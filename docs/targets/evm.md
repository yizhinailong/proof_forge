# EVM Target

Target id: **`evm`**

Stage: **Experimental** — CI smoke tests, target registry, portable IR
diagnostic/coverage gates, and EVM artifact metadata validation are wired.

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
  --artifact-output build/evm/Counter.proof-forge-artifact.json \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean

scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assign-op-ir-smoke.sh
scripts/evm/conditional-ir-smoke.sh
scripts/evm/loop-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/typed-storage-ir-smoke.sh
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/abi-aggregate-ir-smoke.sh
```

## CLI modes

Default Yul mode:

```sh
proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean
```

EVM bytecode mode:

```sh
proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [--artifact-output file] [-o output.bin] input.lean
```

Portable IR EVM fixture modes:

```sh
proof-forge --emit-counter-ir-yul [-o output.yul]
proof-forge --emit-counter-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-abi-scalar-ir-yul [-o output.yul]
proof-forge --emit-abi-scalar-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-assert-ir-yul [-o output.yul]
proof-forge --emit-assert-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-assignment-ir-yul [-o output.yul]
proof-forge --emit-assignment-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-assign-op-ir-yul [-o output.yul]
proof-forge --emit-evm-assign-op-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-conditional-ir-yul [-o output.yul]
proof-forge --emit-conditional-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-loop-ir-yul [-o output.yul]
proof-forge --emit-evm-loop-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-context-ir-yul [-o output.yul]
proof-forge --emit-context-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-event-ir-yul [-o output.yul]
proof-forge --emit-evm-event-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-crosscall-ir-yul [-o output.yul]
proof-forge --emit-evm-crosscall-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-expression-ir-yul [-o output.yul]
proof-forge --emit-evm-expression-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-hash-ir-yul [-o output.yul]
proof-forge --emit-evm-hash-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-map-ir-yul [-o output.yul]
proof-forge --emit-evm-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-storage-array-ir-yul [-o output.yul]
proof-forge --emit-evm-storage-array-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-storage-struct-ir-yul [-o output.yul]
proof-forge --emit-evm-storage-struct-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-typed-storage-ir-yul [-o output.yul]
proof-forge --emit-evm-typed-storage-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-array-value-ir-yul [-o output.yul]
proof-forge --emit-evm-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-struct-array-value-ir-yul [-o output.yul]
proof-forge --emit-evm-struct-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-struct-value-ir-yul [-o output.yul]
proof-forge --emit-evm-struct-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-abi-aggregate-ir-yul [-o output.yul]
proof-forge --emit-evm-abi-aggregate-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
```

`--bytecode` is an alias for `--evm-bytecode`.

`--solc <path>` and `--cast <path>` override external tool paths.
`--artifact-output <path>` overrides the default EVM metadata path. Without an
override, bytecode modes write `proof-forge-artifact.json` next to the bytecode
output and `proof-forge-deploy.json` next to the metadata file. When smoke
scripts pass fixture-specific metadata paths such as
`Counter.proof-forge-artifact.json`, the deploy manifest is written as
`Counter.proof-forge-deploy.json`.

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

| Capability id | SDK / IR surface |
|---|---|
| `storage.scalar` | `Storage.load`, `Storage.store`; portable IR `Bool`/`U32`/`U64`/`Hash` scalar storage read/write, scalar storage compound assignment for numeric words, flat scalar storage struct field read/write, and whole flat scalar storage struct read/write |
| `storage.map` | `Storage.mapLoad`, `Storage.mapStore`; portable IR `Map<K, V, N>` get/set/insert/contains and single-segment map storage paths where `K` and `V` are word types (`Bool`, `U32`, `U64`, or `Hash`); `contains` uses ProofForge-managed presence slots so zero-valued keys can still be present |
| `storage.array` | Partial: portable IR `Bool`/`U32`/`U64`/`Hash` fixed storage arrays and fixed arrays of flat structs lower to contiguous EVM storage slots with runtime index bounds checks |
| `data.fixed_array` | Partial: used by portable IR fixed storage arrays, single-segment index storage paths over word arrays, index+field storage paths over struct arrays, immutable and mutable local fixed-array values, fixed-array literals, static and dynamic local/literal index reads, static and dynamic local element assignment/compound assignment, whole local fixed-array assignment with RHS snapshotting, local fixed arrays of flat structs with static/dynamic field reads and writes plus whole local assignment with RHS snapshotting, flat static fixed-array ABI parameters/returns, fixed-array ABI parameters/returns whose elements are flat structs, scalar fixed-array non-indexed event data fields, and fixed-array event data fields whose elements are flat structs; zero-length ABI arrays, nested arrays, and unsupported element shapes still reject explicitly |
| `data.struct` | Partial: portable IR flat immutable and mutable local struct values, flat struct elements inside local fixed arrays, struct literals, field access, static local field assignment/compound assignment, whole local struct assignment with RHS snapshotting, flat ABI-facing struct parameters/returns, fixed arrays of flat structs in ABI-facing parameters/returns, flat non-indexed event data fields, flat scalar storage structs including whole read/write, and fixed storage arrays of flat structs lower by expanding supported fields to EVM words; nested fields and unsupported field shapes still reject explicitly |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `env.block` | `Env.blockNumber`, `Env.balance` |
| `crosscall.invoke` | SDK `call`, `staticcall`, `delegatecall`, `create`, `create2`; portable IR `crosscallInvoke` lowers to synchronous EVM `call` with a low-32-bit selector, 32-byte word arguments, failed-call reverts, and short-return reverts; `crosscallInvokeTyped` adds Bool/U32/U64/Hash scalar-word arguments and returns with Bool/U32 return guards; `crosscallInvokeValueTyped` forwards an explicit U64 call value through the EVM `call` value slot |
| `events.emit` | `log0` through `log4`; portable IR `eventEmit` lowers to `log1`, `eventEmitIndexed` lowers up to `log4`, topic0 is derived from a Solidity-style event signature, and non-indexed data fields can be scalar words, flat structs, scalar fixed arrays, or fixed arrays of flat structs |
| `assertions.check` | Portable IR `assert` / `assert_eq` lower to Yul revert guards |
| `control.conditional` | Portable IR `if/else` lowers to Yul `switch` blocks |
| `control.bounded_loop` | Portable IR `boundedFor` lowers to Yul `for` loops with static bounds |
| `crypto.hash` | Portable IR `Hash` values lower to one-word EVM `bytes32`; `hash` / `hash_two_to_one` lower to Yul `keccak256` helpers |
| `account.explicit` | Partial: portable IR `contractId` context reads lower to Yul `address()` |

Not supported on EVM (by design for other targets):

- `storage.pda`, `crosscall.cpi`

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
- The production EVM SDK path still lowers through LCNF/EmitYul; the portable
  IR EVM backend currently supports scalar storage/ABI, assertions, local
  assignment, local compound assignment, scalar storage compound assignment,
  conditionals, context reads, scalar and flat aggregate event data, `Hash`
  word values and hashing,
  word key/value `Map<K, V, N>` storage including managed key presence,
  `Bool`/`U32`/`U64`/`Hash` fixed
  storage arrays, flat scalar storage structs, fixed storage arrays of flat
  structs, immutable and mutable local fixed-array values with static and
  dynamic indexes,
  flat immutable and mutable local struct values over scalar/hash fields, local
  fixed arrays of flat structs with static and dynamic field access, flat static
  aggregate ABI parameters and returns, synchronous word-returning
  `crosscallInvoke`, typed scalar-word `crosscallInvokeTyped` over
  `Bool`/`U32`/`U64`/`Hash`, value-bearing typed scalar
  `crosscallInvokeValueTyped`, static bounded loops, and branch/loop-local
  early returns through Yul `leave`. It rejects wider portable IR nodes with
  explicit diagnostics.
- Portable IR EVM currently lacks dynamic or nested aggregate ABI values,
  non-word or aggregate map shapes, nested arrays, nested local structs beyond
  flat struct arrays, richer event declarations,
  `staticcall`/`delegatecall`/contract-creation IR nodes, aggregate or
  variable-length cross-call return data, and real creation-transaction or
  broadcast manifests.

## Portable IR Gates

The portable IR EVM backend is tracked separately from the older
`ProofForge.Evm` SDK path:

```sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assign-op-ir-smoke.sh
scripts/evm/conditional-ir-smoke.sh
scripts/evm/loop-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/expression-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
scripts/evm/typed-map-ir-smoke.sh
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/storage-struct-ir-smoke.sh
scripts/evm/typed-storage-ir-smoke.sh
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/abi-aggregate-ir-smoke.sh
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

`EvmAbiAggregateProbe` validates flat static aggregate ABI lowering. Struct
parameters, fixed-array parameters, and fixed arrays whose elements are flat
structs flatten to contiguous calldata words. `U32` and `Bool` words retain
dispatcher range guards, and flat struct/fixed-array returns, including fixed
arrays of flat structs, encode as multi-word ABI return data. The smoke checks
golden Yul reproducibility, `solc --strict-assembly`, artifact metadata
capabilities `data.struct` and `data.fixed_array`, Foundry calls for struct,
array, and tuple-array parameters/returns, malformed calldata reverts, and
unknown-selector reverts.

`AssertProbe` validates portable IR `assert` and `assert_eq` lowering to Yul
`if iszero(...) { revert(0, 0) }` guards, including Foundry coverage for the
passing path and the assertion-failure revert path.

`AssignmentProbe` validates portable IR mutable scalar local bindings and local
assignment lowering to Yul `let` declarations and `:=` assignments. The smoke
checks golden Yul reproducibility, `solc --strict-assembly` bytecode generation,
successful Foundry execution, and the revert path when the assigned bool guard
is false.

`EvmAssignOpProbe` validates portable IR compound assignment for mutable
`U32`/`U64` locals and `U64` scalar storage. Local compound assignment lowers
to Yul `name := op(name, value)`, while scalar storage compound assignment
lowers to `sstore(slot, op(sload(slot), value))`. Shift operators preserve EVM
operand ordering through `shl(shift, value)` and `shr(shift, value)`. The
smoke checks golden Yul reproducibility, `solc --strict-assembly` bytecode
generation, metadata capability `storage.scalar`, Foundry return values, raw
storage slot updates, and unknown-selector revert behavior. Aggregate targets
remain explicit diagnostics.

`ConditionalProbe` validates portable IR statement-level `if/else` lowering to
Yul `switch condition case 0 { else } default { then }` blocks. The smoke checks
golden Yul reproducibility, `solc --strict-assembly` bytecode generation,
Foundry execution of then/else storage updates, and unknown-selector revert
behavior. EVM-specific branch-local early returns are validated by
`EvmLoopProbe`.

`EvmLoopProbe` validates portable IR `boundedFor` lowering to Yul `for` loops:
the loop prelude declares the index, the condition compares it with the static
exclusive stop bound, and the post block increments it by one. It also validates
branch-local and loop-local early returns by lowering nested `return` statements
to return-value assignments followed by Yul `leave`. The smoke checks golden Yul
reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`storage.scalar`, `control.conditional`, `control.bounded_loop`),
Foundry runtime storage updates, early-return storage effects, and
unknown-selector revert behavior. Invalid loop ranges remain explicit
diagnostics.

`ContextProbe` validates portable IR context reads through EVM opcodes:
`userId` lowers to `caller()`, `contractId` lowers to `address()`, and
`checkpointId` lowers to `number()`. It also validates `nativeValue` lowering
to `callvalue()` through the `native_value()` selector. The smoke checks golden
Yul reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`caller.sender`, `account.explicit`, `env.block`,
`value.native`), Foundry runtime context values through `vm.prank`/`vm.roll`,
value-bearing calls through `probe.call{value: ...}`, and unknown-selector
revert behavior.

`EvmHashProbe` validates portable IR `Hash` values as a one-word EVM ABI and
storage representation. Four-limb `hash4` literals and dynamic `hashValue`
expressions pack into a single 256-bit word, while `hash` and
`hash_two_to_one` lower to Yul helpers that call `keccak256` over one or two
32-byte memory words. The smoke checks golden Yul reproducibility,
`solc --strict-assembly` bytecode generation, metadata capabilities
(`crypto.hash`, `storage.scalar`), ABI `bytes32` parameters/returns, scalar
Hash storage through `sload`/`sstore`, Foundry `vm.load` raw slots, and
unknown-selector revert behavior.

`EventProbe` validates portable IR event emission through Yul logs. EVM IR v0
derives topic0 from a Solidity-style event signature generated from the event
name and field types, for example `ValueEvent(uint64)`,
`PairEvent((uint64,uint64))`, `ArrayEvent(uint64[2])`, or
`PairArrayEvent((uint64,uint64)[2])`. Plain `eventEmit` lowers to `log1`, while
`eventEmitIndexed` snapshots up to three scalar indexed fields into topics and
writes the remaining non-indexed fields as ABI-style 32-byte data words.
Non-indexed data fields can be scalar words, flat structs, scalar fixed arrays,
or fixed arrays of flat structs, and aggregate values flatten in ABI order
before the Yul log call. The smoke checks golden Yul reproducibility, `solc
--strict-assembly` bytecode generation, metadata capability `events.emit`,
Foundry recorded logs (`emitter`, signature topic, indexed topic, flat struct
data, scalar fixed-array data, fixed-array-of-struct data, and decoded scalar
data), ABI selector dispatch, and unknown-selector revert behavior. Aggregate
indexed fields and richer event declarations remain explicit unsupported
surfaces for the portable IR.

`EvmCrosscallProbe` validates portable IR `crosscallInvoke`,
`crosscallInvokeTyped`, and `crosscallInvokeValueTyped` lowering to arity-,
return-type-, and value-mode-specific Yul helpers. EVM IR v0 interprets the
target expression as an address word, the method expression as a low-32-bit
selector, scalar arguments as 32-byte ABI words, and value-bearing call value as
a U64 word. The helper packs calldata, executes either
`call(gas(), target, 0, ...)` or `call(gas(), target, call_value, ...)`,
reverts on call failure or returns shorter than one word, and decodes a single
32-byte return word. Typed helpers cover `Bool`, `U32`, `U64`, and `Hash`; Bool
and U32 helpers reject out-of-range return words before returning to the
dispatcher. The smoke checks golden Yul reproducibility,
`solc --strict-assembly` bytecode generation, metadata capability
`crosscall.invoke`, metadata entrypoints, Foundry U64 calls with zero/one/two
arguments, typed Bool/U32/Hash calls, native-value forwarding to a payable
callee, callee reverts, short-return reverts, invalid typed return reverts, and
unknown-selector reverts.

`EvmExpressionProbe` validates scalar expression lowering directly rather than
through storage or assignment side effects. It covers `U64` and `U32`
arithmetic (`add`, `sub`, `mul`, `div`, `mod`), `U64` exponentiation through
Yul `exp`, `U64`/`U32` bitwise operators and shifts with EVM operand ordering,
predicate expressions (`eq`, `ne`, `lt`, `le`, `gt`, `ge`), boolean
`and`/`or`/`not`, scalar literals, immutable local reads, supported
`U32`/`U64`/`Bool` casts, one-word scalar returns, dispatcher guards for
`U32`/`Bool` calldata, and assertion guards. The smoke checks golden Yul
reproducibility, `solc --strict-assembly` bytecode generation, metadata
capability `assertions.check`, Foundry runtime results, malformed calldata
reverts, and unknown-selector reverts.

`EvmMapProbe` validates portable IR `Map<U64, U64, N>` storage through the same
Solidity-style value slot layout used by the SDK: `keccak256(key || slot)` after
writing `key` and `slot` as two 32-byte memory words. `storage.map.contains`
uses a ProofForge-managed presence mapping rooted at
`keccak256(slot || PROOF_FORGE_MAP_PRESENCE)` so inserted or set keys remain
present even when their stored value is zero. The smoke checks golden Yul
reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`storage.scalar`, `storage.map`, `assertions.check`), ABI
get/set/insert/contains behavior, single-segment `mapKey` storage path reads,
writes, and compound assignment, raw Foundry `vm.load` value and presence
storage slots, and unknown-selector revert behavior. EVM IR v0 still keeps map
paths scoped to a single `mapKey`; nested map/aggregate storage paths remain
explicit diagnostics.

`EvmTypedMapProbe` extends the same mapping slot layout to word key/value maps.
It validates `U32`, `Bool`, and `Hash` map keys and values using the same
`keccak256(key || slot)` helper, with one declared mapping slot per state and a
domain-separated presence mapping for `contains`. The smoke checks golden Yul
reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`storage.scalar`, `storage.map`, `assertions.check`), ABI
dispatcher guards for `U32` and `Bool` map parameters, statement and expression
map writes, previous-value returns, `Hash`/`bytes32` map values,
single-segment `mapKey` path reads/writes, numeric `U32` map-path compound
assignment, typed `contains`, raw Foundry `vm.load` value and presence storage
slots, and unknown-selector revert behavior. Nested map paths and aggregate or
non-word key/value shapes remain explicit diagnostics.

`EvmStorageArrayProbe` validates portable IR `U64` fixed storage arrays through
contiguous EVM storage slots. Array state occupies `length` slots, so state
declared after an array starts after the full array span. Direct
`storageArrayRead`/`storageArrayWrite` effects and single-segment `index`
storage paths lower through `__proof_forge_array_slot(base, length, index)`,
which reverts when the index is out of bounds before calling `sload` or
`sstore`. The smoke checks golden Yul reproducibility, `solc --strict-assembly`
bytecode generation, metadata capabilities (`storage.scalar`, `storage.array`,
`data.fixed_array`), ABI read/write selectors, generic path read/write and
compound assignment, Foundry raw slot layout, out-of-bounds reverts, and
unknown-selector revert behavior.

`EvmTypedStorageProbe` extends the storage-array gate beyond the original `U64`
case. It validates `Bool` scalar storage and `U32`/`Bool`/`Hash` fixed storage
arrays using the same contiguous word-slot layout and
`__proof_forge_array_slot(base, length, index)` helper. The smoke checks golden
Yul reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`storage.scalar`, `storage.array`, `data.fixed_array`,
`assertions.check`), raw Foundry slot layout for word arrays, ABI `Bool` and
`Hash` returns, `U32` calldata range guards on writes, storage-path reads/writes
over typed arrays, numeric `U32` storage-path compound assignment,
out-of-bounds reverts, and unknown-selector revert behavior.

`EvmStorageStructProbe` validates portable IR flat storage structs. Scalar
storage structs reserve one EVM storage slot per supported field in declaration
order, and fixed storage arrays of structs reserve `length * field_count` slots.
Direct `storageStructFieldRead`/`storageStructFieldWrite`,
`storageArrayStructFieldRead`/`storageArrayStructFieldWrite`, scalar `field`
storage paths, `index`+`field` storage paths, and whole scalar storage struct
reads/writes lower to deterministic `sload`/`sstore` expressions. Whole writes
snapshot RHS fields before writing target slots, so self-referential storage
struct updates observe the original RHS values. Struct arrays use
`__proof_forge_struct_array_slot(base, length, field_count, field_offset,
index)`, which reverts on out-of-bounds indexes before deriving
`base + index * field_count + field_offset`. The smoke checks golden Yul
reproducibility, `solc --strict-assembly` bytecode generation, metadata
capabilities (`storage.scalar`, `storage.array`, `data.fixed_array`,
`data.struct`), scalar and array struct field reads/writes, field path
compound assignment, whole scalar storage struct read/write, ABI struct return
encoding from storage, `Bool`/`U32`/`Hash` fields, Foundry raw slot layout,
out-of-bounds reverts, and unknown-selector revert behavior. Nested struct
fields and non-flat struct storage remain explicit diagnostics.

`EvmArrayValueProbe` validates portable IR local fixed-array values. Immutable
and mutable local fixed-array bindings expand into one Yul local per element.
`arrayGet` over local arrays or array literals supports static `U32`/`U64`
literal indexes and dynamic word indexes. Dynamic reads lower through
length-specific Yul helpers with default revert cases; dynamic mutable local
element assignment and numeric compound assignment lower to `switch` blocks over
the expanded locals. Whole local fixed-array assignment from another local
fixed-array or from a fixed-array literal snapshots RHS words into temporary
locals before assigning elements back to the target. The smoke covers `U64`,
`U32`, `Bool`, and `Hash` element arrays, static and dynamic mutable element
writes, whole-local assignment, golden Yul reproducibility,
`solc --strict-assembly`, artifact metadata, Foundry runtime calls, dynamic
out-of-bounds reverts, and unknown-selector revert behavior. Nested arrays
remain explicit diagnostics.

`EvmStructArrayValueProbe` validates portable IR local fixed arrays of flat
struct values. Immutable and mutable local bindings expand into one Yul local
per element field, for example `people[1].score` becomes a deterministic
internal local. `field(arrayGet(localArray, index), name)` supports static
literal indexes and dynamic word indexes; dynamic reads use the same
length-specific local-array getter helpers as scalar arrays, and dynamic
mutable field assignment/compound assignment lowers to `switch` blocks with
default revert cases. The smoke covers `U64`, `U32`, `Bool`, and `Hash` fields,
static and dynamic field reads, static and dynamic mutable field writes, numeric
field compound assignment, golden Yul reproducibility, `solc
--strict-assembly`, artifact metadata capabilities (`data.fixed_array`,
`data.struct`, `assertions.check`), Foundry runtime calls, dynamic
out-of-bounds reverts, and unknown-selector revert behavior. Whole local
assignment from another local struct array and from self-referential struct
array literals snapshots RHS fields before writing target fields. Nested
array/struct elements remain explicit diagnostics.

`EvmStructValueProbe` validates portable IR flat local struct values. Immutable
and mutable struct local bindings expand into one internal Yul local per
supported field, and `field` access over a local struct or direct struct literal
lowers to the corresponding scalar/hash word expression. Static local field
assignment and numeric compound assignment lower to assignments to those
expanded locals. Whole local struct assignment from another local struct or from
a struct literal snapshots RHS field words into temporary locals before assigning
fields back to the target. The smoke covers `U64`, `U32`, `Bool`, and `Hash`
fields, mutable field writes, whole-local assignment, golden Yul
reproducibility, `solc --strict-assembly`, artifact metadata capability
`data.struct`, Foundry runtime calls, and unknown-selector revert behavior.
Nested struct fields remain explicit diagnostics.

## Metadata

EVM bytecode modes emit a ProofForge artifact metadata JSON file and a
ProofForge EVM deploy manifest. The default metadata path is
`proof-forge-artifact.json` next to the bytecode output; smoke scripts pass
fixture-specific `--artifact-output` paths to avoid parallel-run collisions.
The deploy manifest path is derived from the metadata path, for example
`Counter.proof-forge-deploy.json`.

The current EVM metadata schema records:

- `schemaVersion: 1`
- `target: evm`, `targetFamily: evm`, and `artifactKind: evm-bytecode`
- source kind (`lean-sdk` or `portable-ir`), source module, and `irVersion`
  (`portable-ir-v0` for portable IR fixtures)
- portable IR capability ids when available
- selector-facing ABI entrypoints or SDK method specs
- `solc` path/version
- Yul, bytecode, source when available, and deploy-manifest artifact paths,
  byte sizes, and SHA-256 hashes
- validation flags for `solc --strict-assembly`, bytecode generation, and
  deploy-manifest generation

The EVM deploy manifest records:

- `kind: proof-forge-evm-deploy-manifest`
- source kind/module, `irVersion`, capabilities, and ABI entrypoints/methods
- Yul/source inputs and runtime bytecode hash/size
- `creation.mode: runtime-bytecode`, with empty constructor args and no init
  code yet
- `deployment.broadcast: not-generated`, because current Foundry smokes install
  runtime bytecode with `vm.etch` instead of broadcasting a chain transaction

`scripts/evm/validate-artifact-metadata.py` validates these metadata files and
their referenced deploy manifests in the EVM IR smoke scripts and in
`scripts/evm/build-examples.sh`. `scripts/evm/validate-deploy-manifest.py`
can validate a deploy manifest directly.

Method dispatch still uses `.evm-methods` sidecar files until a unified target
manifest lands (RFC 0002).
