import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.Contract

inductive IntentKind where
  | module
  | state
  | entrypoint
  | capability
  deriving BEq, DecidableEq, Repr

def IntentKind.id : IntentKind -> String
  | .module => "module"
  | .state => "state"
  | .entrypoint => "entrypoint"
  | .capability => "capability"

structure Intent where
  kind : IntentKind
  label : String
  capability? : Option ProofForge.Target.Capability := none
  source? : Option String := none
  deriving Repr

def Intent.capability (capability : ProofForge.Target.Capability) (source? : Option String := none) : Intent := {
  kind := .capability
  label := capability.id
  capability? := some capability
  source?
}

end ProofForge.Contract
