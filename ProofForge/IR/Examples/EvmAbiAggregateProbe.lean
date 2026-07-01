import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EvmAbiAggregateProbe

open ProofForge.IR

def pairStruct : StructDecl := {
  name := "Pair"
  fields := #[
    { id := "left", type := .u64 },
    { id := "right", type := .u64 }
  ]
}

def flagsStruct : StructDecl := {
  name := "Flags"
  fields := #[
    { id := "enabled", type := .bool },
    { id := "archived", type := .bool }
  ]
}

def u32 (value : Nat) : Expr :=
  .literal (.u32 value)

def u64 (value : Nat) : Expr :=
  .literal (.u64 value)

def pair (left right : Expr) : Expr :=
  .structLit "Pair" #[
    ("left", left),
    ("right", right)
  ]

def sumPair : Entrypoint := {
  name := "sum_pair"
  selector? := some "25508e13"
  params := #[
    ("pair", .structType "Pair")
  ]
  returns := .u64
  body := #[
    .return (.add
      (.field (.local "pair") "left")
      (.field (.local "pair") "right"))
  ]
}

def sumArray : Entrypoint := {
  name := "sum_array"
  selector? := some "eb353b80"
  params := #[
    ("xs", .fixedArray .u64 3)
  ]
  returns := .u64
  body := #[
    .return (.add
      (.add
        (.arrayGet (.local "xs") (u64 0))
        (.arrayGet (.local "xs") (u64 1)))
      (.arrayGet (.local "xs") (u64 2)))
  ]
}

def sumPairArray : Entrypoint := {
  name := "sum_pair_array"
  selector? := some "10e4c1da"
  params := #[
    ("pairs", .fixedArray (.structType "Pair") 2)
  ]
  returns := .u64
  body := #[
    .return (.add
      (.add
        (.field (.arrayGet (.local "pairs") (u64 0)) "left")
        (.field (.arrayGet (.local "pairs") (u64 0)) "right"))
      (.add
        (.field (.arrayGet (.local "pairs") (u64 1)) "left")
        (.field (.arrayGet (.local "pairs") (u64 1)) "right"))
    )
  ]
}

def makePair : Entrypoint := {
  name := "make_pair"
  selector? := some "ef51ff62"
  params := #[
    ("left", .u64),
    ("right", .u64)
  ]
  returns := .structType "Pair"
  body := #[
    .return (pair (.local "left") (.local "right"))
  ]
}

def makePairArray : Entrypoint := {
  name := "make_pair_array"
  selector? := some "617df171"
  params := #[
    ("a", .u64),
    ("b", .u64),
    ("c", .u64),
    ("d", .u64)
  ]
  returns := .fixedArray (.structType "Pair") 2
  body := #[
    .letBind "pairs" (.fixedArray (.structType "Pair") 2) (.arrayLit (.structType "Pair") #[
      pair (.local "a") (.local "b"),
      pair (.local "c") (.local "d")
    ]),
    .return (.local "pairs")
  ]
}

def makeArray : Entrypoint := {
  name := "make_array"
  selector? := some "ffac5c16"
  params := #[
    ("a", .u64),
    ("b", .u64),
    ("c", .u64)
  ]
  returns := .fixedArray .u64 3
  body := #[
    .letBind "xs" (.fixedArray .u64 3) (.arrayLit .u64 #[.local "a", .local "b", .local "c"]),
    .return (.local "xs")
  ]
}

def sumSmall : Entrypoint := {
  name := "sum_small"
  selector? := some "384e9976"
  params := #[
    ("xs", .fixedArray .u32 2)
  ]
  returns := .u32
  body := #[
    .return (.add
      (.arrayGet (.local "xs") (u32 0))
      (.arrayGet (.local "xs") (u32 1)))
  ]
}

def andFlags : Entrypoint := {
  name := "and_flags"
  selector? := some "1df89823"
  params := #[
    ("flags", .structType "Flags")
  ]
  returns := .bool
  body := #[
    .return (.boolAnd
      (.field (.local "flags") "enabled")
      (.field (.local "flags") "archived"))
  ]
}

def module : Module := {
  name := "EvmAbiAggregateProbe"
  structs := #[pairStruct, flagsStruct]
  state := #[]
  entrypoints := #[sumPair, sumArray, sumPairArray, makePair, makePairArray, makeArray, sumSmall, andFlags]
}

end ProofForge.IR.Examples.EvmAbiAggregateProbe
