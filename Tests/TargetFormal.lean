import ProofForge.Contract.Examples.ValueVault
import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.Solana.Examples.Vault
import ProofForge.Target.Formal

/-!
# FV-1 target-routing anchors

These executable checks keep representative `resolveSpec` boundaries tied to
the theorem-backed `requireCapabilityPlan` helpers.
-/

namespace ProofForge.Tests.TargetFormal

open ProofForge.Target

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireOk {α : Type} (result : Except Diagnostic α) (message : String) : IO α :=
  match result with
  | .ok value => pure value
  | .error err => throw <| IO.userError s!"{message}: {err.render}"

def requireError (result : Except Diagnostic CapabilityPlan) (expected : String)
    (message : String) : IO Unit :=
  match result with
  | .ok _ => throw <| IO.userError s!"{message}: expected error"
  | .error err => require (err.render == expected)
      s!"{message}: expected `{expected}`, got `{err.render}`"

def checkValueVaultEvm : IO Unit := do
  let plan ← requireOk
    (resolveSpec evm ProofForge.Contract.Examples.ValueVault.spec)
    "ValueVault EVM routing failed"
  require (plan.checkedBy evm) "ValueVault EVM plan failed FV-1 checkedBy predicate"
  require (resolveSpecCheckedBy evm ProofForge.Contract.Examples.ValueVault.spec)
    "ValueVault EVM resolve result failed FV-1 checkedBy predicate"

def checkUnsupportedCapability : IO Unit := do
  let spec := ProofForge.Contract.ContractSpec.fromIR
    ProofForge.IR.Examples.CrosscallProbe.module
  requireError (resolveSpec solanaSbpfAsm spec)
    "target `solana-sbpf-asm` does not support capability `crosscall.invoke`: capability is not present in the target profile"
    "generic crosscall must be rejected by Solana target routing"

def checkSolanaExtensionIsolation : IO Unit := do
  requireError (resolveSpec evm ProofForge.Solana.Examples.Vault.spec)
    "target `evm` cannot use Solana target extension metadata on operation `solana.runtime.allocator`"
    "Solana target-extension metadata must be rejected on EVM"
  let solanaPlan ← requireOk
    (resolveSpec solanaSbpfAsm ProofForge.Solana.Examples.Vault.spec)
    "Solana Vault routing failed"
  require (solanaPlan.checkedBy solanaSbpfAsm)
    "Solana Vault plan failed FV-1 checkedBy predicate"

def main : IO UInt32 := do
  checkValueVaultEvm
  checkUnsupportedCapability
  checkSolanaExtensionIsolation
  IO.println "target-formal: ok"
  return 0

end ProofForge.Tests.TargetFormal

def main : IO UInt32 :=
  ProofForge.Tests.TargetFormal.main
