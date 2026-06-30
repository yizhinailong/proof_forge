import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.StorageNestedAggregateProbe

open ProofForge.IR

def profileStruct : StructDecl := {
  name := "Profile"
  deriveStorage := true
  fields := #[
    { id := "age", type := .u64 },
    { id := "level", type := .u64 }
  ]
}

def personStruct : StructDecl := {
  name := "Person"
  deriveStorage := true
  fields := #[
    { id := "profile", type := .structType "Profile", isRef := true },
    { id := "score", type := .u64 }
  ]
}

def statePerson : StateDecl := {
  id := "person"
  kind := .scalar
  type := .structType "Person"
}

def statePeople : StateDecl := {
  id := "people"
  kind := .array 2
  type := .structType "Person"
}

def stateTotal : StateDecl := {
  id := "total"
  kind := .scalar
  type := .u64
}

def felt (value : Nat) : Expr :=
  .literal (.u64 value)

def ix (value : Nat) : Expr :=
  .literal (.u64 value)

def profile (age level : Nat) : Expr :=
  .structLit "Profile" #[
    ("age", felt age),
    ("level", felt level)
  ]

def person (age level score : Nat) : Expr :=
  .structLit "Person" #[
    ("profile", profile age level),
    ("score", felt score)
  ]

def personProfileAgePath : Array StoragePathSegment :=
  #[.field "profile", .field "age"]

def personProfileLevelPath : Array StoragePathSegment :=
  #[.field "profile", .field "level"]

def personProfilePath : Array StoragePathSegment :=
  #[.field "profile"]

def personScorePath : Array StoragePathSegment :=
  #[.field "score"]

def people1ProfileAgePath : Array StoragePathSegment :=
  #[.index (ix 1), .field "profile", .field "age"]

def people1ScorePath : Array StoragePathSegment :=
  #[.index (ix 1), .field "score"]

def readPath (stateId : String) (path : Array StoragePathSegment) : Expr :=
  .effect (.storagePathRead stateId path)

def storageNestedLifecycle : Entrypoint := {
  name := "storage_nested_lifecycle"
  returns := .u64
  body := #[
    .effect (.storageScalarWrite "total" (felt 20)),
    .effect (.storageScalarAssignOp "total" .add (felt 3)),
    .effect (.storageScalarAssignOp "total" .sub (felt 1)),
    .effect (.storageScalarAssignOp "total" .mul (felt 2)),
    .effect (.storageScalarAssignOp "total" .div (felt 11)),
    .effect (.storageScalarAssignOp "total" .mod (felt 4)),
    .effect (.storageScalarAssignOp "total" .bitOr (felt 8)),
    .effect (.storageScalarAssignOp "total" .bitAnd (felt 10)),
    .effect (.storageScalarAssignOp "total" .bitXor (felt 3)),
    .effect (.storageScalarAssignOp "total" .shiftLeft (felt 1)),
    .effect (.storageScalarAssignOp "total" .shiftRight (felt 1)),
    .effect (.storageScalarWrite "person" (person 18 2 50)),
    .effect (.storagePathWrite "person" personProfilePath (profile 21 4)),
    .effect (.storagePathWrite "person" personScorePath (felt 55)),
    .effect (.storageArrayWrite "people" (ix 1) (person 30 7 100)),
    .effect (.storagePathAssignOp "person" personProfileAgePath .add (felt 2)),
    .effect (.storagePathAssignOp "person" personScorePath .add (felt 5)),
    .effect (.storagePathWrite "people" people1ProfileAgePath (felt 31)),
    .effect (.storagePathWrite "people" people1ScorePath (felt 109)),
    .effect (.storagePathAssignOp "people" people1ScorePath .sub (felt 9)),
    .return (.add
      (.add
        (.add
          (.add
            (readPath "person" personProfileAgePath)
            (readPath "person" personProfileLevelPath))
          (readPath "person" personScorePath))
        (readPath "people" people1ProfileAgePath))
      (.add
        (readPath "people" people1ScorePath)
        (.effect (.storageScalarRead "total"))))
  ]
}

def module : Module := {
  name := "StorageNestedAggregateProbe"
  structs := #[profileStruct, personStruct]
  state := #[statePerson, statePeople, stateTotal]
  entrypoints := #[storageNestedLifecycle]
}

end ProofForge.IR.Examples.StorageNestedAggregateProbe
