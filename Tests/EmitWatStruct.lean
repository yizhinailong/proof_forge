import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Examples.StructProbe
open ProofForge.IR.Examples StructProbe ProofForge.Backend.WasmNear.EmitWat

/-! Render the full StructProbe module: localSum (structLit+field) + storageLifecycle (struct storage write/field-read/field-write). -/

def main : IO UInt32 := do
  match renderModule module with
  | .ok wat =>
      let path := "build/wasm-near/emitwat-struct-full.wat"
      IO.FS.createDirAll "build/wasm-near"
      IO.FS.writeFile path wat
      IO.println s!"wrote {path} ({wat.length} bytes)"
      pure 0
  | .error e => IO.eprintln e.message *> pure 1