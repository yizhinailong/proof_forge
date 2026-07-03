import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Examples.ErrorRefProbe

open ProofForge.Backend.WasmNear.EmitWat

def main : IO UInt32 := do
  match renderModule ProofForge.IR.Examples.ErrorRefProbe.module with
  | .ok wat =>
    IO.FS.createDirAll "build/wasm-near"
    IO.FS.writeFile "build/wasm-near/emitwat-error-ref.wat" wat
    IO.println s!"wrote build/wasm-near/emitwat-error-ref.wat ({wat.length} bytes)"
    pure 0
  | .error e =>
    IO.eprintln s!"EmitWat failed: {e.message}"
    pure 1
