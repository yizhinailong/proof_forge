import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.Counter

open ProofForge.IR

def stateCount : StateDecl := {
  id := "count"
  kind := .scalar
  type := .u64
}

def initializeEntrypoint : Entrypoint := {
  name := "initialize"
  returns := .unit
  body := #[
    .effect (.storageScalarWrite "count" (.literal (.u64 0)))
  ]
}

def increment : Entrypoint := {
  name := "increment"
  returns := .unit
  body := #[
    .letBind "n" (.effect (.storageScalarRead "count")),
    .effect (.storageScalarWrite "count" (.add (.local "n") (.literal (.u64 1))))
  ]
}

def get : Entrypoint := {
  name := "get"
  returns := .u64
  body := #[
    .return (.effect (.storageScalarRead "count"))
  ]
}

def module : Module := {
  name := "Counter"
  state := #[stateCount]
  entrypoints := #[initializeEntrypoint, increment, get]
}

end ProofForge.IR.Examples.Counter
