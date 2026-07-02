import ProofForge.IR.Contract
import ProofForge.Target.Check
import ProofForge.Compiler.Leo.Emit

namespace ProofForge.Backend.Aleo.IR

open ProofForge.IR

structure LowerError where
  message : String
  deriving Repr, Inhabited

def LowerError.render (err : LowerError) : String := err.message

def capabilityError (err : ProofForge.Target.CapabilityError) : LowerError :=
  { message := ProofForge.Target.CapabilityError.render err }

/-- Render the full module by lowering to the Leo AST and printing it. -/
def renderModule (module : Module) : Except LowerError String :=
  match ProofForge.Compiler.Leo.Emit.renderModule module with
  | .ok s => .ok s
  | .error e => .error { message := e.message }

end ProofForge.Backend.Aleo.IR
