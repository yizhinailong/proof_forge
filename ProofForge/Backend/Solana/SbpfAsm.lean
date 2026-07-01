import Init.Data.String.Basic

/-!
# Solana sBPF Assembly Backend (Phase 0)

This is the first codegen module for the `solana-sbpf-asm` target (D-026).
Phase 0 emits a canned `entrypoint.s` that returns success without parsing
accounts. It validates the blueshift-gg/sbpf toolchain round-trip:

  proof-forge --emit-sbpf-asm -o build/solana/entrypoint.s
  sbpf build                          # → deploy/entrypoint.so (eBPF ELF)
  sbpf disassemble deploy/entrypoint.so

Phase 1 (Workstream 7) will replace `renderCannedEntrypoint` with a real
`ProofForge.IR.Module` → sBPF lowering. See `docs/targets/solana-sbpf-asm.md`.
-/

namespace ProofForge.Backend.Solana.SbpfAsm

/-- Error type for the sBPF assembly backend. -/
structure LowerError where
  message : String
  deriving Repr, Inhabited

def LowerError.render (err : LowerError) : String :=
  err.message

/-- Target id for artifact metadata. -/
def targetId : String := "solana-sbpf-asm"

/-- Artifact kind for artifact metadata. -/
def artifactKind : String := "solana-elf"

/-- IR version recorded in artifact metadata. -/
def irVersion : String := "portable-ir-v0"

/--
Render a canned sBPF entrypoint that returns success (r0 = 0).

This is the Phase 0 spike program. It contains no account parsing, no storage,
and no instruction dispatch — just a valid `.globl entrypoint` that the
blueshift-gg/sbpf assembler accepts and the disassembler round-trips.

The assembly is valid sBPF v3 (the sbpf toolchain default arch):
- `.globl entrypoint` marks the single Solana entry symbol.
- `mov64 r0, 0` sets the return value to success.
- `exit` terminates execution.
-/
def renderCannedEntrypoint : Except LowerError String :=
  .ok (String.intercalate "\n" #[
    "; ProofForge generated sBPF entrypoint (Phase 0 spike)",
    "; Target: solana-sbpf-asm (D-026)",
    "; This canned entrypoint returns success (r0 = 0) without parsing accounts.",
    "; It validates the blueshift-gg/sbpf toolchain round-trip.",
    "; Phase 1 will replace this with real IR → sBPF lowering.",
    "",
    ".globl entrypoint",
    "",
    "entrypoint:",
    "  mov64 r0, 0",
    "  exit",
    ""
  ].toList)

end ProofForge.Backend.Solana.SbpfAsm