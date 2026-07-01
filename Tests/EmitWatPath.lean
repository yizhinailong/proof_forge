import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Examples.MapProbe
open ProofForge.IR.Examples MapProbe ProofForge.Backend.WasmNear.EmitWat

/-! Render the path-storage subset of MapProbe (storagePathRead/Write, mapKey segment). -/

def main : IO UInt32 := do
  match renderModule emitWatPathModule with
  | .ok wat =>
      let path := "build/wasm-near/emitwat-path.wat"
      IO.FS.createDirAll "build/wasm-near"
      IO.FS.writeFile path wat
      IO.println s!"wrote {path} ({wat.length} bytes)"
      pure 0
  | .error e => IO.eprintln e.message *> pure 1
