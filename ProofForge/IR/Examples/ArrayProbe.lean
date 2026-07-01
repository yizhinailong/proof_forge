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

def arrayPredicates : Entrypoint := {
  name := "array_predicates"
  returns := .u64
  body := #[
    .letBind "xs" (.fixedArray .u64 3) (.arrayLit .u64 #[felt 1, felt 2, felt 3]),
    .letBind "ys" (.fixedArray .u64 3) (.arrayLit .u64 #[felt 1, felt 2, felt 3]),
    .letBind "zs" (.fixedArray .u64 3) (.arrayLit .u64 #[felt 1, felt 2, felt 4]),
    .assertEq (.local "xs") (.local "ys") "fixed array assert_eq compares elements",
    .assert (.eq (.local "xs") (.local "ys")) "fixed array equality compares elements",
    .assert (.ne (.local "xs") (.local "zs")) "fixed array inequality compares elements",
    .return (felt 1)
  ]
}

def emitWatStorageModule : Module := {
  name := "ArrayProbe",
  state := #[stateValues],
  entrypoints := #[storageLifecycle]
}

/-- EmitWat-compatible subset for 16b-1: only `sumLiteral` (arrayLit + arrayGet),
    no storage or array-equality. -/
def emitWatSumModule : Module := {
  name := "ArrayProbe",
  state := #[],
  entrypoints := #[sumLiteral]
}
/-- Allocator-strategy variants of the sumLiteral subset. -/
def emitWatSumResetModule : Module := {
  name := "ArrayProbe",
  state := #[],
  entrypoints := #[sumLiteral],
  allocator := { strategy := .bumpReset }
}
def emitWatSumExternalModule : Module := {
  name := "ArrayProbe",
  state := #[],
  entrypoints := #[sumLiteral],
  allocator := { strategy := .external }
}
/-- A reuse-capable strategy: host must provide jemalloc-backed pf_alloc/pf_dealloc.
    Same lowering surface as `external`; the strategy records which host
    implementation is expected. Not chain-deployable (NEAR runtime exports
    neither pf_alloc nor pf_dealloc). -/
def emitWatSumJemallocModule : Module := {
  name := "ArrayProbe",
  state := #[],
  entrypoints := #[sumLiteral],
  allocator := { strategy := .jemalloc }
}


def module : Module := {
  name := "ArrayProbe"
  state := #[stateValues]
  entrypoints := #[sumLiteral, storageLifecycle, arrayPredicates]
}

end ProofForge.IR.Examples.ArrayProbe
