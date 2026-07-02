/-
Portable ValueVault example.

This file is intentionally a normal ProofForge Contract Builder source, not a
backend fixture. The same `spec` can be routed to EVM, Solana sBPF assembly,
Wasm-family profiles, Move-family profiles, and future targets according to
their capability sets.
-/

import ProofForge.Contract.Examples.ValueVault

namespace Examples.Portable.ValueVault

def spec : ProofForge.Contract.ContractSpec :=
  ProofForge.Contract.Examples.ValueVault.spec

def module : ProofForge.IR.Module :=
  ProofForge.Contract.Examples.ValueVault.module

end Examples.Portable.ValueVault
