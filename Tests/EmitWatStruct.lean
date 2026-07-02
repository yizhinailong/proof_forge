import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Contract
import ProofForge.IR.Examples.StructProbe
open ProofForge.IR ProofForge.IR.Examples StructProbe ProofForge.Backend.WasmNear.EmitWat

/-! Render the full StructProbe module: localSum (structLit+field) + storageLifecycle (struct storage write/field-read/field-write). -/

def statePoints : StateDecl := {
  id := "points"
  kind := .array 2
  type := .structType "Point"
}

def arrayStructLifecycle : Entrypoint := {
  name := "array_struct_lifecycle"
  returns := .u64
  body := #[
    .effect (.storageArrayStructFieldWrite "points" (felt 0) "x" (felt 7)),
    .effect (.storageArrayStructFieldWrite "points" (felt 0) "y" (felt 11)),
    .effect (.storageArrayStructFieldWrite "points" (felt 0) "x" (felt 19)),
    .return (.add
      (.effect (.storageArrayStructFieldRead "points" (felt 0) "x"))
      (.effect (.storageArrayStructFieldRead "points" (felt 0) "y")))
  ]
}

def arrayStructModule : Module := {
  name := "ArrayStructProbe"
  structs := #[pointStruct]
  state := #[statePoints]
  entrypoints := #[arrayStructLifecycle]
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
  let r1 ← render module "build/wasm-near/emitwat-struct-full.wat"
  let r2 ← render arrayStructModule "build/wasm-near/emitwat-array-struct.wat"
  if r1 == 0 && r2 == 0 then pure 0 else pure 1
