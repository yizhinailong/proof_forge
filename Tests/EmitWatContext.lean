import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Contract

open ProofForge.IR ProofForge.Backend.WasmNear.EmitWat

/-! Context probe: predecessor/contract id determinism (sha256 of account id),
    and block_height (checkpoint). -/

def callerStable : Entrypoint := {
  name := "callerStable", returns := .u64,
  body := #[
    .assertEq (.effect (.contextRead .userId)) (.effect (.contextRead .userId)) "caller unstable",
    .return (.literal (.u64 1)) ] }

def contractStable : Entrypoint := {
  name := "contractStable", returns := .u64,
  body := #[
    .assertEq (.effect (.contextRead .contractId)) (.effect (.contextRead .contractId)) "contract id unstable",
    .return (.literal (.u64 1)) ] }

def checkpoint : Entrypoint := {
  name := "checkpoint", returns := .u64,
  body := #[.return (.effect (.contextRead .checkpointId))] }

def contextModule : Module := {
  name := "ContextProbe", state := #[],
  entrypoints := #[callerStable, contractStable, checkpoint] }

def main : IO UInt32 := do
  match renderModule contextModule with
  | .ok wat =>
    IO.FS.createDirAll "build/wasm-near"
    IO.FS.writeFile "build/wasm-near/emitwat-context.wat" wat
    IO.println s!"wrote build/wasm-near/emitwat-context.wat ({wat.length} bytes)"
    pure 0
  | .error e =>
    IO.eprintln s!"EmitWat failed: {e.message}"
    pure 1
