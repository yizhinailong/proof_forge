import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Contract
import ProofForge.IR.Examples.MapProbe
open ProofForge.IR ProofForge.IR.Examples MapProbe ProofForge.Backend.WasmNear.EmitWat

/-! Render the path-storage subset of MapProbe (storagePathRead/Write, mapKey segment). -/

def pathAssignState : StateDecl := {
  id := "scores"
  kind := .map .u64 8
  type := .u64
}

def u64 (value : Nat) : Expr :=
  .literal (.u64 value)

def pathAssignLifecycle : Entrypoint := {
  name := "path_assign_lifecycle"
  returns := .u64
  body := #[
    .effect (.storagePathWrite "scores" #[.mapKey (u64 7)] (u64 10)),
    .effect (.storagePathAssignOp "scores" #[.mapKey (u64 7)] .add (u64 5)),
    .effect (.storagePathAssignOp "scores" #[.mapKey (u64 7)] .mul (u64 2)),
    .return (.effect (.storagePathRead "scores" #[.mapKey (u64 7)]))
  ]
}

def pathAssignModule : Module := {
  name := "PathAssignProbe"
  state := #[pathAssignState]
  entrypoints := #[pathAssignLifecycle]
}

def main : IO UInt32 := do
  let render (module : Module) (path : String) : IO UInt32 := do
    match renderModule module with
    | .ok wat =>
        IO.FS.createDirAll "build/wasm-near"
        IO.FS.writeFile path wat
        IO.println s!"wrote {path} ({wat.length} bytes)"
        pure 0
    | .error e => IO.eprintln e.message *> pure 1
  let r1 ← render emitWatPathModule "build/wasm-near/emitwat-path.wat"
  let r2 ← render pathAssignModule "build/wasm-near/emitwat-path-assign.wat"
  if r1 == 0 && r2 == 0 then pure 0 else pure 1
