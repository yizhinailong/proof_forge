import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.MapProbe

open ProofForge.IR

def stateBefore : StateDecl := {
  id := "before"
  kind := .scalar
  type := .u64
}

def stateBalances : StateDecl := {
  id := "balances"
  kind := .map .hash 128
  type := .hash
}

def stateAfter : StateDecl := {
  id := "after"
  kind := .scalar
  type := .u64
}

def seedKey : Expr :=
  .literal (.hash4 1001 0 0 0)

def initialValue : Expr :=
  .literal (.hash4 11 22 33 44)

def updatedValue : Expr :=
  .literal (.hash4 55 66 77 88)

def pathKey : Expr :=
  .literal (.hash4 2002 0 0 0)

def pathValue : Expr :=
  .literal (.hash4 77 88 99 111)

def mapLifecycle : Entrypoint := {
  name := "map_lifecycle"
  returns := .hash
  body := #[
    .letBind "key" .hash seedKey,
    .letBind "value0" .hash initialValue,
    .letBind "value1" .hash updatedValue,
    .effect (.storageScalarWrite "before" (.literal (.u64 111))),
    .effect (.storageScalarWrite "after" (.literal (.u64 222))),
    .letBind "present0" .bool (.effect (.storageMapContains "balances" (.local "key"))),
    .letBind "old0" .hash (.effect (.storageMapInsert "balances" (.local "key") (.local "value0"))),
    .letBind "present1" .bool (.effect (.storageMapContains "balances" (.local "key"))),
    .effect (.storageMapSet "balances" (.local "key") (.local "value1")),
    .return (.effect (.storageMapGet "balances" (.local "key")))
  ]
}

def pathLifecycle : Entrypoint := {
  name := "path_lifecycle"
  returns := .hash
  body := #[
    .letBind "key" .hash pathKey,
    .letBind "value" .hash pathValue,
    .effect (.storagePathWrite "balances" #[.mapKey (.local "key")] (.local "value")),
    .return (.effect (.storagePathRead "balances" #[.mapKey (.local "key")]))
  ]
}

def getSeedBalance : Entrypoint := {
  name := "get_seed_balance"
  returns := .hash
  body := #[
    .letBind "key" .hash seedKey,
    .return (.effect (.storageMapGet "balances" (.local "key")))
  ]
}

def hasSeedBalance : Entrypoint := {
  name := "has_seed_balance"
  returns := .bool
  body := #[
    .letBind "key" .hash seedKey,
    .return (.effect (.storageMapContains "balances" (.local "key")))
  ]
}

def upsertBalance : Entrypoint := {
  name := "upsert_balance"
  params := #[
    ("key", .hash),
    ("value", .hash)
  ]
  returns := .hash
  body := #[
    .return (.effect (.storageMapInsert "balances" (.local "key") (.local "value")))
  ]
}

def setBalance : Entrypoint := {
  name := "set_balance"
  params := #[
    ("key", .hash),
    ("value", .hash)
  ]
  returns := .unit
  body := #[
    .effect (.storageMapSet "balances" (.local "key") (.local "value"))
  ]
}

def module : Module := {
  name := "MapProbe"
  state := #[stateBefore, stateBalances, stateAfter]
  entrypoints := #[
    mapLifecycle,
    getSeedBalance,
    hasSeedBalance,
    upsertBalance,
    setBalance,
    pathLifecycle
  ]
}

end ProofForge.IR.Examples.MapProbe
