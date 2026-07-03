import ProofForge.Cli

namespace ProofForge.Tests.CliTargetFirst

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireLegacy (args expected : List String) : IO Unit :=
  match ProofForge.Cli.newCommandArgsToLegacy args with
  | .ok got =>
      require (got == expected) s!"legacy args mismatch: got {repr got}, expected {repr expected}"
  | .error err =>
      throw <| IO.userError s!"unexpected CLI mapping error: {err}"

def main : IO UInt32 := do
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "system-cpi", "--format", "s"]
    ["--emit-solana-system-cpi-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "system-cpi"]
    ["--emit-solana-system-cpi-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "system-cpi", "--format", "elf"]
    ["--solana-system-cpi-elf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "system-cpi", "--format", "elf", "--solana-sbpf-arch", "v0"]
    ["--solana-system-cpi-elf", "--solana-sbpf-arch", "v0"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "spl-token-ops-cpi", "--format", "s"]
    ["--emit-solana-spl-token-ops-cpi-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "spl-token-ops-cpi"]
    ["--emit-solana-spl-token-ops-cpi-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "counter", "--format", "elf"]
    ["--solana-elf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "solana-sdk", "--format", "s"]
    ["--emit-solana-sdk-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "value-vault", "--format", "s"]
    ["--emit-value-vault-ir-sbpf"]
  requireLegacy
    ["emit", "--target", "solana-sbpf-asm", "--fixture", "value-vault", "--format", "elf"]
    ["--value-vault-solana-elf"]
  requireLegacy
    ["emit", "--target", "wasm-cloudflare-workers", "--fixture", "counter", "--format", "ts"]
    ["--emit-counter-ir-ts"]

  IO.println "cli-target-first: ok"
  return 0

end ProofForge.Tests.CliTargetFirst

#eval ProofForge.Tests.CliTargetFirst.main
