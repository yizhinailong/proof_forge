import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.TestkitSolanaCapabilityDiagnostic

open ProofForge.Target

def expectedCrosscallDiagnostic : String :=
  "target `solana-sbpf-asm` does not support capability `crosscall.invoke`: " ++
  "capability is not present in the target profile"

def main : IO UInt32 := do
  match resolveModule solanaSbpfAsm ProofForge.IR.Examples.CrosscallProbe.module with
  | .ok _ =>
      IO.eprintln "testkit-solana-diagnostic: expected Solana to reject crosscall.invoke"
      pure 1
  | .error err =>
      let actual := err.render
      if actual == expectedCrosscallDiagnostic then
        IO.println "testkit-solana-diagnostic: ok: crosscall.invoke unsupported"
        IO.println s!"diagnostic: {actual}"
        pure 0
      else
        IO.eprintln "testkit-solana-diagnostic: unexpected diagnostic"
        IO.eprintln s!"expected: {expectedCrosscallDiagnostic}"
        IO.eprintln s!"actual:   {actual}"
        pure 1

end ProofForge.Tests.TestkitSolanaCapabilityDiagnostic

def main : IO UInt32 :=
  ProofForge.Tests.TestkitSolanaCapabilityDiagnostic.main
