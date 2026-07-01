import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Examples.ArrayProbe
open ProofForge.IR.Examples ArrayProbe ProofForge.Backend.WasmNear.EmitWat

/-! Render the storage-array subset of ArrayProbe (storageArrayRead/Write). -/

def main : IO UInt32 := do
  match renderModule emitWatStorageModule with
  | .ok wat =>
      let path := "build/wasm-near/emitwat-array.wat"
      IO.FS.createDirAll "build/wasm-near"
      IO.FS.writeFile path wat
      IO.println s!"wrote {path} ({wat.length} bytes)"
      pure 0
  | .error e => IO.eprintln e.message *> pure 1
