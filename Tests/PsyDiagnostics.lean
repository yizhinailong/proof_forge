import ProofForge.Backend.Psy.IR
import ProofForge.IR.Contract

namespace ProofForge.Tests.PsyDiagnostics

open ProofForge.IR

def markerState : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def countState : StateDecl := {
  id := "count"
  kind := .scalar
  type := .u64
}

def pointStructNoStorage : StructDecl := {
  name := "Point"
  fields := #[
    { id := "x", type := .u64 }
  ]
}

def unitEntrypoint (name : String) (body : Array Statement := #[]) : Entrypoint := {
  name := name
  returns := .unit
  body := body
}

def unitParamModule : Module := {
  name := "BadUnitParam"
  state := #[markerState]
  entrypoints := #[{
    name := "bad"
    params := #[("x", .unit)]
    returns := .unit
    body := #[]
  }]
}

def zeroArrayParamModule : Module := {
  name := "BadZeroArrayParam"
  state := #[markerState]
  entrypoints := #[{
    name := "bad"
    params := #[("xs", .fixedArray .u64 0)]
    returns := .unit
    body := #[]
  }]
}

def unknownReturnStructModule : Module := {
  name := "BadUnknownReturnStruct"
  state := #[markerState]
  entrypoints := #[{
    name := "bad"
    returns := .structType "Missing"
    body := #[]
  }]
}

def unsupportedMapModule : Module := {
  name := "BadMapShape"
  state := #[{
    id := "bad_map"
    kind := .map .u64 16
    type := .u64
  }]
  entrypoints := #[unitEntrypoint "bad"]
}

def nonStorageStructStateModule : Module := {
  name := "BadStructState"
  structs := #[pointStructNoStorage]
  state := #[{
    id := "current"
    kind := .scalar
    type := .structType "Point"
  }]
  entrypoints := #[unitEntrypoint "bad"]
}

def emptyStructModule : Module := {
  name := "BadEmptyStruct"
  structs := #[{
    name := "Empty"
    fields := #[]
  }]
  state := #[markerState]
  entrypoints := #[unitEntrypoint "bad"]
}

def invalidLoopModule : Module := {
  name := "BadLoop"
  state := #[markerState]
  entrypoints := #[unitEntrypoint "bad" #[
    .boundedFor "_i" 0 0 #[]
  ]]
}

def storageWriteExprModule : Module := {
  name := "BadStorageWriteExpr"
  state := #[countState]
  entrypoints := #[{
    name := "bad"
    returns := .u64
    body := #[
      .return (.effect (.storageScalarWrite "count" (.literal (.u64 1))))
    ]
  }]
}

def storageReadStmtModule : Module := {
  name := "BadStorageReadStmt"
  state := #[countState]
  entrypoints := #[unitEntrypoint "bad" #[
    .effect (.storageScalarRead "count")
  ]]
}

def renderError? (module : Module) : Option String :=
  match ProofForge.Backend.Psy.IR.renderModule module with
  | .ok _ => none
  | .error err => some err.render

def cases : Array (String × Module × String) := #[
  (
    "unit entrypoint parameter",
    unitParamModule,
    "entrypoint `bad` parameter `x` uses Unit; Psy IR v0 entrypoint parameters must use Felt, Bool, Hash, fixed arrays, or declared structs"
  ),
  (
    "zero-length ABI array parameter",
    zeroArrayParamModule,
    "entrypoint `bad` parameter `xs` uses a zero-length fixed array; Psy IR v0 fixed arrays must have non-zero length"
  ),
  (
    "unknown struct return type",
    unknownReturnStructModule,
    "entrypoint `bad` return type references unknown struct type `Missing`"
  ),
  (
    "unsupported map key/value shape",
    unsupportedMapModule,
    "map state `bad_map` has unsupported Psy IR v0 type Map<U64, U64>; only Map<Hash, Hash, N> is supported"
  ),
  (
    "non-storage struct state",
    nonStorageStructStateModule,
    "state `current` uses struct `Point`, but the struct is not marked deriveStorage"
  ),
  (
    "empty struct declaration",
    emptyStructModule,
    "struct `Empty` must declare at least one field"
  ),
  (
    "invalid bounded loop range",
    invalidLoopModule,
    "bounded loop `_i` must have stop greater than start"
  ),
  (
    "storage write used as expression",
    storageWriteExprModule,
    "storage.scalar.write is a statement effect, not an expression"
  ),
  (
    "storage read used as statement",
    storageReadStmtModule,
    "storage.scalar.read must be used as an expression"
  )
]

def checkCase (name : String) (module : Module) (expected : String) : IO Bool := do
  match renderError? module with
  | some actual =>
      if actual == expected then
        IO.println s!"psy-diagnostics: ok: {name}"
        pure true
      else
        IO.eprintln s!"psy-diagnostics: FAILED: {name}"
        IO.eprintln s!"  expected: {expected}"
        IO.eprintln s!"  actual:   {actual}"
        pure false
  | none =>
      IO.eprintln s!"psy-diagnostics: FAILED: {name}"
      IO.eprintln "  expected an error, but Psy source generation succeeded"
      pure false

def main : IO UInt32 := do
  let mut failures : Nat := 0
  for (name, module, expected) in cases do
    let ok ← checkCase name module expected
    if !ok then
      failures := failures + 1
  if failures == 0 then
    IO.println s!"psy-diagnostics: {cases.size} cases passed"
    pure 0
  else
    IO.eprintln s!"psy-diagnostics: {failures} case(s) failed"
    pure 1

end ProofForge.Tests.PsyDiagnostics

def main : IO UInt32 :=
  ProofForge.Tests.PsyDiagnostics.main
