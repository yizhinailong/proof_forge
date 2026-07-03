import ProofForge.Backend.Move.Aptos
import ProofForge.IR.Contract
import ProofForge.IR.Examples.CrosscallProbe

namespace ProofForge.Tests.AptosDiagnostics

open ProofForge.IR
open ProofForge.Backend.Move.Aptos

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw <| IO.userError message

def main : IO UInt32 := do
  let expected := "Aptos Counter spike: capability `crosscall.invoke` is not supported"
  match renderPackage ProofForge.IR.Examples.CrosscallProbe.module with
  | .ok _ => throw <| IO.userError "Aptos backend unexpectedly accepted crosscall.invoke"
  | .error err =>
      require (err.message == expected) s!"unexpected Aptos diagnostic: {err.message}"

  IO.println "aptos-diagnostics: ok: crosscall.invoke unsupported"
  return 0

end ProofForge.Tests.AptosDiagnostics

def main : IO UInt32 :=
  ProofForge.Tests.AptosDiagnostics.main
