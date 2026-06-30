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
See [docs/INDEX.md](docs/INDEX.md) for the full documentation map.

中文分析文档：

- [ProofForge 多链愿景可行性分析](docs/zh/feasibility-analysis.md)
- [ProofForge 多链技术实现方案](docs/zh/technical-implementation-plan.md)
- [ProofForge 多链方案 Review 清单](docs/zh/review-checklist.md)

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
lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
```

For Yul-only output:

```sh
lake env proof-forge --root . -o build/counter.yul Examples/Evm/Contracts/Counter.lean
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

Generate and validate the current Psy/DPN Counter IR spike:

```sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
scripts/psy/counter-smoke.sh
```

Validate the Psy/DPN context fixture, which exercises parameter lowering and
Psy context reads:

```sh
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
scripts/psy/context-smoke.sh
```

Validate the Psy/DPN hash fixture, which exercises `crypto.hash` through
Psy `hash` and `hash_two_to_one`:

```sh
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
scripts/psy/hash-smoke.sh
```

The Psy smoke expects `dargo` on `PATH`. The preferred installer is `psyup`:

```sh
curl -fsSL https://raw.githubusercontent.com/QEDProtocol/psyup/main/install.sh | bash
```

On macOS arm64, `psyup` latest may not currently publish a matching toolchain
tarball. `psyup install 0.1.0` is known to provide
`psy-toolchain-v0.1.0-aarch64-apple-darwin.tar.gz`.

## Development Docs

- [Development standards](docs/development-standards.md)
- [Validation gates](docs/validation-gates.md)
- [EVM target notes](docs/targets/evm.md)
- [Capability registry](docs/capability-registry.md)

## Module naming

- **Lake module:** `ProofForge.Evm` (import in contract files).
- **Lean namespace:** `Lean.Evm` (use via `open Lean.Evm` in examples).

This split comes from the Lean fork migration; new code should keep both names
until a rename is scheduled.

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
proof-forge build --target wasm-near        # planned reference target
proof-forge build --target wasm-cosmwasm    # planned first new Wasm spike
proof-forge build --target solana-sbpf-linker
proof-forge build --target move-aptos       # planned first Move POC
proof-forge build --target move-sui         # planned follow-up Move target
```

`proof-forge build --target ...` is planned; the implemented command remains
`proof-forge --evm-bytecode`.

Canonical target ids: [docs/decisions.md](docs/decisions.md). The filename
`docs/targets/solana-sbf.md` is a historical alias for the Solana target notes.
