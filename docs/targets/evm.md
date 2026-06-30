# EVM Target

Target id: **`evm`**

Stage: **Experimental** — CI smoke tests pass, target registry and portable IR
diagnostic/coverage gates are wired, but artifact metadata is not yet emitted.

Related: [Capability registry](../capability-registry.md),
[Shared scenario](../shared-scenario.md),
[RFC 0002](../rfcs/0002-target-implementation-design.md).

## Pipeline

```text
Lean contract (ProofForge.Evm / Lean.Evm)
  -> Lean frontend / LCNF
  -> EmitYul
  -> Yul AST + Printer
  -> solc --strict-assembly
  -> EVM runtime bytecode
  -> Foundry smoke (vm.etch)
```

## Build Commands

```sh
lake build

lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean

scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
```

## CLI modes

Default Yul mode:

```sh
proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean
```

EVM bytecode mode:

```sh
proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [-o output.bin] input.lean
```

Portable IR EVM fixture modes:

```sh
proof-forge --emit-counter-ir-yul [-o output.yul]
proof-forge --emit-counter-ir-bytecode [--solc solc] [--yul-output output.yul] [-o output.bin]
proof-forge --emit-abi-scalar-ir-yul [-o output.yul]
proof-forge --emit-abi-scalar-ir-bytecode [--solc solc] [--yul-output output.yul] [-o output.bin]
```

`--bytecode` is an alias for `--evm-bytecode`.

`--solc <path>` and `--cast <path>` override external tool paths.

## .evm-methods sidecar format

Each line follows this syntax:

```text
<solidity-signature>=<lean-export-symbol>[view|update]
```

Examples:

```text
get()=l_Counter_get[view]
set(uint256)=l_Counter_set[update]
transfer(uint256,uint256)=l_SimpleToken_transfer[update]
```

Parser rules (from `ProofForge/Cli.lean`):

- Empty lines and `#` comments are ignored.
- Selectors are computed with `cast sig <solidity-signature>`.
- `l_Counter_get` maps to Yul function `f_Counter_get` by stripping leading
  `l_` and prefixing `f_`; this must stay consistent with
  `EmitYul.yulFnName`.
- `view`, `pure`, `return`, `returns`, and `true` mean the dispatch returns a
  value; `update`, `void`, and `false` mean it returns zero bytes unless the
  Lean entrypoint terminates itself with an explicit EVM return.
- EVM bytecode mode requires at least one method.

## Adding or changing an EVM example

1. Add or update the Lean contract under `Examples/Evm/Contracts/`.
2. Add or update the sibling `.evm-methods` file.
3. If the example is part of the baseline, add or update a case in
   `scripts/evm/foundry-smoke.sh`.
4. Run `scripts/evm/build-examples.sh`; run `scripts/evm/foundry-smoke.sh` when
   Foundry and `solc` are available.

## Implemented Capabilities

Mapped to [capability-registry](../capability-registry.md) ids:

| Capability id | SDK surface |
|---|---|
| `storage.scalar` | `Storage.load`, `Storage.store` |
| `storage.map` | `Storage.mapLoad`, `Storage.mapStore` |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `env.block` | `Env.blockNumber`, `Env.balance` |
| `crosscall.invoke` | `call`, `staticcall`, `delegatecall`, `create`, `create2` |
| `events.emit` | `log0`, `log1`, `log2` |

Not supported on EVM (by design for other targets):

- `account.explicit`, `storage.pda`, `crosscall.cpi`

## Module Layout

- `ProofForge/Evm.lean` — EVM SDK (`@[extern "lean_evm_*"]` primitives).
- `ProofForge/Compiler/LCNF/EmitYul.lean` — LCNF to Yul lowering.
- `ProofForge/Compiler/Yul/` — Yul AST and printer.
- `ProofForge/Cli.lean` — `proof-forge` CLI.

Contracts import `ProofForge.Evm` and `open Lean.Evm`.

## Examples

See [Examples/Evm/README.md](../../Examples/Evm/README.md):

- `Counter.lean` — scalar storage
- `SimpleToken.lean` — ERC-20-style token with mappings
- `ArrayExample.lean` — in-memory arrays
- `VerifiedVault.lean` — proofs in contract module
- `stdlib/` — ERC20, Ownable, Pausable

## Known Limits

- `Nat` capped at U256; no bignum on EVM.
- String manipulation APIs incomplete in Yul runtime.
- No unified `proof-forge-artifact.json` yet (planned Workstream 2).
- The production EVM SDK path still lowers through LCNF/EmitYul; the portable
  IR EVM backend currently supports only a Counter-class subset and rejects
  wider portable IR nodes with explicit diagnostics.
- Portable IR EVM currently lacks aggregate ABI values, mappings, storage
  arrays, structs, assertions/reverts, context opcodes, hashing, events,
  cross-contract calls, and artifact metadata.

## Portable IR Gates

The portable IR EVM backend is tracked separately from the older
`ProofForge.Evm` SDK path:

```sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
```

`Tests/EvmCoverage.tsv` records every portable IR constructor as `lowered`,
`validated`, `unsupported`, or `structural` for EVM. New portable IR nodes must
update this manifest before CI passes.

`Tests/EvmDiagnostics.lean` locks the current unsupported-surface behavior so
unsupported EVM IR shapes fail before Yul generation instead of silently
omitting behavior.

`AbiScalarProbe` is the first portable IR EVM ABI fixture beyond Counter. It
validates dispatcher calldata decoding for `U64`, `U32`, and `Bool` parameters,
one-word return data for `U64` and `Bool`, golden Yul reproducibility, solc
bytecode generation, and Foundry runtime behavior including malformed calldata
reverts.

## Metadata

Method dispatch uses `.evm-methods` sidecar files until a unified target
manifest lands (RFC 0002).
