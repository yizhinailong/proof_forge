import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.ArrayProbe

open ProofForge.IR

def stateValues : StateDecl := {
  id := "values"
  kind := .array 3
  type := .u64
}

def felt (value : Nat) : Expr :=
  .literal (.u64 value)

def ix (value : Nat) : Expr :=
  .literal (.u64 value)

def sumLiteral : Entrypoint := {
  name := "sum_literal"
  returns := .u64
  body := #[
    .letBind "xs" (.fixedArray .u64 3) (.arrayLit .u64 #[felt 10, felt 20, felt 30]),
    .return (.add
      (.add
        (.arrayGet (.local "xs") (ix 0))
        (.arrayGet (.local "xs") (ix 1)))
      (.arrayGet (.local "xs") (ix 2)))
  ]
}

def storageLifecycle : Entrypoint := {
  name := "storage_lifecycle"
  returns := .u64
  body := #[
    .effect (.storageArrayWrite "values" (ix 0) (felt 7)),
    .effect (.storageArrayWrite "values" (ix 1) (felt 11)),
    .effect (.storageArrayWrite "values" (ix 2) (felt 13)),
    .return (.add
      (.add
        (.effect (.storageArrayRead "values" (ix 0)))
        (.effect (.storageArrayRead "values" (ix 1))))
      (.effect (.storageArrayRead "values" (ix 2))))
  ]
}

def module : Module := {
  name := "ArrayProbe"
  state := #[stateValues]
  entrypoints := #[sumLiteral, storageLifecycle]
}

end ProofForge.IR.Examples.ArrayProbe
