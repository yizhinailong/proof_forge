import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EvmArrayValueProbe

open ProofForge.IR

def u32 (value : Nat) : Expr :=
  .literal (.u32 value)

def u64 (value : Nat) : Expr :=
  .literal (.u64 value)

def bool (value : Bool) : Expr :=
  .literal (.bool value)

def hash (a b c d : Nat) : Expr :=
  .literal (.hash4 a b c d)

def localSum : Entrypoint := {
  name := "local_sum"
  selector? := some "77bd09b1"
  returns := .u64
  body := #[
    .letBind "xs" (.fixedArray .u64 3) (.arrayLit .u64 #[u64 7, u64 11, u64 13]),
    .letBind "head" .u64 (.arrayGet (.local "xs") (u64 0)),
    .return (.add (.local "head") (.arrayGet (.local "xs") (u64 2)))
  ]
}

def directLiteralIndex : Entrypoint := {
  name := "direct_literal_index"
  selector? := some "7389a736"
  returns := .u64
  body := #[
    .return (.arrayGet (.arrayLit .u64 #[u64 4, u64 6, u64 8]) (u64 1))
  ]
}

def boolGuard : Entrypoint := {
  name := "bool_guard"
  selector? := some "7c95ba13"
  returns := .bool
  body := #[
    .letBind "flags" (.fixedArray .bool 2) (.arrayLit .bool #[bool false, bool true]),
    .assert (.arrayGet (.local "flags") (u64 1)) "fixed array bool guard must be true",
    .return (.arrayGet (.local "flags") (u64 0))
  ]
}

def u32Pick : Entrypoint := {
  name := "u32_pick"
  selector? := some "a13f4ee0"
  returns := .u32
  body := #[
    .letBind "smalls" (.fixedArray .u32 2) (.arrayLit .u32 #[u32 3, u32 5]),
    .return (.arrayGet (.local "smalls") (u32 1))
  ]
}

def hashPick : Entrypoint := {
  name := "hash_pick"
  selector? := some "211a2fc4"
  returns := .hash
  body := #[
    .letBind "roots" (.fixedArray .hash 2) (.arrayLit .hash #[hash 1 2 3 4, hash 5 6 7 8]),
    .return (.arrayGet (.local "roots") (u64 0))
  ]
}

def module : Module := {
  name := "EvmArrayValueProbe"
  state := #[]
  entrypoints := #[localSum, directLiteralIndex, boolGuard, u32Pick, hashPick]
}

end ProofForge.IR.Examples.EvmArrayValueProbe
