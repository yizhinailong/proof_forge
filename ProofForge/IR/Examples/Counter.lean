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
  selector? := some "8129fc1c"
  returns := .unit
  body := #[
    .effect (.storageScalarWrite "count" (.literal (.u64 0)))
  ]
}

def increment : Entrypoint := {
  name := "increment"
  selector? := some "d09de08a"
  returns := .unit
  body := #[
    .letBind "n" .u64 (.effect (.storageScalarRead "count")),
    .effect (.storageScalarWrite "count" (.add (.local "n") (.literal (.u64 1))))
  ]
}

def get : Entrypoint := {
  name := "get"
  selector? := some "6d4ce63c"
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
