import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EvmMapProbe

open ProofForge.IR

def stateBefore : StateDecl := {
  id := "before"
  kind := .scalar
  type := .u64
}

def stateBalances : StateDecl := {
  id := "balances"
  kind := .map .u64 128
  type := .u64
}

def stateAfter : StateDecl := {
  id := "after"
  kind := .scalar
  type := .u64
}

def seedKey : Expr :=
  .literal (.u64 1001)

def pathKey : Expr :=
  .literal (.u64 2002)

def mapLifecycle : Entrypoint := {
  name := "map_lifecycle"
  selector? := some "3bb39394"
  returns := .u64
  body := #[
    .effect (.storageScalarWrite "before" (.literal (.u64 111))),
    .effect (.storageScalarWrite "after" (.literal (.u64 222))),
    .letBind "old0" .u64 (.effect (.storageMapInsert "balances" seedKey (.literal (.u64 11)))),
    .assertEq (.local "old0") (.literal (.u64 0)) "first insert returns default zero",
    .assertEq (.effect (.storageMapGet "balances" seedKey)) (.literal (.u64 11)) "insert writes the value",
    .letBind "old1" .u64 (.effect (.storageMapSet "balances" seedKey (.literal (.u64 55)))),
    .assertEq (.local "old1") (.literal (.u64 11)) "set returns the previous value",
    .return (.effect (.storageMapGet "balances" seedKey))
  ]
}

def getSeedBalance : Entrypoint := {
  name := "get_seed_balance"
  selector? := some "541be503"
  returns := .u64
  body := #[
    .return (.effect (.storageMapGet "balances" seedKey))
  ]
}

def readBalance : Entrypoint := {
  name := "read_balance"
  selector? := some "68eb1eef"
  params := #[("key", .u64)]
  returns := .u64
  body := #[
    .return (.effect (.storageMapGet "balances" (.local "key")))
  ]
}

def upsertBalance : Entrypoint := {
  name := "upsert_balance"
  selector? := some "e1de6ac8"
  params := #[
    ("key", .u64),
    ("value", .u64)
  ]
  returns := .u64
  body := #[
    .return (.effect (.storageMapInsert "balances" (.local "key") (.local "value")))
  ]
}

def setBalance : Entrypoint := {
  name := "set_balance"
  selector? := some "b41d1f5c"
  params := #[
    ("key", .u64),
    ("value", .u64)
  ]
  returns := .unit
  body := #[
    .effect (.storageMapSet "balances" (.local "key") (.local "value"))
  ]
}

def pathLifecycle : Entrypoint := {
  name := "path_lifecycle"
  selector? := some "84c21205"
  returns := .u64
  body := #[
    .effect (.storagePathWrite "balances" #[.mapKey pathKey] (.literal (.u64 77))),
    .return (.effect (.storagePathRead "balances" #[.mapKey pathKey]))
  ]
}

def module : Module := {
  name := "EvmMapProbe"
  state := #[stateBefore, stateBalances, stateAfter]
  entrypoints := #[
    mapLifecycle,
    getSeedBalance,
    readBalance,
    upsertBalance,
    setBalance,
    pathLifecycle
  ]
}

end ProofForge.IR.Examples.EvmMapProbe
