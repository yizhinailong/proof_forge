# ProofForge EVM Examples

This directory is a self-contained example repository for writing EVM smart
contracts in Lean and compiling them through EmitYul.

It demonstrates the `ProofForge.Evm` SDK in [`ProofForge/Evm.lean`](../../ProofForge/Evm.lean).
Import the module as `ProofForge.Evm` and use the `Lean.Evm` namespace (`open Lean.Evm`).

See [docs/targets/evm.md](../../docs/targets/evm.md) for the canonical source on CLI modes, `.evm-methods` sidecar format, capability mapping, and known limits.

- `Counter.lean` uses `Storage.load`/`store` for a simple counter with
  `get`/`set`/`increment`/`decrement` methods.
- `SimpleToken.lean` is an ERC-20-style token with owner access control,
  `Storage.mapLoad`/`mapStore` for balances, and conditional transfers.
- `ArrayExample.lean` demonstrates in-memory `Array Nat` literals, element
  access (`xs[i]!`), size queries, and arithmetic over array elements.

## Build all examples

From the repository root:

```bash
scripts/evm/build-examples.sh
```

This compiles each `.lean` contract to EVM bytecode via
`proof-forge --evm-bytecode`
(Lean -> EmitYul -> Yul -> `solc --strict-assembly` -> bytecode).
It also diffs generated Yul against the sibling `.golden.yul` fixtures and
validates ProofForge artifact/deploy metadata. It expects Foundry
(`cast`/`forge`) and `solc` on `PATH`.

## Run Foundry smoke tests

```bash
scripts/evm/foundry-smoke.sh
```

This compiles the examples and runs Forge tests against the generated runtime
bytecode using Foundry's `vm.etch` cheatcode.

## Current EVM support

The support is enough to write and deploy small Lean EVM contracts through
`proof-forge --evm-bytecode`:

- Contract methods: selector dispatch via 4-byte function selectors (`.evm-methods` files).
- Storage: `Storage.load`/`store` (sload/sstore), `Storage.mapLoad`/`mapStore` (mapping via keccak256).
- Environment: `Env.sender` (caller), `Env.value` (msg.value), `Env.blockNumber`, `Env.balance`.
- Arithmetic: Nat add/sub/mul/div/mod, comparisons, bitwise ops (all U256-capped).
- Control flow: if-then-else, match, Bool logic.
- Arrays: literal construction (`#[...]`), element access (`xs[i]!`), size.
- Externals: `call`, `staticcall`, `delegatecall`, `create`, `create2`, `selfdestruct`.
- Events: `log0`/`log1`/`log2`.
- Revert: bare `revert` and `revertWithReason` (Solidity `Error(string)` ABI).

There are still important limits:

- `Nat` is capped at U256 (reverts on overflow); there is no bignum/GMP on EVM.
- `String` literals are allocated but string manipulation APIs (concat, compare)
  are not fully implemented in the Yul runtime yet.
- The standalone `proof-forge` CLI uses a `runFrontend` path; it does not patch
  the upstream `lean` binary.
