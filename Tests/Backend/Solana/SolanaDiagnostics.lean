import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.IR.Contract

/-!
# Solana sBPF Assembly Capability Diagnostics

V-GATE-SOLANA-05 (capability-checker half). The `solana-sbpf-asm` target
profile (D-026) supports the Solana-native `crosscall.cpi` and `storage.pda`
capabilities but **not** the generic portable `crosscall.invoke` capability —
Solana's account-passing CPI has no analog on EVM/Wasm/Move (D-027), so the
generic crosscall constructors must be rejected before sBPF assembly emission
with a clear diagnostic citing both the target id and the capability id.

The portable IR never produces `zk.circuit` or `zk.proof` (those live on the
target side), so the only unsupported capabilities the portable IR can surface
to this checker are the generic crosscall family. Each case below builds a
module that uses one of those constructors, calls `SbpfAsm.renderModule`, and
asserts the exact `CapabilityError.render` message:

    target `solana-sbpf-asm` does not support capability `crosscall.invoke`:
    capability is not present in the target profile
-/

namespace ProofForge.Tests.SolanaDiagnostics

open ProofForge.IR
open ProofForge.Backend.Solana

def markerState : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def selectedEntrypoint (name : String) (body : Array Statement := #[]) : Entrypoint := {
  name := name
  selector? := some "deadbeef"
  returns := .unit
  body := body
}

def selectedReturnEntrypoint (name : String) (returns : ValueType) (body : Array Statement) : Entrypoint := {
  name := name
  selector? := some "deadbeef"
  returns := returns
  body := body
}

def selectedModule (name : String) (entrypoint : Entrypoint) : Module := {
  name := name
  state := #[markerState]
  entrypoints := #[entrypoint]
}

/-- Common expected message for every `crosscall.invoke` rejection. -/
def crosscallInvokeMessage : String :=
  "target `solana-sbpf-asm` does not support capability `crosscall.invoke`: capability is not present in the target profile"

def crosscallInvokeModule : Module :=
  selectedModule "BadCrosscallInvoke" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallInvoke (.literal (.u64 1)) (.literal (.u64 2)) #[])
    ]

def crosscallInvokeTypedModule : Module :=
  selectedModule "BadCrosscallInvokeTyped" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallInvokeTyped
        (.literal (.u64 1))
        (.literal (.u64 2))
        #[]
        .u64)
    ]

def crosscallInvokeValueTypedModule : Module :=
  selectedModule "BadCrosscallInvokeValueTyped" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallInvokeValueTyped
        (.literal (.u64 1))
        (.literal (.u64 2))
        (.literal (.u64 0))
        #[]
        .u64)
    ]

def crosscallInvokeStaticTypedModule : Module :=
  selectedModule "BadCrosscallInvokeStaticTyped" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallInvokeStaticTyped
        (.literal (.u64 1))
        (.literal (.u64 2))
        #[]
        .u64)
    ]

def crosscallInvokeDelegateTypedModule : Module :=
  selectedModule "BadCrosscallInvokeDelegateTyped" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallInvokeDelegateTyped
        (.literal (.u64 1))
        (.literal (.u64 2))
        #[]
        .u64)
    ]

def crosscallCreateModule : Module :=
  selectedModule "BadCrosscallCreate" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallCreate (.literal (.u64 0)) "00")
    ]

def crosscallCreate2Module : Module :=
  selectedModule "BadCrosscallCreate2" <|
    selectedReturnEntrypoint "bad" .u64 #[
      .return (.crosscallCreate2 (.literal (.u64 0)) (.literal (.u64 0)) "00")
    ]

/-- Aggregate crosscall in a `letBind`: diagnostic still fires from the expr
position, proving the check is module-wide, not only at `return`. -/
def crosscallLetBindModule : Module :=
  selectedModule "BadCrosscallLetBind" <|
    selectedEntrypoint "bad" #[
      .letBind "r" .u64
        (.crosscallInvoke (.literal (.u64 1)) (.literal (.u64 2)) #[])
    ]

def cases : Array (String × Module × String) := #[
  ("crosscall.invoke unsupported", crosscallInvokeModule, crosscallInvokeMessage),
  ("crosscall.invokeTyped unsupported", crosscallInvokeTypedModule, crosscallInvokeMessage),
  ("crosscall.invokeValueTyped unsupported", crosscallInvokeValueTypedModule, crosscallInvokeMessage),
  ("crosscall.invokeStaticTyped unsupported", crosscallInvokeStaticTypedModule, crosscallInvokeMessage),
  ("crosscall.invokeDelegateTyped unsupported", crosscallInvokeDelegateTypedModule, crosscallInvokeMessage),
  ("crosscall.create unsupported", crosscallCreateModule, crosscallInvokeMessage),
  ("crosscall.create2 unsupported", crosscallCreate2Module, crosscallInvokeMessage),
  ("crosscall.invoke in letBind unsupported", crosscallLetBindModule, crosscallInvokeMessage)
]

def renderError? (module : Module) : Option String :=
  match SbpfAsm.renderModule module with
  | .ok _ => none
  | .error err => some err.render

def checkCase (name : String) (module : Module) (expected : String) : IO Bool := do
  match renderError? module with
  | some actual =>
      if actual == expected then
        IO.println s!"solana-diagnostics: ok: {name}"
        pure true
      else
        IO.eprintln s!"solana-diagnostics: FAILED: {name}"
        IO.eprintln s!"  expected: {expected}"
        IO.eprintln s!"  actual:   {actual}"
        pure false
  | none =>
      IO.eprintln s!"solana-diagnostics: FAILED: {name}"
      IO.eprintln "  expected an error, but sBPF assembly generation succeeded"
      pure false

def main : IO UInt32 := do
  let mut failures : Nat := 0
  for (name, module, expected) in cases do
    let ok ← checkCase name module expected
    if !ok then
      failures := failures + 1
  if failures == 0 then
    IO.println s!"solana-diagnostics: {cases.size} cases passed"
    pure 0
  else
    IO.eprintln s!"solana-diagnostics: {failures} case(s) failed"
    pure 1

end ProofForge.Tests.SolanaDiagnostics

def main : IO UInt32 :=
  ProofForge.Tests.SolanaDiagnostics.main