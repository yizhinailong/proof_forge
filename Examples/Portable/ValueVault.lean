/-
Portable ValueVault example.

This file exposes the ValueVault contract written through the ProofForge
Contract Surface API, not a backend fixture. The same `spec` can be routed to
EVM, Solana sBPF assembly, Wasm-family profiles, Move-family profiles, and
future targets according to their capability sets.
-/

import ProofForge.Contract.Examples.ValueVault

namespace Examples.Portable.ValueVault

def spec : ProofForge.Contract.ContractSpec :=
  ProofForge.Contract.Examples.ValueVault.spec

def module : ProofForge.IR.Module :=
  ProofForge.Contract.Examples.ValueVault.module

end Examples.Portable.ValueVault
