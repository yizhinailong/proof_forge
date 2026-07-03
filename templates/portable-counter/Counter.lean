/-
Minimal ProofForge portable starter contract.

This source is chain-neutral: it lowers to ContractSpec / portable IR. The
selected `--target` decides whether ProofForge emits EVM Yul/bytecode, Solana
sBPF assembly/ELF, NEAR WAT/Wasm, or another target artifact.
-/
import ProofForge.Contract.Source

namespace Templates.PortableCounter

open ProofForge.Contract.Source

contract_source Counter do
  state count : .u64

  entry «initialize» do
    count := u64 0;

  entry increment do
    let current : .u64 := count;
    count := current +! u64 1;

  query get returns(.u64) do
    return count;

end Templates.PortableCounter
