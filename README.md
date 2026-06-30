# ProofForge

Lean-first multi-chain smart contract platform.

ProofForge's long-term goal is one verified Lean contract codebase that can be
compiled, tested, and deployed across multiple blockchain target families. The
current repository contains the EVM backend baseline and the first design docs
for expanding toward Solana/sBPF, Wasm-family chains, Move-family chains, and a
future cloud deployment platform.

See [RFC 0001](docs/rfcs/0001-multichain-platform.md) for the multi-chain
architecture and roadmap.
See [RFC 0002](docs/rfcs/0002-target-implementation-design.md) for target
profiles, backend implementation details, and proposed build pipelines.

中文分析文档：

- [ProofForge 多链愿景可行性分析](docs/zh/feasibility-analysis.md)
- [ProofForge 多链技术实现方案](docs/zh/technical-implementation-plan.md)

## Current Implementation

This package keeps the current EVM/Yul backend outside the Lean 4 source tree.
It adds:

- `ProofForge.Evm`: a small EVM contract SDK using `@[extern "lean_evm_*"]`
  primitives.
- `ProofForge.Compiler.Yul`: a Yul AST and printer.
- `ProofForge.Compiler.LCNF.EmitYul`: an LCNF-to-Yul emitter.
- `proof-forge`: a CLI that compiles a Lean file to Yul or EVM runtime
  bytecode without patching `lean`.

The implemented target today is EVM. Solana/sBPF, Wasm-family, and Move-family
targets are design goals, not current compiler outputs.

Build:

```sh
lake build
```

Compile the example:

```sh
lake env proof-forge --root . -o build/counter.yul Examples/Counter.lean
```

Validate the generated Yul if `solc` is installed:

```sh
solc --strict-assembly build/counter.yul --bin
```

Build the EVM contract examples migrated from the Lean fork:

```sh
scripts/evm/build-examples.sh
```

This path expects Foundry (`cast`/`forge`) and `solc` on `PATH`.

Compile one EVM contract directly to runtime bytecode:

```sh
lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
```

Run Foundry smoke tests:

```sh
scripts/evm/foundry-smoke.sh
```

The smoke runner uses Forge's local EVM test runner and `vm.etch` to execute
the generated runtime bytecode.

## Platform Direction

ProofForge uses a portable core plus capabilities model:

- Portable core: business logic, state-machine transitions, math, and proofs.
- Capabilities: explicit chain-facing operations such as storage, caller,
  value transfer, events, cross-contract calls, account/object/resource access,
  and chain environment reads.
- Target adapters: ABI, packaging, test runner, and deployment logic for each
  chain family.

Planned target families:

- EVM: current baseline through Yul, `solc`, and Foundry.
- Solana/sBPF: planned backend for Solana's account and instruction model.
- Wasm family: planned adapters for NEAR, CosmWasm, and Polkadot/ink-style
  contracts.
- Move family: research track for Sui and Aptos.
- Bitcoin ecosystem: research-only for now; not an early direct L1 backend.

Future CLI direction:

```sh
proof-forge build --target evm
proof-forge build --target solana-sbf
proof-forge build --target wasm-near
proof-forge build --target move-sui
```
