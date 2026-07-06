/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# SolanaReplay — Tier C-diff replay shim for the Solana (sBPF) backend

This is the Step A type-only stub from RFC 0014 Phase 5, Path 5a
(see `docs/quint-cdiff-multi-backend-design.md`). It is the second C-diff
candidate after NEAR: the same Quint MBT ITF traces that `Replay.replayTrace`
consumes for Tier A (IR self-replay) are lowered into a Rust Mollusk test
file that replays the trace against the emitted sBPF ELF (`.so`).

The shim is **not** wired into any `*-backend-replay-gate.sh` and does not
spawn Mollusk, `sbpf`, `solana-keygen`, or `quint`. It only renders the Rust
test source deterministically and provides the type definitions. Step B
(the wrapping test that emits the ELF + spawns `cargo test`, the gate script,
the `justfile` recipe wired into `just check`) is a follow-up, gated on the
stub compiling cleanly and the SBF platform-tools being available.

## Harness shape

Mollusk is a Rust crate (`mollusk_svm`) invoked as a Rust test harness — there
is no Mollusk CLI. The rendered harness is therefore a Rust source file that
calls `mollusk_svm::Mollusk::new(&pid, "<elf>")` and
`m.process_instruction(...)` per trace step, mirroring the in-tree template
`Tests/solana/counter_mollusk.rs.tpl` and the testkit harness
(`testkit/harness-solana/src/lib.rs`). This is the EVM-shim shape (render a
test file the target toolchain executes) rather than the NEAR-shim shape
(render a CLI arg list).

## Account-model translation

Solana's executable artifact is an sBPF ELF; its state lives in *accounts*
(one account per state field group, owned by the program), not in flat
storage. The shim maps an IR trace step `(entrypoint, args)` to a Solana
instruction `(program_id, accounts, instruction_data)`:

- `program_id` is the first 32 bytes of the keypair JSON (rendered as a
  `program_id()` fn in the test, identical to the in-tree template).
- `accounts` is a single writable state account owned by the program
  (v1 scalar-state shape, matching `SolanaModulePlan.accounts[0]` for the
  Counter). Multi-account/PDA/CPI translation is deferred.
- `instruction_data` is the entrypoint discriminator (1-byte internal tag or
  8-byte external selector parsed from `Entrypoint.selector?`) followed by the
  little-endian encoding of the IR arguments. The `SolanaModulePlan`
  (`ProofForge/Backend/Solana/Plan.lean`, Phase 2) already exposes this
  discriminator + instruction-data ABI; the shim re-derives it from
  `Entrypoint.selector?` via `Manifest.externalDiscriminatorBytes?` to avoid
  requiring a full plan build at replay time.

The chain-neutral trace interpretation (`resolveActionName`, `entrypointMap`,
`buildArgs`, `itfValueToIr`) is imported unchanged from `Replay.lean`.
-/

import ProofForge.IR.Contract
import ProofForge.IR.Semantics
import ProofForge.Backend.Quint.ITF
import ProofForge.Backend.Quint.Replay
import ProofForge.Backend.Solana.Manifest

namespace ProofForge.Backend.Quint.SolanaReplay

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.Backend.Quint.Replay
open ProofForge.Backend.Solana.Manifest

structure SolanaReplayError where
  message : String

/-- Per-backend config: where the sBPF ELF + keypair live, the state account
data length, and how to read back the primary scalar state. Mirrors
`EvmReplayConfig` (`bytecodeHex` / `readSignature` / `primaryStateVar`) but with
Solana artifact paths and an account-data length instead of a Solidity getter
signature. -/
structure SolanaReplayConfig where
  /-- Path to the emitted sBPF ELF (`.so`), passed to `Mollusk::new`. -/
  programPath : String
  /-- Path to the program keypair JSON; the program id is its first 32 bytes. -/
  keypairPath : String
  /-- Byte length of the state account data (e.g. 8 for Counter's u64). -/
  stateAccountDataLen : Nat
  /-- ITF/IR state variable name being checked (e.g. `count`). -/
  primaryStateVar : String
  /-- Byte size of the primary scalar (e.g. 8 for u64). Used to render the
  expected little-endian byte array and to slice return data. -/
  primaryStateByteSize : Nat

def indent (n : Nat) (lines : List String) : String :=
  let pad := String.ofList (List.replicate n ' ')
  String.intercalate "\n" (lines.map (fun line => pad ++ line))

/-- Read the primary scalar state variable as a Nat from an ITF state. -/
def itfNatValue (state : ITF.State) (varName : String) : Except SolanaReplayError Nat :=
  match state.vars.find? (fun (k, _) => k == varName) with
  | some (_, .int n) => .ok n
  | some (_, v) => .error { message := s!"expected int for `{varName}` in ITF state {state.index}, got {repr v}" }
  | none => .error { message := s!"missing ITF field `{varName}` in state {state.index}" }

/-- Render a Nat as a Rust little-endian byte-array literal body, e.g.
`[1u8, 0, 0, 0, 0, 0, 0, 0]` for `n=1, byteSize=8`. -/
def renderLeBytes (byteSize : Nat) (n : Nat) : String :=
  let bytes := (List.range byteSize).map (fun i => (n / (256 ^ i)) % 256)
  String.intercalate ", " (bytes.map (fun b => toString b))

/-- Encode an IR scalar argument value as little-endian byte string for the
instruction-data payload. Only scalar argument types are supported in v1;
aggregates are deferred (matches the EVM/NEAR v1 scalar-args constraint). -/
def encodeArgLe (v : Value) : Except SolanaReplayError (Array Nat) :=
  match v with
  | .u8 n => .ok #[(n % 256)]
  | .u32 n => .ok #[(n % 256), (n / 256 % 256), (n / 65536 % 256), (n / 16777216 % 256)]
  | .u64 n =>
      .ok #[(n % 256), (n / 256 % 256), (n / 65536 % 256), (n / 16777216 % 256),
            (n / 4294967296 % 256), (n / 1099511627776 % 256),
            (n / 281474976710656 % 256), (n / 72057594037927936 % 256)]
  | .u128 n =>
      -- 16 bytes little-endian; n is Nat so this is exact for the bounded MBT range.
      .ok ((List.range 16).map (fun i => (n / (256 ^ i)) % 256) |>.toArray)
  | .bool b => .ok #[if b then 1 else 0]
  | .unit => .ok #[]
  | other => .error { message := s!"SolanaReplay v1 cannot encode argument: {repr other}" }

/-- Encode an array of IR argument values as a single byte array
(concatenated little-endian bytes). -/
def encodeArgsLe (args : Array Value) : Except SolanaReplayError (Array Nat) := do
  let mut out := #[]
  for arg in args do
    out := out ++ (← encodeArgLe arg)
  pure out

/-- Build a sanitized-name → entrypoint map (reuses `Replay.entrypointMap`). -/
def entrypointMap (module : ProofForge.IR.Module) : Std.HashMap String Entrypoint :=
  Replay.entrypointMap module

/-- Build a sanitized-name → instruction tag (entrypoint index) map. The tag
is the entrypoint's position in `module.entrypoints`, matching
`Manifest.buildInstructions` and the sBPF dispatch prologue. -/
def tagMap (module : ProofForge.IR.Module) : Std.HashMap String Nat :=
  module.entrypoints.foldl
    (fun m ep => m.insert (sanitizeName ep.name) m.size)
    {}

/-- Discriminator bytes for an entrypoint: the 8-byte external selector if
`selector?` is a valid 8-byte hex, otherwise the 1-byte internal tag. Reuses
`Manifest.externalDiscriminatorBytes?` so the shim stays consistent with the
manifest emitter. -/
def discriminatorBytes (ep : Entrypoint) (tag : Nat) : Array Nat :=
  match externalDiscriminatorBytes? ep with
  | some bytes => bytes
  | none => #[tag]

/-- Whether an entrypoint is a read (returns a non-unit value) vs a mutating
call. Used to decide whether the step asserts account data (mutating) or
return data (read). -/
def isReadEntrypoint (ep : Entrypoint) : Bool :=
  ep.returns != .unit

/-- Render the instruction-data `Vec<u8>` literal for one trace step:
discriminator bytes followed by little-endian-encoded arguments. Returns the
Rust source snippet (a `vec![...]` expression) and the entrypoint used. -/
def renderInstructionData (ep : Entrypoint) (tag : Nat) (args : Array Value) :
    Except SolanaReplayError String := do
  let disc := discriminatorBytes ep tag
  let argBytes ← encodeArgsLe args
  let allBytes := disc ++ argBytes
  if allBytes.isEmpty then
    .ok "vec![]"
  else
    .ok (s!"vec![{String.intercalate ", " (allBytes.toList.map toString)}]")

/-- Render one `#[test] fn test_step_<idx>()` for a trace step. -/
def renderTraceStep (module : ProofForge.IR.Module) (cfg : SolanaReplayConfig)
    (epMap : Std.HashMap String Entrypoint) (tags : Std.HashMap String Nat)
    (prevValue expected : Nat) (stepIdx : Nat) (state : ITF.State) :
    Except SolanaReplayError String := do
  let actionName ← resolveActionName module state.actionTaken state.nondetPicks
    |>.mapError (fun err => { message := err.message })
  -- The Quint `init` action maps to the IR `initialize` entrypoint (the
  -- Counter fixture's first entrypoint), mirroring NearReplay's init handling.
  let resolvedName := if actionName == "init" then "initialize" else actionName
  let entrypoint ← match Std.HashMap.get? epMap resolvedName with
    | some ep => .ok ep
    | none => .error { message := s!"unknown entrypoint `{actionName}` (resolved `{resolvedName}`) for Solana replay" }
  let tag := (tags.get? resolvedName).getD 0
  let args ← buildArgs entrypoint state.nondetPicks
    |>.mapError (fun err => { message := err.message })
  let dataLiteral ← renderInstructionData entrypoint tag args
  let isRead := isReadEntrypoint entrypoint
  let testName := s!"test_step_{stepIdx}"
  let comment := s!"// step {stepIdx}: {entrypoint.name} -> {cfg.primaryStateVar} = {expected}"
  -- The state account is seeded with the previous step's primary value; for
  -- `init`/`initialize` the prior value is 0 (the account starts zeroed).
  let seedBytes := renderLeBytes cfg.primaryStateByteSize prevValue
  let expectedBytes := renderLeBytes cfg.primaryStateByteSize expected
  let mut lines := [
    "#[test]",
    s!"fn {testName}() " ++ "{",
    "    let pid = program_id();",
    "    let m = mollusk();",
    "    let counter = Address::new_unique();",
    s!"    let mut counter_account = Account::new(0, {cfg.stateAccountDataLen}, &pid);",
    s!"    counter_account.data = vec![{seedBytes}];",
    s!"    {comment}",
    s!"    let data = {dataLiteral};",
    "    let result = m.process_instruction(",
    "        &ix(pid, data, counter),",
    "        &[(counter, counter_account)],",
    "    );",
    s!"    assert!(!result.program_result.is_err(), \"step {stepIdx} ({entrypoint.name}) failed\");"
  ]
  if isRead then
    -- Read entrypoint: the primary value comes back as return data.
    lines := lines.concat
      s!"    assert_eq!(result.return_data, vec![{expectedBytes}], \"step {stepIdx} return data mismatch\");"
  else
    -- Mutating entrypoint: the primary value is written to the account data.
    lines := lines.concat
      s!"    let after = result.get_account(&counter).expect(\"step {stepIdx} missing state account\");"
    lines := lines.concat
      s!"    assert_eq!(after.data, vec![{expectedBytes}], \"step {stepIdx} account data mismatch\");"
  lines := lines.concat "}"
  .ok (String.intercalate "\n" lines)

/-- Render the full Rust Mollusk test file for a trace (v1: one test per
trace step, each seeded from the previous ITF state's primary value and
asserting the current ITF state's expected value). The result is a
self-contained Rust source file suitable for `cargo test` against a
Mollusk-bearing crate. -/
def renderReplayHarness (module : ProofForge.IR.Module) (trace : ITF.Trace)
    (cfg : SolanaReplayConfig) : Except SolanaReplayError String := do
  if trace.states.isEmpty then
    .error { message := "empty ITF trace" }
  let epMap := entrypointMap module
  let tags := tagMap module
  -- The initial (var) state carries the pre-init primary value; default to 0.
  let initialValue ←
    match itfNatValue trace.states.head! cfg.primaryStateVar with
    | .ok n => .ok n
    | .error _ => .ok 0
  let steps ← trace.states.tail!.mapM (fun state => do
    let prevIdx := state.index - 1
    let prevValue ←
      if prevIdx < trace.states.length then
        match itfNatValue trace.states[prevIdx]! cfg.primaryStateVar with
        | .ok n => .ok n
        | .error _ => .ok initialValue
      else
        .ok initialValue
    let expected ← itfNatValue state cfg.primaryStateVar
    renderTraceStep module cfg epMap tags prevValue expected state.index state)
  .ok <| String.intercalate "\n" [
    "#![cfg(test)]",
    "// ProofForge Quint C-diff Solana replay harness (generated).",
    "// Mirrors Tests/solana/counter_mollusk.rs.tpl; executes one Mollusk",
    "// instruction per ITF trace step and asserts the primary scalar state.",
    "",
    "use {",
    "    mollusk_svm::Mollusk,",
    "    solana_account::Account,",
    "    solana_address::Address,",
    "    solana_instruction::{AccountMeta, Instruction},",
    "};",
    "",
    s!"const STATE_DATA_LEN: usize = {cfg.stateAccountDataLen};",
    "",
    "fn program_id() -> Address {",
    s!"    let keypair_bytes = std::fs::read(\"{cfg.keypairPath}\").unwrap();",
    "    let mut arr = [0u8; 32];",
    "    arr.copy_from_slice(&keypair_bytes[..32]);",
    "    Address::new_from_array(arr)",
    "}",
    "",
    "fn mollusk() -> Mollusk {",
    "    let pid = program_id();",
    s!"    let mut mollusk = Mollusk::new(&pid, \"{cfg.programPath}\");",
    "    // Phase 1 lowering uses the legacy embedded account-data layout.",
    "    mollusk.feature_set.account_data_direct_mapping = false;",
    "    mollusk.feature_set.direct_account_pointers_in_program_input = false;",
    "    mollusk.feature_set.virtual_address_space_adjustments = false;",
    "    mollusk",
    "}",
    "",
    "fn ix(pid: Address, data: Vec<u8>, counter: Address) -> Instruction {",
    "    Instruction::new_with_bytes(",
    "        pid,",
    "        &data,",
    "        vec![AccountMeta::new(counter, false)],",
    "    )",
    "}",
    "",
    indent 0 steps
  ]

end ProofForge.Backend.Quint.SolanaReplay