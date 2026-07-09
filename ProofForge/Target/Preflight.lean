/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Target preflight (IR-level gates before materialize)

Answers the product question: **do we validate on the IR before chain
materialization?** Yes — in **layers**. Preflight is the shared orchestrator
that runs *before* target-native packing (CPI / CALL / Promise /
`invoke_contract`):

```text
IR.Module
  ├─ L0  Portability (family-only constructors)     IR.Portability
  ├─ L1  Capability resolve                         Target.Adapter.resolveModule
  ├─ L2  Protocol-shaped IR checks (per backend)    Evm.Validate / Solana / EmitWat
  └─ L3  Materialize + native emit                  Materialize / CPI / CALL / Promise / Soroban invoke
```

| Layer | Question | Maps to materialize? |
|---|---|---|
| L0 Portability | Is this constructor legal for *any* portable path / this family? | No — reject early |
| L1 Capability | Does `--target X` advertise the needed capabilities? | Gates materialize |
| L2 Protocol IR | Target-specific well-formedness still on IR (types, returns, …) | Feeds plan |
| L3 Materialize | Account roles, CPI pack, CALL ABI, Promise strings | **Is** materialize |
| L4 Prologue / emit | Solana signer/owner traps; Yul/WAT specifics | After schema exists |

Solana Anchor/Pinocchio-style **account** checks are **L3→L4**: schema from
materialize, traps in entrypoint prologue — not portable IR nodes.

This module implements **L0+L1 preflight** as one report so CLI/tests can
assert “ready to materialize” without running full emit.
-/
import ProofForge.IR.Contract
import ProofForge.IR.Portability
import ProofForge.Target.Adapter
import ProofForge.Target.Registry
import ProofForge.Target.CrosscallMaterialize
import ProofForge.Target.PortableHonesty

namespace ProofForge.Target.Preflight

open ProofForge.IR
open ProofForge.IR.Portability
open ProofForge.Target
open ProofForge.Target.CrosscallMaterialize
open ProofForge.Target.PortableHonesty

structure Report where
  targetId : String
  /-- L1 capability plan resolved (empty when failed). -/
  capabilityOk : Bool
  capabilityError? : Option String
  /-- L0 hard: no *family-only constructors* illegal on this family
  (e.g. nearPromiseThen on Solana). Foreign *metadata* (e.g. nearCrosscallStrings
  on EVM) is recorded but does not block materialize — backends ignore it. -/
  portabilityOk : Bool
  portabilityViolations : Array String
  /-- Soft: foreign target metadata present (ignored by this family). -/
  metadataNotes : Array String
  /-- Declared native form for portable crosscall (if any). -/
  crosscallNativeForm : String
  /-- Ready for target materialize/emit (hard L0 ∧ L1). L2 still runs in backends. -/
  readyToMaterialize : Bool
  note : String
  deriving Repr

private def jsonStr (s : String) : String := "\"" ++ s ++ "\""

def Report.json (r : Report) : String :=
  "{" ++
  "\"targetId\":" ++ jsonStr r.targetId ++ "," ++
  "\"capabilityOk\":" ++ (if r.capabilityOk then "true" else "false") ++ "," ++
  "\"portabilityOk\":" ++ (if r.portabilityOk then "true" else "false") ++ "," ++
  "\"readyToMaterialize\":" ++ (if r.readyToMaterialize then "true" else "false") ++ "," ++
  "\"crosscallNativeForm\":" ++ jsonStr r.crosscallNativeForm ++ "," ++
  "\"note\":" ++ jsonStr r.note ++
  "}"

/-- Hard L0: only `targetFamilyOnly` mismatches block materialize.
`targetMetadata` for another family is soft (backends ignore foreign metadata). -/
def hardPortabilityViolations (module : Module) (family : TargetFamily) :
    Array PortabilityFinding :=
  (classifyModule module).filter fun f =>
    match f.class_ with
    | .targetFamilyOnly other => other != family
    | _ => false

def softMetadataNotes (module : Module) (family : TargetFamily) : Array PortabilityFinding :=
  (classifyModule module).filter fun f =>
    match f.class_ with
    | .targetMetadata (some other) => other != family
    | _ => false

/-- Run L0 portability + L1 capability + portable honesty preflight for one target.

Portable honesty (HostEnv/Identity/sync-crosscall) is enforced inside
`resolveModule` → `defaultResolve`; this report surfaces that as capabilityOk
failure with the PortableHonesty diagnostic text.
-/
def run (profile : TargetProfile) (module : Module) : Report :=
  let capResult := resolveModule profile module
  let (capabilityOk, capabilityError?) :=
    match capResult with
    | .ok _ => (true, none)
    | .error e => (false, some e.render)
  let hard := hardPortabilityViolations module profile.family
  let soft := softMetadataNotes module profile.family
  let portabilityOk := hard.isEmpty
  let violStrs := hard.map renderFinding
  let metaStrs := soft.map renderFinding
  let xform := (forProfile profile).nativeForm.id
  -- Explicit sync-subset note for report consumers (also enforced in resolve).
  let syncNote :=
    if moduleUsesPortableSyncCrosscall module && moduleUsesNearAsyncExtension module then
      " [portable sync-subset forbids mixing crosscallInvoke with promise_then/result]"
    else if moduleUsesPortableSyncCrosscall module then
      " [portable sync-subset remote]"
    else ""
  let ready := capabilityOk && portabilityOk
  let note :=
    if ready then
      let softNote :=
        if metaStrs.isEmpty then ""
        else s!" (soft metadata ignored: {String.intercalate "; " metaStrs.toList})"
      s!"preflight ok → materialize as {xform} (L2 protocol validate still in backend){softNote}{syncNote}"
    else if !capabilityOk then
      s!"capability/honesty reject: {capabilityError?.getD "?"}"
    else
      s!"portability reject: {String.intercalate "; " violStrs.toList}"
  { targetId := profile.id
    capabilityOk := capabilityOk
    capabilityError? := capabilityError?
    portabilityOk := portabilityOk
    portabilityViolations := violStrs
    metadataNotes := metaStrs
    crosscallNativeForm := xform
    readyToMaterialize := ready
    note := note }

/-- Preflight primary three targets used by portable multi-target demos. -/
def runPrimary (module : Module) : Array Report :=
  #[run evm module, run solanaSbpfAsm module, run wasmNear module]

/-- Primary triad + Soroban host-adapter profile (not in `Registry.all`). -/
def runPrimaryWithSoroban (module : Module) : Array Report :=
  runPrimary module |>.push (run wasmStellarSoroban module)

def allReady (reports : Array Report) : Bool :=
  reports.all (fun r => r.readyToMaterialize)

end ProofForge.Target.Preflight
