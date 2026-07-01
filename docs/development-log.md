# Development Log

This log records engineering milestones for ProofForge. It is not a replacement
for Git history. Use it to understand what changed, what was validated, and what
the next engineering step is.

## Format

Each entry should include:

- date
- commit or work range
- summary
- validation run
- known limitations
- next step

## 2026-07-01

### EVM IR Nested Struct Crosscall Fixed Arrays

Commit: feature commit for EVM IR nested struct crosscall arrays

Summary:

- Extended typed crosscall aggregate word-shape validation so nested fixed
  arrays can use flat struct leaves such as `RemotePair[2][2]`, while non-flat
  struct leaves still fail with explicit diagnostics.
- Added `EvmCrosscallProbe` entrypoints for `RemotePair[2][2]` arguments and
  direct entrypoint returns across normal, value-bearing, static, and delegate
  typed calls.
- Refreshed `EvmCrosscallProbe.golden.yul`, metadata selector expectations, and
  the Foundry smoke harness with `Pair[2][2]` callee helpers.
- Updated the EVM coverage manifest and target/validation docs to distinguish
  supported flat struct leaves from unsupported non-flat struct leaves.

Validation run:

```sh
lake build
scripts/i18n/check-sync.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/crosscall-ir-smoke.sh
git diff --check
```

Result:

- `EvmCrosscallProbe` generated reproducible Yul and runtime bytecode through
  `solc --strict-assembly`.
- Foundry ran 73 CrosscallProbe tests, including nested fixed-array
  flat-struct arguments and returns in normal, value-bearing, static, and
  delegate modes.

Known limitations:

- Dynamic ABI values, nested local fixed-array mutation beyond the current
  local-array surface, nested crosscall fixed arrays with non-flat or
  unsupported leaves, and variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking the EVM aggregate gap around dynamic ABI data, richer
  cross-call return data, or unsupported nested aggregate leaves.

### EVM IR Storage-Backed Aggregate ABI Returns

Commit: feature commit for EVM IR storage-backed aggregate ABI returns

Summary:

- Extended `EvmStorageArrayProbe` with `return_values()`, which writes U64
  storage-array elements, reads them back through `storageArrayRead`, and
  encodes those reads as a fixed-array ABI return.
- Extended `EvmStorageStructProbe` with `return_points()`, which writes fields
  in a fixed storage array of flat structs, reads them back through
  `storageArrayStructFieldRead`, and encodes those reads as a
  fixed-array-of-struct ABI return.
- Refreshed both storage probe golden Yul snapshots and metadata selector
  expectations.
- Added Foundry ABI decoding checks for `uint256[3]` and `Point[2]` returns,
  while still validating the raw storage slots with `vm.load`.

Validation run:

```sh
lake build
scripts/i18n/check-sync.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/storage-struct-ir-smoke.sh
git diff --check
```

Result:

- `EvmStorageArrayProbe` generated reproducible Yul and runtime bytecode, and
  Foundry ran 7 tests including the new storage-backed fixed-array return.
- `EvmStorageStructProbe` generated reproducible Yul and runtime bytecode, and
  Foundry ran 12 tests including the new storage-backed fixed-array-of-struct
  return.

Known limitations:

- This covers fixed-size word arrays and fixed arrays of flat structs assembled
  from storage reads. Dynamic ABI values, richer storage-backed aggregate
  shapes, and variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking the EVM ABI/storage gap around dynamic ABI data, richer
  aggregate storage shapes, or return data that cannot be represented as a
  static word sequence.

### EVM IR Nested Crosscall Fixed Arrays

Commit: `fb0828b` (`feat: support nested EVM crosscall arrays`)

Summary:

- Extended typed crosscall aggregate lowering so nested scalar fixed arrays such
  as `Array<Array<U64,2>,2>` flatten to ABI words for normal, value-bearing,
  static, and delegate typed calls.
- Added `EvmCrosscallProbe` entrypoints for nested scalar fixed-array arguments
  and direct entrypoint returns across all four call modes.
- Kept nested fixed arrays with struct or other non-scalar leaves as explicit
  unsupported diagnostics.
- Refreshed `EvmCrosscallProbe.golden.yul`, metadata selector expectations, and
  the Foundry smoke harness with `uint64[2][2]` callee helpers.

Validation run:

```sh
lake build
lake env lean --run Tests/TargetRegistry.lean
scripts/i18n/check-sync.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/crosscall-ir-smoke.sh
git diff --check
```

Result:

- `EvmCrosscallProbe` generated reproducible Yul and runtime bytecode through
  `solc --strict-assembly`.
- Foundry ran 65 CrosscallProbe tests, including nested scalar fixed-array
  arguments and returns in normal, value-bearing, static, and delegate modes.
- GitHub Actions run `28514575022` passed on `main`.

Known limitations:

- Dynamic ABI values, nested local fixed-array mutation beyond the current
  local-array surface, nested crosscall fixed arrays with non-flat or
  unsupported leaves, and variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking the EVM aggregate gap around dynamic ABI data, storage
  backed aggregate ABI surfaces, or richer cross-call return data.

### EVM IR Nested Fixed-Array ABI

Commit: feature commit for EVM IR nested fixed-array ABI

Summary:

- Extended EVM ABI word flattening for entrypoint parameters and returns from
  flat fixed arrays to nested scalar fixed arrays such as
  `Array<Array<U64,2>,2>`.
- Added deterministic flattened Yul local names for nested ABI array words and
  static nested index reads such as `matrix[0][1]`.
- Extended `EvmAbiAggregateProbe` with `sum_matrix`, `make_matrix`, and
  `sum_small_matrix` entrypoints covering nested `U64`/`U32` ABI calldata,
  return-data encoding, and range guards.
- Kept typed crosscall nested aggregate arrays explicitly unsupported with
  crosscall-specific diagnostics instead of silently inheriting ABI entrypoint
  support.

Validation run:

```sh
lake build
scripts/evm/diagnostic-smoke.sh
scripts/evm/abi-aggregate-ir-smoke.sh
```

Result:

- `EvmAbiAggregateProbe` generated reproducible Yul and runtime bytecode
  through `solc --strict-assembly`.
- Foundry validated nested fixed-array parameters, nested fixed-array returns,
  malformed nested calldata length checks, and nested `U32` range guards.
- EVM diagnostics now keep zero-length arrays, non-flat struct fields, nested
  crosscall aggregate arrays, and malformed crosscall surfaces explicit.

Known limitations:

- Nested fixed-array support is currently ABI-entrypoint focused.
- Dynamic ABI values, nested local fixed-array mutation, nested crosscall
  aggregate arrays, and variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking the EVM aggregate gap around nested crosscall aggregates
  or dynamic ABI data.

### EVM IR Contract Creation

Commit: feature commit for EVM IR contract creation

Summary:

- Added portable IR `crosscallCreate` and `crosscallCreate2` expressions for
  EVM contract creation from fixed init-code hex.
- Lowered creation expressions to deterministic Yul helpers that write init
  code into memory, call `create(value, offset, length)` or
  `create2(value, offset, length, salt)`, revert on zero-address failure, and
  return the deployed address word.
- Extended `EvmCrosscallProbe` with `deploy_create` and `deploy_create2`
  entrypoints using tiny init code that deploys a runtime returning U256 `42`.
- Kept non-EVM target behavior explicit by adding Psy unsupported diagnostics
  for both creation expressions.

Validation run:

```sh
lake build ProofForge.IR.Examples.EvmCrosscallProbe
scripts/evm/diagnostic-smoke.sh
scripts/psy/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/psy/check-ir-coverage-manifest.py
scripts/evm/crosscall-ir-smoke.sh
```

Result:

- `EvmCrosscallProbe` generated reproducible Yul and runtime bytecode through
  `solc --strict-assembly`.
- Foundry ran 57 CrosscallProbe tests, including `create` deployment,
  deterministic `create2` address validation, and calls into the deployed
  runtime.
- EVM diagnostics now cover bad creation value type, malformed init-code hex,
  and bad `create2` salt type; Psy diagnostics cover unsupported creation
  nodes.

Known limitations:

- Creation init code is currently embedded as fixed hex in the IR expression.
- Dynamic constructor arguments, artifact-linked init code, creation manifests,
  live transaction broadcasting, and variable-length cross-call return data
  remain future EVM IR work.

Next step:

- Continue closing EVM call-surface gaps around artifact-linked creation or
  variable-length ABI data.

### EVM IR Struct-Array Crosscall Aggregates

Commit: feature commit for EVM IR struct-array crosscall aggregates

Summary:

- Extended the existing typed crosscall aggregate path to fixed arrays of flat
  structs.
- Added `EvmCrosscallProbe` entrypoints for fixed-array-of-flat-struct typed
  arguments and direct aggregate returns across normal, value-bearing, static,
  and delegate call modes.
- Reused the ABI-static flattening policy: `RemotePair[2]` lowers to four ABI
  words, preserving Bool and U32 return guards for every decoded element field.
- Refreshed golden Yul, artifact metadata entrypoint expectations, Foundry
  callee fixtures, and coverage/target validation docs.

Validation run:

```sh
lake build ProofForge.IR.Examples.EvmCrosscallProbe
scripts/evm/crosscall-ir-smoke.sh
```

Result:

- `EvmCrosscallProbe` generated reproducible Yul and runtime bytecode through
  `solc --strict-assembly`.
- Foundry ran 55 CrosscallProbe tests, including fixed-array-of-flat-struct
  arguments and returns in normal/value/static/delegate modes.
- Metadata validation now checks all new struct-array crosscall selectors.

Known limitations:

- Aggregate crosscall arguments and returns remain limited to ABI-static flat
  shapes.
- Nested dynamic arrays, variable-length return data, and artifact-linked
  creation remain future EVM IR work.

Next step:

- Continue closing the remaining EVM call-surface gaps around artifact-linked
  creation or variable-length ABI data.

### EVM IR Aggregate Crosscall Arguments

Commit: feature commit for EVM IR aggregate crosscall arguments

Summary:

- Extended typed crosscall argument lowering beyond scalar words for normal,
  value-bearing, static, and delegate typed calls.
- Reused the EVM ABI flattening rules for flat struct and scalar fixed-array
  arguments, so helper arity now reflects the ABI word count rather than the
  surface IR argument count.
- Made crosscall helper discovery type-env aware, allowing let-bound local
  structs and fixed arrays to request the correct generated helper.
- Extended `EvmCrosscallProbe` with normal struct and fixed-array arguments,
  value-bearing struct arguments, static struct arguments, and delegate struct
  arguments.
- Kept nested aggregate crosscall argument shapes as explicit unsupported
  diagnostics.

Validation run:

```sh
lake build
scripts/evm/diagnostic-smoke.sh
scripts/evm/crosscall-ir-smoke.sh
```

Result:

- `EvmCrosscallProbe` generated reproducible Yul and runtime bytecode through
  `solc --strict-assembly`.
- Foundry ran 35 CrosscallProbe tests, including aggregate argument calldata
  packing for normal/value/static/delegate typed calls.
- EVM diagnostics ran 55 cases, including nested aggregate argument rejection.

Known limitations:

- Aggregate crosscall arguments are limited to ABI-static flat structs and
  scalar fixed arrays.
- Value-bearing, static, and delegate typed crosscalls still return scalar
  words only.
- Contract creation and variable-length return data remain future work.

Next step:

- Continue closing EVM call-surface gaps around aggregate returns for
  value/static/delegate calls or contract creation manifests.

### EVM IR Aggregate Crosscall Returns

Commit: feature commit for EVM IR aggregate crosscall returns

Summary:

- Extended normal `crosscallInvokeTyped` returns beyond scalar words when the
  expression is returned directly from an ABI-facing entrypoint.
- Lowered flat struct and scalar fixed-array crosscall return data through
  arity- and ABI-word-shape-specific Yul helpers such as
  `__proof_forge_crosscall_0_abi_bool_u32`, assigning multiple helper results
  directly to the entrypoint's ABI return words.
- Preserved scalar behavior for value-bearing, static, and delegate typed
  crosscalls, and kept unsupported nested aggregate return shapes as explicit
  diagnostics.
- Extended `EvmCrosscallProbe` with `call_remote_pair` and
  `call_remote_array`, refreshed golden Yul, metadata selector checks, Foundry
  aggregate struct/array return tests, malformed Bool/U32 aggregate return
  guard tests, coverage manifests, validation gates, target docs, backlog, and
  Chinese docs.

Validation run:

```sh
lake build
scripts/i18n/check-sync.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/foundry-smoke.sh
```

Known limitations:

- Aggregate crosscall support is limited to normal typed calls returned
  directly from entrypoints.
- Aggregate crosscall arguments, value/static/delegate aggregate returns,
  nested aggregate return data, contract creation, and variable-length return
  data remain future EVM IR work.

Next step:

- Continue shrinking EVM cross-call gaps around aggregate arguments,
  value/static/delegate aggregate returns, or create/create2.

### EVM IR Typed Delegatecalls

Commit: feature commit for EVM IR typed delegatecalls

Summary:

- Added portable IR `crosscallInvokeDelegateTyped` for EVM delegate calls that
  return one scalar word.
- Lowered delegate calls to arity- and return-type-specific Yul helpers using
  `delegatecall(gas(), target, ...)`, sharing selector packing, scalar-word
  argument encoding, short-return checks, and Bool/U32 return guards with the
  other crosscall helper modes.
- Kept delegate semantics explicit across backends: Psy IR v0 rejects delegate
  typed crosscalls with a stable unsupported diagnostic.
- Extended `EvmCrosscallProbe` with U64/Bool/U32/Hash delegate entrypoints,
  refreshed golden Yul, Foundry caller-storage read/write checks, typed-return
  guard checks, metadata selector checks, EVM/Psy diagnostics, coverage
  manifests, target docs, validation gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
scripts/i18n/check-sync.sh
```

Known limitations:

- Delegate crosscalls are currently limited to scalar word arguments and one
  scalar word return (`U32`, `U64`, `Bool`, or `Hash`).
- Contract creation, aggregate crosscall arguments/returns, and
  variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking EVM cross-call gaps around create/create2 or aggregate
  calldata/return-data.

### EVM IR Typed Staticcalls

Commit: feature commit for EVM IR typed staticcalls

Summary:

- Added portable IR `crosscallInvokeStaticTyped` for read-only EVM
  cross-contract calls that return one scalar word.
- Lowered typed static calls to arity- and return-type-specific Yul helpers
  using `staticcall(gas(), target, ...)`, sharing selector packing, scalar-word
  argument encoding, short-return checks, and Bool/U32 return guards with the
  existing call helpers.
- Kept target semantics explicit across backends: Psy IR v0 rejects static
  typed crosscalls with a stable unsupported diagnostic rather than silently
  lowering them to the existing Felt-returning `__invoke_sync` form.
- Extended `EvmCrosscallProbe` with `call_remote_static` plus Bool/U32/Hash
  static typed variants, refreshed golden Yul, Foundry read-only return,
  typed-return guard, and static-context state-write failure checks, metadata
  selector checks, EVM/Psy diagnostics, coverage manifests, target docs,
  validation gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
scripts/i18n/check-sync.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/crosscall-ir-smoke.sh
```

Known limitations:

- Static crosscalls are currently limited to scalar word arguments and one
  scalar word return (`U32`, `U64`, `Bool`, or `Hash`).
- `delegatecall`, contract creation, aggregate crosscall arguments/returns, and
  variable-length return data remain future EVM IR work.

Next step:

- Continue shrinking EVM cross-call gaps around `delegatecall`, create/create2,
  aggregate calldata/return-data, or richer artifact metadata for deployment.

### EVM IR Aggregate Event Data

Commit: feature commit for EVM IR aggregate event data

Summary:

- Extended EVM `eventEmit` / `eventEmitIndexed` lowering so non-indexed event
  data fields can be scalar words, flat structs, scalar fixed arrays, or fixed
  arrays of flat structs.
- Added canonical Solidity-style event signature generation for flat aggregate
  event fields, including `PairEvent((uint64,uint64))`,
  `ArrayEvent(uint64[2])`, and `PairArrayEvent((uint64,uint64)[2])`.
- Flattened aggregate event data into ABI-style 32-byte words before `log1`
  through `log4`, preserving scalar indexed topics for `eventEmitIndexed`.
- Kept aggregate indexed fields explicit: they now fail with a diagnostic
  rather than pretending EVM's indexed aggregate topic-hash semantics are
  direct scalar topics.
- Extended `EventProbe` with `emit_pair_event`, `emit_array_event`, and
  `emit_pair_array_event`, refreshed golden Yul, Foundry recorded-log checks,
  metadata selector checks, EVM diagnostics, coverage, target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build proof-forge
scripts/evm/event-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Indexed event fields remain scalar-only (`U32`, `U64`, `Bool`, or `Hash`) and
  limited to three indexed fields after the signature topic.
- Richer first-class event declarations are still not represented in the
  portable IR.

Next step:

- Continue shrinking EVM gaps around richer cross-call return data,
  `staticcall`/`delegatecall`/creation call kinds, nested aggregate lowering,
  or real creation/broadcast manifests.

### EVM IR Indexed Event Topics

Commit: feature commit for EVM IR indexed events

Summary:

- Added portable IR `eventEmitIndexed` for EVM-style events with scalar indexed
  fields and non-indexed data fields.
- Lowered indexed events to Yul `log2`/`log3`/`log4`: topic0 is the
  Solidity-style event signature hash, indexed fields become topics, and
  non-indexed fields remain ABI-style 32-byte data words.
- Kept indexed events explicit on non-EVM targets: Psy IR v0 rejects the new
  node with a diagnostic instead of silently dropping topic semantics.
- Extended `EventProbe` with `emit_indexed_event`, refreshed golden Yul,
  Foundry recorded-log checks, metadata selector checks, EVM/Psy diagnostics,
  coverage manifests, target docs, validation gates, backlog, capability
  registry entries, and Chinese docs.

Validation run:

```sh
lake build
scripts/evm/event-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
scripts/i18n/check-sync.sh
```

Known limitations:

- Indexed event fields are limited to scalar EVM word values (`U32`, `U64`,
  `Bool`, or `Hash`) and at most three indexed fields after the signature
  topic.
- Aggregate event payloads and richer event declarations remain future work.

Next step:

- Continue shrinking EVM gaps around aggregate event payloads, richer
  cross-call return data, contract-creation call kinds, or nested aggregate
  lowering.

### EVM IR Solidity-Style Event Signatures

Commit: feature commit for EVM IR event signature topics

Summary:

- Changed portable IR `eventEmit` topic0 derivation from the raw event-name
  hash to `keccak256(Solidity-style event signature)`.
- Added EVM ABI type names for supported event scalar fields:
  `U32 -> uint32`, `U64 -> uint64`, `Bool -> bool`, and `Hash -> bytes32`.
- Reworked the Yul event topic preimage writer to pack arbitrary-length UTF-8
  signature strings into memory before hashing, removing the old 32-byte event
  name packing limit.
- Updated `EventProbe` golden Yul, Foundry recorded-log assertion, coverage
  manifest, EVM target docs, validation gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
scripts/evm/event-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/i18n/check-sync.sh
```

Known limitations:

- Portable IR event payload fields remain limited to scalar word values:
  `U32`, `U64`, `Bool`, or `Hash`.
- Richer event declarations are still not represented in the portable IR.

Next step:

- Continue shrinking event gaps around aggregate event payloads or richer event
  declarations, or move to another EVM surface such as richer cross-call return
  data or nested aggregate lowering.

### EVM IR Whole Storage Struct Read/Write

Commit: feature commit for EVM IR whole storage struct read/write

Summary:

- Allowed `storageScalarRead` and `storageScalarWrite` to operate on flat
  scalar storage structs by expanding the struct into declaration-ordered EVM
  field slots.
- Added aggregate-only lowering for struct storage reads: struct local
  bindings, struct field access, whole local struct assignment, and struct
  returns can consume `storageScalarRead` without treating the struct as a
  single EVM word.
- Lowered whole scalar storage struct writes from local structs, struct
  literals, and storage struct reads with RHS field snapshotting before writing
  target slots.
- Extended `EvmStorageStructProbe` with whole write/read-into-local, direct
  ABI struct return from storage, and self-referential storage write snapshot
  coverage.
- Refreshed golden Yul, artifact metadata entrypoint checks, Foundry smoke
  tests, diagnostics, coverage manifest, target docs, validation gates, backlog,
  and Chinese docs.

Validation run:

```sh
lake build
scripts/evm/storage-struct-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Whole storage struct operations are limited to flat scalar storage structs
  whose fields lower to EVM words (`U32`, `U64`, `Bool`, or `Hash`).
- Nested struct fields, non-flat struct storage, nested arrays, and dynamic or
  nested aggregate ABI values remain explicit diagnostics or documented gaps.

Next step:

- Continue shrinking the EVM aggregate unsupported surface around nested local
  aggregate shapes, broader storage-backed aggregate ABI values, richer
  cross-call return data, or event schema fidelity.

### EVM IR Struct Array Whole Local Assignment

Commit: feature commit for EVM IR struct-array whole local assignment

Summary:

- Allowed `assign (.local name) value` for mutable local fixed arrays whose
  element type is a flat struct.
- Lowered whole local struct-array assignment from another local struct array
  or a struct-array literal by snapshotting every RHS element field into
  temporary Yul locals before writing the expanded target fields.
- Extended `EvmStructArrayValueProbe` with `whole_struct_array_assign()` and
  `self_struct_array_assign()` to validate local-source assignment and
  self-referential literal RHS snapshot semantics.
- Refreshed the golden Yul, artifact metadata entrypoint checks, Foundry smoke
  harness, EVM coverage manifest, target docs, validation gates, backlog, and
  Chinese docs.

Validation run:

```sh
lake build
scripts/evm/struct-array-value-ir-smoke.sh
```

Known limitations:

- Struct-array whole assignment is limited to fixed arrays whose element type is
  a flat struct over EVM word fields (`U32`, `U64`, `Bool`, or `Hash`).
- Nested arrays, nested local structs, whole-struct storage reads/writes, and
  dynamic or nested aggregate ABI values remain explicit diagnostics.

Next step:

- Continue shrinking the remaining EVM aggregate unsupported surface, likely
  around nested aggregate locals, richer cross-call return data, or event schema
  fidelity.

### EVM IR Storage Map Contains

Commit: feature commit for EVM IR storage map contains

Summary:

- Lowered `storage.map.contains` for EVM portable IR through
  ProofForge-managed presence slots instead of treating nonzero map values as
  presence.
- Added `__proof_forge_map_presence_slot(slot, key)`, rooted at
  `keccak256(slot || PROOF_FORGE_MAP_PRESENCE)`, while preserving the existing
  Solidity-style value slot `keccak256(key || slot)`.
- Updated map insert/set, map statement writes, and map storage-path compound
  assignment helpers to mark key presence whenever ProofForge writes a map key.
- Extended `EvmMapProbe` with U64 contains coverage, including a zero-valued
  present key, and extended `EvmTypedMapProbe` with U32/Bool/Hash contains
  entrypoints.
- Updated diagnostics so statement-position `storage.map.contains` fails with
  an expression-only diagnostic instead of an unsupported-capability error.

Validation run:

```sh
lake build ProofForge.Backend.Evm.IR proof-forge
scripts/evm/map-ir-smoke.sh
scripts/evm/typed-map-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Presence tracks keys written through ProofForge-generated map helpers; raw
  external storage mutation outside those helpers can still bypass the
  presence mapping.
- Nested map paths and aggregate/non-word map key/value shapes remain explicit
  diagnostics.

Next step:

- Continue shrinking the remaining EVM aggregate unsupported surface, likely
  around nested aggregate locals, richer event schemas, or broader cross-call
  return data.

### EVM IR Whole Local Aggregate Assignment

Commit: feature commit for EVM IR whole local aggregate assignment

Summary:

- Allowed `assign (.local name) value` for mutable local fixed-array and flat
  local struct values.
- Lowered whole local fixed-array assignment from another local fixed-array or a
  fixed-array literal by snapshotting RHS element words into temporary Yul
  locals before assigning expanded target elements.
- Lowered whole local struct assignment from another local struct or a struct
  literal by snapshotting RHS field words into temporary Yul locals before
  assigning expanded target fields.
- Extended `EvmArrayValueProbe` with `whole_array_assign()` and
  `EvmStructValueProbe` with `whole_struct_assign()` to validate local-source
  assignment and self-referential literal RHS snapshot semantics.
- Updated EVM diagnostics, coverage manifests, target docs, validation gates,
  backlog, and Chinese docs to remove the stale whole-local-aggregate
  assignment limitation.

Validation run:

```sh
lake build ProofForge.Backend.Evm.IR proof-forge
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Whole local aggregate assignment is limited to flat fixed-array and flat
  struct locals whose elements/fields lower to EVM words.
- Nested arrays, nested local structs, and whole-struct storage reads/writes
  remain explicit diagnostics.
- Dynamic or nested aggregate ABI values remain out of scope for the current
  flat ABI lowering.

Next step:

- Continue shrinking the EVM aggregate unsupported surface around nested
  aggregate locals, richer cross-call return data, or event schema fidelity.

### EVM IR Dynamic Local Fixed-Array Indexes

Commit: feature commit for EVM IR dynamic local fixed-array indexing

Summary:

- Threaded the EVM IR lowering environment through expression, effect,
  aggregate binding, return, and statement lowering so local aggregate shape is
  available during code generation.
- Added dynamic `arrayGet` lowering for local fixed-array values and fixed-array
  literals using length-specific Yul getter helpers with default revert cases.
- Added dynamic mutable local fixed-array element assignment and numeric
  compound assignment lowering with Yul `switch` blocks over expanded local
  elements.
- Extended `EvmArrayValueProbe` with `dynamic_pick(uint256)` and
  `dynamic_update(uint256)`, refreshed golden Yul, metadata entrypoint
  validation, and Foundry assertions for in-bounds values and out-of-bounds
  reverts.
- Updated EVM diagnostics, coverage manifests, target docs, validation gates,
  backlog, and Chinese docs to remove the stale dynamic-local-index limitation.

Validation run:

```sh
lake build ProofForge.Backend.Evm.IR proof-forge
scripts/evm/array-value-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Dynamic fixed-array indexing is limited to local fixed-array values and
  fixed-array literals whose elements lower to EVM words.
- Whole local aggregate assignment is handled by the later
  "EVM IR Whole Local Aggregate Assignment" entry.
- Nested arrays, nested local structs, and whole-struct storage reads/writes
  remain explicit diagnostics.
- Dynamic or nested aggregate ABI values remain out of scope for the current
  flat ABI lowering.

Next step:

- Continue shrinking the EVM aggregate unsupported surface, most likely around
  nested aggregate locals or richer cross-call return data.

### EVM Deploy Manifest Metadata

Commit: feature commit for EVM deploy manifest metadata

Summary:

- Extended EVM bytecode modes to emit a ProofForge EVM deploy manifest next to
  each `proof-forge-artifact.json` metadata file.
- The manifest records source kind/module, portable IR version when present,
  capabilities, ABI entrypoints or SDK methods, Yul/source inputs, runtime
  bytecode hash/size, and `creation.mode: runtime-bytecode`.
- EVM artifact metadata now records the deploy manifest artifact and requires
  `validation.deployManifest: passed`.
- Added a standalone `scripts/evm/validate-deploy-manifest.py` validator and
  extended `scripts/evm/validate-artifact-metadata.py` to validate the
  referenced deploy manifest against metadata.
- Updated EVM target docs, validation gates, backlog, and Chinese docs to
  distinguish ProofForge runtime-bytecode manifests from future broadcast or
  creation-transaction manifests.

Validation run:

```sh
lake build ProofForge.Cli proof-forge
python3 -m py_compile scripts/evm/validate-artifact-metadata.py scripts/evm/validate-deploy-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/build-examples.sh
python3 scripts/evm/validate-deploy-manifest.py --root . --expect-fixture AbiScalarProbe --expect-source-kind portable-ir build/ir/AbiScalarProbe.proof-forge-deploy.json
python3 scripts/evm/validate-deploy-manifest.py --root . --expect-fixture Counter.lean --expect-source-kind lean-sdk build/evm/Counter.proof-forge-deploy.json
```

Known limitations:

- The deploy manifest describes runtime bytecode deployment inputs only.
- It does not yet generate constructor initcode, Foundry broadcast JSON, chain
  id, deployed address, or a signed/raw transaction.
- Foundry smokes still install runtime bytecode with `vm.etch`.

Next step:

- Either extend EVM manifests toward creation/broadcast artifacts, or continue
  shrinking the remaining EVM IR unsupported surface around dynamic aggregates
  and richer cross-call returns.

### EVM IR Mutable Local Aggregates

Commit: feature commit for EVM IR mutable local aggregate lowering

Summary:

- Extended EVM IR lowering for local fixed-array and flat struct values from
  immutable-only bindings to mutable aggregate locals.
- Added static local fixed-array element assignment and numeric compound
  assignment over expanded Yul locals.
- Added static local struct field assignment and numeric compound assignment
  over expanded Yul locals.
- Extended `EvmArrayValueProbe` and `EvmStructValueProbe` with mutable
  `U64`/`U32`/`Bool`/`Hash` write paths, metadata entrypoint validation,
  refreshed golden Yul, and Foundry runtime assertions.
- Updated EVM diagnostics so immutable aggregate element/field assignment still
  fails explicitly while mutable aggregate locals now lower successfully.
- Updated EVM coverage, target docs, validation gates, backlog, and Chinese
  docs to remove stale mutable-local aggregate limitations.

Validation run:

```sh
lake build ProofForge.IR.Examples.EvmArrayValueProbe ProofForge.IR.Examples.EvmStructValueProbe proof-forge
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- Dynamic local fixed-array indexing is handled by the later
  "EVM IR Dynamic Local Fixed-Array Indexes" entry.
- Whole local aggregate assignment remains an explicit diagnostic; update
  elements or fields directly for now.
- Nested arrays, nested local structs, and whole-struct storage reads/writes
  remain explicit diagnostics.

Next step:

- Continue shrinking the EVM aggregate unsupported surface around nested
  aggregate locals or richer cross-call return data.

### EVM IR Scalar Expression Probe

Commit: feature commit for EVM IR scalar expression validation

Summary:

- Added `ProofForge.IR.Examples.EvmExpressionProbe` to validate scalar
  expression lowering directly, separate from storage or assignment side
  effects.
- Covered `U64` and `U32` arithmetic (`add`, `sub`, `mul`, `div`, `mod`),
  `U64` exponentiation, `U64`/`U32` bitwise operators and shifts, predicates,
  boolean `and`/`or`/`not`, scalar literals, immutable local reads, supported
  `U32`/`U64`/`Bool` casts, one-word scalar returns, and assertion guards.
- Added CLI emission modes, golden Yul, Foundry smoke coverage, artifact
  metadata validation, and CI.
- Updated EVM coverage, target docs, validation gates, backlog, and Chinese
  docs so the scalar expression family now has runtime validation evidence
  instead of only structural lowering notes.

Validation run:

```sh
lake build ProofForge.IR.Examples.EvmExpressionProbe proof-forge
scripts/evm/expression-ir-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Known limitations:

- EVM arithmetic still follows raw EVM word semantics; checked overflow,
  signed arithmetic, and target-specific numeric policies remain future
  design work.
- Aggregate expression behavior remains covered by the array, struct, and ABI
  probes rather than this scalar expression probe.

Next step:

- Continue converting remaining `lowered` coverage rows into validated probes
  or explicit diagnostics, especially around target-specific artifact/deploy
  surfaces and any residual statement/effect validation gaps.

### EVM IR Typed Storage Maps

Commit: feature commit for EVM IR typed storage maps

Summary:

- Generalized portable EVM storage maps from `Map<U64, U64, N>` to word
  key/value maps over `U32`, `U64`, `Bool`, and `Hash`.
- Reused the existing Solidity-style `keccak256(key, slot)` mapping slot helper
  for all supported word map shapes, preserving one declared storage slot per
  map state.
- Added `ProofForge.IR.Examples.EvmTypedMapProbe`, CLI emission modes, golden
  Yul, Foundry smoke coverage, artifact metadata validation, and CI.
- Covered ABI dispatcher guards for `U32` and `Bool` map parameters,
  expression-position previous-value returns, statement-position writes,
  `Hash`/`bytes32` map values, raw mapping slots, and single-segment `mapKey`
  storage-path read/write/compound assignment.
- Updated EVM diagnostics, coverage, target docs, validation gates, and Chinese
  docs so unsupported map diagnostics now target non-word map shapes while
  `storage.map.contains` remains explicitly unsupported.

Validation run:

```sh
lake build ProofForge.Backend.Evm.IR ProofForge.IR.Examples.EvmTypedMapProbe proof-forge
scripts/evm/typed-map-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Known limitations:

- EVM storage maps still support only single-word key/value shapes. Aggregate,
  nested, dynamic, or non-word map key/value shapes remain explicit diagnostics.
- `storage.map.contains` remains unsupported because EVM mappings do not track
  key presence without an auxiliary bitmap.
- Nested map storage paths remain unsupported; `mapKey` paths are currently
  single-segment only.

Next step:

- Continue reducing the remaining EVM IR unsupported surface, likely around
  richer ABI/cross-call surfaces or target-specific deployment artifacts, with
  the same golden Yul, metadata, Foundry, diagnostics, and CI pattern.

### EVM IR Typed Storage Words

Commit: feature commit for EVM IR typed storage word arrays

Summary:

- Generalized portable EVM storage arrays from `U64`-only arrays to word-scalar
  arrays over `U32`, `U64`, `Bool`, and `Hash`.
- Enabled `Bool` scalar storage in the portable EVM backend; scalar storage
  still rejects unsupported non-word shapes explicitly.
- Reused the existing contiguous `__proof_forge_array_slot(base, length,
  index)` helper for typed word arrays, preserving runtime out-of-bounds
  checks and deterministic slot layout.
- Added `ProofForge.IR.Examples.EvmTypedStorageProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.
- Updated EVM diagnostics, coverage, target docs, validation gates, and Chinese
  docs so `Unit` storage remains the explicit unsupported case while
  `Bool`/`U32`/`Hash` storage arrays are validated behavior.

Validation run:

```sh
lake build ProofForge.Backend.Evm.IR proof-forge
scripts/evm/typed-storage-ir-smoke.sh
```

Known limitations:

- Typed storage arrays are still fixed-size word arrays. Nested arrays, dynamic
  storage arrays, and non-word storage elements remain future work.

Next step:

- Continue reducing the remaining EVM IR unsupported surface, likely either
  richer map shapes or the next ABI/control/cross-call gap, with the same
  golden Yul, metadata, Foundry, diagnostics, and CI pattern.

### EVM IR Flat Storage Structs

Commit: feature commit for EVM IR flat storage struct lowering

Summary:

- Added EVM portable IR lowering for flat scalar storage structs and fixed
  storage arrays of flat structs. Scalar storage structs reserve one slot per
  field; struct arrays reserve `length * field_count` slots.
- Added direct lowering for `storageStructFieldRead`/`Write` and
  `storageArrayStructFieldRead`/`Write`, plus generic storage paths using
  scalar `field` and array `index`+`field` segments.
- Added the `__proof_forge_struct_array_slot` Yul helper with runtime
  out-of-bounds checks and deterministic
  `base + index * field_count + field_offset` slot derivation.
- Added `ProofForge.IR.Examples.EvmStorageStructProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.
- Updated EVM diagnostics and coverage so whole-struct storage reads/writes and
  missing fields fail explicitly before Yul generation.

Validation run:

```sh
lake build proof-forge
scripts/evm/storage-struct-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Known limitations:

- Storage struct support is flat and field-based only. Whole-struct storage
  reads/writes, nested struct fields, map values shaped as structs, and dynamic
  storage arrays remain explicit future work.

Next step:

- Continue EVM portable IR support toward richer storage element types or the
  next unsupported ABI/control surface, keeping the same golden Yul, metadata,
  Foundry, diagnostics, and CI pattern.

### EVM IR Flat Aggregate ABI

Commit: feature commit for EVM IR flat aggregate ABI lowering

Summary:

- Added EVM portable IR ABI flattening for flat static fixed-array and struct
  parameters. Fixed arrays lower to one calldata word per element, and structs
  lower to fields in declaration order.
- Added dispatcher range guards for `U32` and `Bool` words inside aggregate
  ABI parameters.
- Added multi-word return-data lowering for flat fixed-array and struct return
  values, including local fixed-array returns and struct literal returns.
- Added `ProofForge.IR.Examples.EvmAbiAggregateProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.
- Updated EVM diagnostics so Unit ABI values, zero-length ABI arrays, and
  nested aggregate ABI values fail explicitly before Yul generation.

Validation run:

```sh
lake build
scripts/evm/abi-aggregate-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Known limitations:

- Aggregate ABI support is flat/static only. Nested aggregate ABI values,
  dynamic arrays, storage structs, mutable local structs, and struct arrays
  remain future work.

Next step:

- Continue the EVM backend toward storage struct layout or richer ABI/event
  schemas, using the same fixture, golden, metadata, Foundry, and CI pattern.

### CI ContextProbe Target Split

Commit: bugfix commit for CI fixture isolation

Summary:

- Split `ContextProbe` target usage so the shared Psy fixture keeps only
  target-portable context reads.
- Added `ProofForge.IR.Examples.EvmContextProbe` for EVM-only `nativeValue`
  coverage while preserving the existing `ContextProbe` Yul object name,
  selectors, golden Yul, and Foundry smoke behavior.
- Updated EVM context CLI emission to use the EVM-specific fixture, while
  `--emit-context-ir-psy` continues to use the Psy-compatible fixture.
- Fixed the GitHub Actions failure where the Psy golden source step attempted
  to lower `nativeValue`, which Psy IR v0 intentionally rejects.
- Made `scripts/evm/build-examples.sh` explicitly build `ProofForge.Evm` before
  compiling SDK examples so clean CI environments have the SDK `.olean` needed
  by the Lean frontend.

Validation run:

```sh
lake build
# Full Check Psy golden sources block from .github/workflows/ci.yml
scripts/evm/context-ir-smoke.sh
scripts/evm/build-examples.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
git diff --check
```

Known limitations:

- Psy still rejects `nativeValue` by design; EVM owns the current
  `callvalue()` lowering and runtime validation.

Next step:

- Re-run GitHub Actions on `main` and continue the EVM aggregate ABI work after
  CI is green.

### EVM IR Local Struct Values

Commit: feature commit for EVM IR local struct values

Summary:

- Added EVM portable IR lowering for flat immutable local struct values by
  expanding each supported field into an internal Yul local.
- Added direct field-access lowering for local struct values and struct
  literals over `U64`, `U32`, `Bool`, and `Hash` fields.
- Registered partial `data.struct` support in the EVM target profile and
  metadata capability flow.
- Added explicit diagnostics for struct storage, mutable local structs, nested
  struct fields, ABI-facing structs, duplicate/empty struct declarations, and
  unsupported field shapes.
- Added `ProofForge.IR.Examples.EvmStructValueProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.

Validation run:

```sh
lake build
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
git diff --check
```

Known limitations:

- This feature supports flat immutable local struct values only. Mutable local
  structs, nested structs, storage structs, struct arrays, ABI structs, and
  struct assignment paths remain future work.

Next step:

- Continue EVM aggregate coverage toward ABI aggregate values or storage
  struct layout once the target-specific EVM ABI/storage policy is specified.

### EVM IR Local Fixed-Array Values

Commit: feature commit for EVM IR local fixed-array values

Summary:

- Added EVM portable IR lowering for immutable local fixed-array values by
  expanding each array element into an internal Yul local.
- Added static `arrayGet` lowering for local fixed-array values and direct
  fixed-array literals over `U64`, `U32`, `Bool`, and `Hash` elements.
- Added explicit diagnostics for mutable fixed-array locals, dynamic local
  fixed-array indexes, and static out-of-bounds indexes.
- Added `ProofForge.IR.Examples.EvmArrayValueProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.

Validation run:

```sh
lake build proof-forge
scripts/evm/array-value-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
```

Known limitations:

- This feature supports immutable local fixed-array values with static indexes.
  Dynamic local indexes, mutable local arrays, nested arrays, aggregate ABI
  arrays, and storage arrays beyond the existing `U64` path remain future work.

Next step:

- Continue EVM aggregate coverage toward structs or ABI aggregate values, using
  the same fixture/golden/smoke/metadata pattern.

### EVM IR Array Index Storage Paths

Commit: feature commit for EVM IR array index storage paths

Summary:

- Added EVM portable IR lowering for single-segment `StoragePathSegment.index`
  paths over `U64` fixed storage arrays.
- Reused `__proof_forge_array_slot(base, length, index)` for generic
  `storagePathRead`, `storagePathWrite`, and `storagePathAssignOp` so direct
  array effects and storage paths share bounds-checking behavior.
- Extended `EvmStorageArrayProbe` with `path_lifecycle()` and
  `path_assign_lifecycle()`.
- Extended `scripts/evm/storage-array-ir-smoke.sh` to validate path read,
  write, compound assignment, metadata selectors, and raw storage slots.
- Kept nested index paths, struct paths, and non-`U64` arrays explicitly
  rejected.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-storage-array-ir-yul -o build/ir/EvmStorageArrayProbe.yul
diff -u Examples/Evm/EvmStorageArrayProbe.golden.yul build/ir/EvmStorageArrayProbe.yul
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
git diff --check
```

Known limitations:

- This feature supports exactly one `index` path segment over `U64` storage
  arrays. Nested array paths, struct fields, local fixed-array values, and
  aggregate ABI arrays remain future work.

Next step:

- Move from storage-array paths toward local fixed-array values or flat structs,
  depending on which aggregate surface is needed first.

### EVM IR U64 Storage Arrays

Commit: feature commit for EVM IR U64 storage array lowering

Summary:

- Added EVM target-profile support for `storage.array` and partial
  `data.fixed_array`.
- Added state-slot span accounting so fixed storage arrays reserve one EVM
  storage slot per element and later state starts after the full array span.
- Added portable IR lowering for `storageArrayRead` and `storageArrayWrite`
  over `U64` storage arrays.
- Lowered array access through `__proof_forge_array_slot(base, length, index)`,
  which reverts when the runtime index is out of bounds before `sload` or
  `sstore`.
- Added `ProofForge.IR.Examples.EvmStorageArrayProbe`, CLI emission modes,
  golden Yul, Foundry smoke coverage, artifact metadata validation, and CI.
- Kept local fixed-array values, aggregate ABI arrays, generic index storage
  paths, structs, and non-`U64` storage arrays explicitly rejected.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-storage-array-ir-yul -o build/ir/EvmStorageArrayProbe.yul
diff -u Examples/Evm/EvmStorageArrayProbe.golden.yul build/ir/EvmStorageArrayProbe.yul
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
git diff --check
```

Known limitations:

- This feature covers `U64` storage arrays only. `U32`, `Hash`, `Bool`,
  struct arrays, local fixed-array values, ABI arrays, and generic index
  storage paths remain follow-up work.

Next step:

- Extend EVM aggregate support toward local fixed-array values or generic index
  storage paths, then move into structs once the array layout is stable.

### EVM IR Native Value

Commit: feature commit for EVM IR native value lowering

Summary:

- Added EVM portable IR lowering for expression-position `nativeValue` as Yul
  `callvalue()`.
- Extended `ProofForge.IR.Examples.ContextProbe` with `native_value()` and
  selector `0xf0eba40f`.
- Extended `scripts/evm/context-ir-smoke.sh` so Foundry calls
  `native_value()` with attached value and verifies the returned word.
- Updated EVM artifact metadata validation to require `value.native` and the
  `native_value:f0eba40f` entrypoint.
- Moved `Expr.nativeValue` in `Tests/EvmCoverage.tsv` from unsupported to
  validated and removed the old unsupported diagnostic case.

Validation run:

```sh
lake build
lake env proof-forge --emit-context-ir-yul -o build/ir/ContextProbe.yul
diff -u Examples/Evm/ContextProbe.golden.yul build/ir/ContextProbe.yul
scripts/evm/context-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
git diff --check
```

Known limitations:

- `nativeValue` is exposed as the raw EVM call value word. Higher-level native
  asset accounting remains a target/runtime policy layer above this IR node.

Next step:

- Continue expanding EVM portable IR coverage one small capability at a time,
  with fixture, smoke, coverage, docs, commit, and push for each feature.

### EVM IR Map Path Compound Assignment

Commit: feature commit for EVM IR map path compound assignment

Summary:

- Added EVM portable IR lowering for statement-position `storagePathAssignOp`
  on single-segment `mapKey` paths over `Map<U64, U64, N>`.
- Lowered map path compound assignment through generated Yul helpers named
  `__proof_forge_map_assign_<op>`.
- Kept mapping slot calculation inside the helper so the key expression is
  evaluated once and the computed storage slot is reused for `sload` and
  `sstore`.
- Added type validation so storage path compound assignment requires matching
  numeric path/value types.
- Kept nested map paths, array paths, and struct paths explicitly rejected
  until those storage layouts are implemented.
- Extended `ProofForge.IR.Examples.EvmMapProbe` with
  `path_assign_lifecycle()`, updated `Examples/Evm/EvmMapProbe.golden.yul`,
  and extended `scripts/evm/map-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-map-ir-yul -o build/ir/EvmMapProbe.yul
diff -u Examples/Evm/EvmMapProbe.golden.yul build/ir/EvmMapProbe.yul
scripts/evm/map-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmMapProbe Yul includes selector dispatch for
  `path_assign_lifecycle()` and map assign helpers for all `AssignOp`
  variants.
- Foundry verifies `path_assign_lifecycle()` returns `58`, the raw mapping
  slot for key `3003` is `58`, and existing map get/set/path behavior still
  passes.
- EVM artifact metadata records and validates `storage.scalar`, `storage.map`,
  and `assertions.check`.
- Diagnostics reject expression-position `storagePathAssignOp` and nested
  storage-path compound assignment.

Known limitations at the time of this entry:

- EVM IR storage path compound assignment supported only a single `mapKey` over
  `Map<U64, U64, N>`.
- Array index paths, struct field paths, nested paths, and non-`U64` map shapes
  remained explicit diagnostics.

Next step:

- Continue EVM portable IR support toward storage arrays, structs, aggregate
  ABI values, or checked arithmetic semantics.

### EVM IR Compound Assignment

Commit: feature commit for EVM IR compound assignment

Summary:

- Added EVM portable IR lowering for `Statement.assignOp` on mutable local
  `U32`/`U64` bindings.
- Added EVM portable IR lowering for statement-position
  `storageScalarAssignOp` on numeric scalar storage.
- Lowered arithmetic/bitwise compound assignment to Yul
  `add/sub/mul/div/mod/and/or/xor`, and lowered shifts with EVM operand order
  through `shl(shift, value)` and `shr(shift, value)`.
- Added type validation so compound assignment requires matching `U32` or
  `U64` operands, mutable local targets, and scalar numeric storage targets.
- Kept aggregate assignment targets and storage path compound assignment
  outside this local/scalar feature; the following map path entry closes the
  single-segment `mapKey` subset.
- Added `ProofForge.IR.Examples.EvmAssignOpProbe`,
  `--emit-evm-assign-op-ir-yul`, `--emit-evm-assign-op-ir-bytecode`,
  `Examples/Evm/EvmAssignOpProbe.golden.yul`, and
  `scripts/evm/assign-op-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-assign-op-ir-yul -o build/ir/EvmAssignOpProbe.yul
diff -u Examples/Evm/EvmAssignOpProbe.golden.yul build/ir/EvmAssignOpProbe.yul
scripts/evm/assign-op-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmAssignOpProbe Yul includes selector dispatch, local compound
  assignment, scalar storage `sstore(slot, op(sload(slot), value))`, and U32
  ABI range guards.
- Foundry verifies `compound_assignment(uint256)` returns `58`, raw storage
  slot `0` is `58`, `compound_u32(uint32)` returns `11`, and unknown selectors
  revert.
- EVM artifact metadata records and validates `storage.scalar`.
- Diagnostics reject non-local compound assignment targets, non-numeric
  compound operands, and expression-position scalar storage compound
  assignment.

Known limitations:

- EVM IR compound assignment in this entry supports only mutable local scalars
  and scalar storage; aggregate locals remain out of scope.
- Operations use raw EVM word semantics and do not add checked-overflow
  behavior.

Next step:

- Continue EVM portable IR support toward storage arrays, structs, aggregate
  ABI values, or storage-path compound updates.

### EVM IR Bounded Loops

Commit: feature commit for EVM IR bounded loops

Summary:

- Added EVM target support for `control.bounded_loop`.
- Added EVM portable IR lowering for statement-position `boundedFor`.
- Lowered bounded loops to Yul `for` loops with a static `let` index prelude,
  `lt(index, stopExclusive)` condition, and `index := add(index, 1)` post
  block.
- Added type validation for loop bodies with the loop index available as an
  immutable `U32` local.
- Added explicit diagnostics for invalid loop ranges and loop-local returns.
- Added `ProofForge.IR.Examples.EvmLoopProbe`,
  `--emit-evm-loop-ir-yul`, `--emit-evm-loop-ir-bytecode`,
  `Examples/Evm/EvmLoopProbe.golden.yul`, and
  `scripts/evm/loop-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-loop-ir-yul -o build/ir/EvmLoopProbe.yul
diff -u Examples/Evm/EvmLoopProbe.golden.yul build/ir/EvmLoopProbe.yul
scripts/evm/loop-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmLoopProbe Yul includes selector dispatch and a Yul `for` loop
  that increments scalar storage three times.
- Foundry verifies the returned value and raw storage slot are both `3`, plus
  unknown-selector revert behavior.
- EVM artifact metadata records and validates `control.bounded_loop`.
- Diagnostics reject invalid bounded-loop ranges and loop-local returns.

Known limitations:

- EVM IR bounded loops currently require static natural-number bounds from the
  portable IR node.
- Loop-local `return`, `break`, and `continue` are not modeled yet.

Next step:

- Continue expanding EVM portable IR support for aggregate values, storage
  arrays, structs, or compound assignment.

### EVM IR Crosscalls

Commit: feature commit for EVM IR crosscalls

Summary:

- Added EVM portable IR lowering for expression-position `crosscallInvoke`.
- Defined the EVM IR v0 crosscall policy: target is an address word, method is
  a low-32-bit selector, arguments are 32-byte words, the call uses zero ETH
  value, and the result is one 32-byte return word.
- Added arity-specific Yul helpers that pack calldata, call
  `call(gas(), target, 0, ...)`, revert on failed calls or short returns, and
  decode the returned word.
- Added type validation so crosscall target, method, and every argument must be
  `U64`.
- Added `ProofForge.IR.Examples.EvmCrosscallProbe`,
  `--emit-evm-crosscall-ir-yul`, `--emit-evm-crosscall-ir-bytecode`,
  `Examples/Evm/EvmCrosscallProbe.golden.yul`, and
  `scripts/evm/crosscall-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-crosscall-ir-yul -o build/ir/EvmCrosscallProbe.yul
diff -u Examples/Evm/EvmCrosscallProbe.golden.yul build/ir/EvmCrosscallProbe.yul
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmCrosscallProbe Yul includes selector dispatch, calldata size
  guards, zero/one/two-argument crosscall helpers, failed-call reverts,
  short-return reverts, and one-word return decoding.
- Foundry verifies a Solidity callee for zero/one/two argument calls, callee
  reverts, short returns, and unknown-selector reverts.
- EVM artifact metadata records and validates `crosscall.invoke`.
- Diagnostics reject malformed crosscall target, method, and argument types.

Known limitations at this slice:

- This first crosscall slice modeled only synchronous zero-value `call`.
- Later slices below add typed scalar returns and value-bearing typed scalar
  calls; `staticcall`, `delegatecall`, create/create2, aggregate
  arguments/returns, and variable-length return data remain future IR work.

Next step:

- Continue expanding the EVM portable IR surface toward typed scalar returns,
  aggregate ABI values, arrays, structs, or richer call semantics.

### EVM IR Typed Scalar Crosscalls

Commit: feature commit for EVM IR typed scalar crosscalls

Summary:

- Added portable IR `crosscallInvokeTyped` as a typed scalar-word crosscall
  expression while preserving the existing `crosscallInvoke` U64 behavior and
  helper names.
- Extended EVM lowering so typed crosscalls accept `Bool`, `U32`, `U64`, and
  `Hash` word arguments and return `Bool`, `U32`, `U64`, or `Hash`.
- Generated return-type-specific Yul helpers such as
  `__proof_forge_crosscall_1_bool`, `__proof_forge_crosscall_1_u32`, and
  `__proof_forge_crosscall_1_hash`; Bool and U32 helpers reject out-of-range
  return words after `returndatacopy`.
- Extended `EvmCrosscallProbe` with `call_remote_bool`, `call_remote_u32`, and
  `call_remote_hash`, plus Foundry callee methods for valid typed returns and
  malformed Bool/U32 return words.
- Added explicit EVM diagnostics for unsupported typed crosscall aggregate
  arguments/returns and an explicit Psy diagnostic because Psy IR v0 still only
  supports untyped Felt-returning `crosscallInvoke`.
- Updated golden Yul, EVM/Psy coverage manifests, validation gates, EVM target
  docs, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-crosscall-ir-yul -o build/ir/EvmCrosscallProbe.yul
diff -u Examples/Evm/EvmCrosscallProbe.golden.yul build/ir/EvmCrosscallProbe.yul
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/psy/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/psy/check-ir-coverage-manifest.py
```

Result:

- Generated EvmCrosscallProbe Yul includes selector dispatch for the typed
  entrypoints, Bool/U32 calldata guards, typed crosscall helper names, and
  Bool/U32 return-data guards.
- Foundry verifies U64 zero/one/two-argument calls, Bool/U32/Hash typed return
  calls, callee reverts, short returns, invalid Bool/U32 return words, and
  unknown-selector reverts.
- EVM artifact metadata validates all six CrosscallProbe entrypoints and
  records `crosscall.invoke`.
- Diagnostics reject unsupported typed crosscall aggregate arguments/returns,
  while Psy rejects typed crosscalls explicitly instead of silently lowering
  them as Felt calls.

Known limitations:

- Portable IR EVM crosscalls still model only synchronous `call`.
- Aggregate arguments/returns, multi-word return data, `staticcall`,
  `delegatecall`, and create/create2 remain future IR work.

Next step:

- Continue closing EVM backend gaps around richer call semantics, ABI aggregate
  storage-backed surfaces, and unsupported-node diagnostics.

### EVM IR Value-Bearing Typed Crosscalls

Commit: feature commit for EVM IR value-bearing typed crosscalls

Summary:

- Added portable IR `crosscallInvokeValueTyped` for synchronous EVM calls that
  forward an explicit `U64` call-value expression while returning a typed
  scalar word.
- Extended EVM lowering with value-specific Yul helpers named like
  `__proof_forge_crosscall_value_0`; these helpers keep the same selector and
  calldata packing as scalar crosscalls but pass `call_value` into the EVM
  `call(gas(), target, call_value, ...)` value slot.
- Extended `EvmCrosscallProbe` with `call_remote_value`, implemented using
  `.nativeValue` so the entrypoint forwards the ETH received by the probe to a
  payable callee.
- Added Foundry coverage that calls the probe with value, asserts the payable
  callee receives `msg.value`, checks the callee balance, and verifies the probe
  does not retain the forwarded value.
- Added explicit EVM diagnostics for malformed call-value type and unsupported
  aggregate return type, plus an explicit Psy unsupported diagnostic for
  value-bearing typed crosscalls.
- Updated golden Yul, coverage manifests, validation gates, EVM target docs,
  backlog, and Chinese docs.

Validation run:

```sh
lake build
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/psy/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/psy/check-ir-coverage-manifest.py
```

Result:

- `EvmCrosscallProbe` now has seven metadata-validated entrypoints, including
  `call_remote_value:365f4a44`.
- Generated Yul includes `__proof_forge_crosscall_value_0(target, selector,
  call_value)` and passes the helper value parameter to the `call` opcode.
- Foundry verifies 12 crosscall runtime paths, including ETH forwarding through
  `probe.call{value: 1234}` to a payable callee.
- EVM and Psy diagnostics cover the new portable IR node instead of relying on
  missing-pattern or silent lowering behavior.

Known limitations:

- Value-bearing crosscalls are currently limited to synchronous EVM `call` and
  single scalar-word return data.
- `staticcall`, `delegatecall`, create/create2, aggregate arguments/returns,
  and multi-word or variable-length return data remain future IR work.

Next step:

- Continue closing EVM cross-contract gaps around richer call kinds and richer
  return-data encoding.

### EVM IR Events

Commit: feature commit for EVM IR events

Summary:

- Added EVM portable IR lowering for statement-position `eventEmit`.
- Defined the EVM IR v0 event policy:
  `topic0 = keccak256(Solidity-style event signature)` and log data is the
  sequence of 32-byte field words.
- Added event name and field validation: event names must be non-empty; event
  fields must be `U32`, `U64`, `Bool`, or `Hash`; event emission remains
  statement-only.
- Added `--emit-evm-event-ir-yul`, `--emit-evm-event-ir-bytecode`,
  `Examples/Evm/EventProbe.golden.yul`, and
  `scripts/evm/event-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-event-ir-yul -o build/ir/EventProbe.yul
diff -u Examples/Evm/EventProbe.golden.yul build/ir/EventProbe.yul
scripts/evm/event-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EventProbe Yul includes selector dispatch, calldata size guards,
  event signature hashing, field data writes, and `log1(0, 32, topic0)`.
- Foundry verifies recorded logs for emitter address, topic0, decoded data,
  and unknown-selector reverts.
- EVM artifact metadata records and validates `events.emit`.
- Diagnostics reject expression-position events and malformed event names.

Known limitations:

- Event data fields are limited to scalar word values.
- Indexed fields are now covered by `eventEmitIndexed`; aggregate event
  payloads and richer event declarations remain future work.

Next step:

- Extend aggregate event payloads or richer event declarations, or start
  cross-contract call lowering for the EVM portable IR backend.

### EVM IR Hash Words

Commit: feature commit for EVM IR hash words

Summary:

- Added EVM portable IR lowering for `Hash` as a one-word EVM `bytes32`
  representation across locals, ABI parameters, ABI returns, and scalar
  storage.
- Added `hash4` literal packing and dynamic `hashValue` packing from four
  `U64` limbs into one 256-bit word.
- Added Yul helper lowering for `hash` and `hash_two_to_one` using
  `keccak256(0, 32)` and `keccak256(0, 64)`.
- Added lightweight EVM IR type validation for the currently supported scalar
  and Hash subset so Hash/U64 mismatches fail before Yul generation.
- Added `ProofForge.IR.Examples.EvmHashProbe`,
  `--emit-evm-hash-ir-yul`, `--emit-evm-hash-ir-bytecode`,
  `Examples/Evm/EvmHashProbe.golden.yul`, and
  `scripts/evm/hash-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-hash-ir-yul -o build/ir/EvmHashProbe.yul
diff -u Examples/Evm/EvmHashProbe.golden.yul build/ir/EvmHashProbe.yul
scripts/evm/hash-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmHashProbe Yul includes selector dispatch, ABI calldata size
  guards, Hash literal packing, dynamic Hash packing, `keccak256` helpers,
  Hash scalar storage reads/writes, and one-word return encoding.
- Foundry verifies `bytes32` ABI params/returns, single-word and pair hashing,
  dynamic packing, Hash scalar storage, raw slot reads through `vm.load`, and
  unknown-selector reverts.
- EVM artifact metadata records and validates `crypto.hash` and
  `storage.scalar`.
- Diagnostics now treat Hash as supported in the EVM scalar subset and reject
  malformed Hash/U64 usage with explicit type mismatch messages.

Known limitations:

- EVM portable IR Hash currently uses a target-specific one-word `bytes32`
  representation; Psy still uses four Felt limbs.
- Hash map key/value shapes are still unsupported; EVM map support remains
  limited to `Map<U64, U64, N>`.
- Aggregate hashing inputs, arrays, structs, and events remain future work.

Next step:

- Extend EVM maps to additional scalar key/value shapes, or add event emission
  lowering with indexed topic/data metadata.

### EVM IR Storage Maps

Commit: feature commit for EVM IR storage maps

Summary:

- Added EVM portable IR lowering for `Map<U64, U64, N>` storage state.
- Added Solidity-style mapping slot helpers:
  `mstore(0, key)`, `mstore(32, slot)`, `keccak256(0, 64)`.
- Added EVM lowering for `storageMapGet`, `storageMapInsert`, and
  `storageMapSet`; expression-position set/insert return the previous value.
- Added single-segment `storagePathRead`/`storagePathWrite` support for
  `.mapKey` paths over `Map<U64, U64, N>`.
- Kept `storageMapContains` explicitly unsupported because EVM mappings do not
  track key presence without an auxiliary bitmap.
- Added `ProofForge.IR.Examples.EvmMapProbe`, `--emit-evm-map-ir-yul`,
  `--emit-evm-map-ir-bytecode`, `Examples/Evm/EvmMapProbe.golden.yul`, and
  `scripts/evm/map-ir-smoke.sh`.
- Updated EVM diagnostics, coverage manifest, CI, EVM target docs, validation
  gates, backlog, and Chinese docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-evm-map-ir-yul -o build/ir/EvmMapProbe.yul
diff -u Examples/Evm/EvmMapProbe.golden.yul build/ir/EvmMapProbe.yul
scripts/evm/map-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated EvmMapProbe Yul includes selector dispatch, scalar ABI calldata
  guards, map helper functions, map get/set/insert calls, assertion guards, and
  `keccak256(0, 64)` slot hashing.
- Foundry verifies lifecycle behavior, parameterized read/write behavior,
  single-segment `mapKey` storage paths, unknown-selector reverts, and raw
  mapping slots with `vm.load`.
- EVM artifact metadata records and validates `storage.scalar`, `storage.map`,
  and `assertions.check`.
- Diagnostics reject unsupported Hash map shapes, `storage.map.contains`, and
  malformed map storage paths.

Known limitations:

- EVM portable IR map support is currently limited to `Map<U64, U64, N>`.
- `storage.map.contains` remains unsupported until the IR models an EVM
  presence bitmap or a different target-specific presence policy.
- Nested map/struct/array storage paths are still rejected.

Next step:

- Extend maps to more scalar key/value shapes, or add EVM `crypto.hash`
  lowering with a clear Keccak-vs-portable-Hash semantic boundary.

### EVM IR Context Reads

Commit: feature commit for EVM IR context reads

Summary:

- Added EVM portable IR lowering for `contextRead` expressions:
  `userId -> caller()`, `contractId -> address()`, and
  `checkpointId -> number()`.
- Added an EVM selector to `ContextProbe` while preserving the existing Psy
  context fixture.
- Added `--emit-context-ir-yul` and `--emit-context-ir-bytecode` CLI modes.
- Added `Examples/Evm/ContextProbe.golden.yul` plus
  `scripts/evm/context-ir-smoke.sh`.
- Updated EVM capability metadata so `ContextProbe` validates
  `caller.sender`, `account.explicit`, and `env.block`.
- Updated EVM diagnostics, coverage manifest, CI, target docs, validation
  gates, backlog, and capability registry docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-context-ir-yul -o build/ir/ContextProbe.yul
diff -u Examples/Evm/ContextProbe.golden.yul build/ir/ContextProbe.yul
scripts/evm/context-ir-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
```

Result:

- Generated ContextProbe Yul contains selector dispatch for
  `sum_context(uint256,uint256)`, ABI calldata size guarding, and direct EVM
  context opcodes.
- Foundry verifies `caller()` via `vm.prank`, `number()` via `vm.roll`, and
  `address()` via an etched runtime address.
- EVM artifact metadata records and validates the three context capabilities.
- Statement-position context reads remain rejected with an explicit diagnostic.

Known limitations:

- The current portable `ContextField` set covers only user id, contract id, and
  checkpoint id.
- EVM context values are emitted as 256-bit words; address-width and narrower
  integer normalization are still future type-validation work.

Next step:

- Add EVM `crypto.hash` lowering with a clear Keccak-vs-portable-Hash semantic
  boundary, or start EVM storage map slot hashing.

### EVM Artifact Metadata

Commit: feature commit for EVM artifact metadata

Summary:

- Added EVM `proof-forge-artifact.json` emission to `proof-forge`
  bytecode-producing modes, covering both `--evm-bytecode` SDK builds and
  portable IR EVM bytecode fixtures.
- Added `--artifact-output` to override the metadata path; without an override,
  bytecode modes write `proof-forge-artifact.json` next to the bytecode output.
- Added metadata fields for schema version, target id/family, artifact kind,
  source kind/module, portable IR version, capability ids, selector-facing ABI,
  `solc` path/version, Yul/bytecode/source artifact hashes and byte sizes, and
  validation status.
- Added `scripts/evm/validate-artifact-metadata.py` for machine validation of
  EVM metadata files.
- Updated EVM IR smoke scripts and `scripts/evm/build-examples.sh` so generated
  metadata is validated in CI.
- Updated EVM target docs, validation gates, backlog, portable IR docs, and
  Chinese docs.

Validation run:

```sh
lake build
PATH="$HOME/.foundry/bin:$PATH" lake env proof-forge --evm-bytecode --root . --module contract \
  --artifact-output build/evm/Counter.proof-forge-artifact.json \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
python3 scripts/evm/validate-artifact-metadata.py --root . \
  --expect-fixture Counter.lean \
  --expect-source-kind lean-sdk \
  build/evm/Counter.proof-forge-artifact.json
bash -n scripts/evm/*.sh
python3 -m py_compile scripts/evm/validate-artifact-metadata.py
scripts/evm/conditional-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- SDK EVM bytecode builds emit validated metadata with source, Yul, bytecode,
  method selectors, and `solc` validation status.
- Portable IR EVM bytecode builds emit validated metadata with fixture name,
  source module, `irVersion: portable-ir-v0`, capability ids, ABI selectors,
  Yul/bytecode hashes, and validation status.
- Each EVM IR smoke now writes a fixture-specific metadata file to avoid
  parallel-run overwrite races.
- `scripts/evm/build-examples.sh` validates metadata for every SDK example with
  a sibling `.evm-methods` file.

Known limitations:

- EVM metadata is still build metadata, not a full deploy manifest.
- `capabilities` are populated for portable IR fixtures; SDK builds currently
  record method metadata but not inferred SDK capability ids.

Next step:

- Add EVM context or hashing lowering as the next isolated capability slice, or
  turn metadata into a unified target manifest when more targets share the
  schema.

### EVM IR Conditionals

Commit: feature commit for EVM IR conditionals

Summary:

- Added `control.conditional` to the EVM target profile.
- Extended `ProofForge.Backend.Evm.IR` to lower portable IR `if/else` into Yul
  `switch condition case 0 { else } default { then }` blocks.
- Kept branch-local `return` statements explicitly rejected because EVM IR
  `return` currently assigns the generated function result and does not yet
  emit Yul `leave` for early return semantics.
- Added an EVM selector to `ConditionalProbe` while preserving Psy output.
- Added `--emit-conditional-ir-yul` and
  `--emit-conditional-ir-bytecode` CLI modes.
- Added `Examples/Evm/ConditionalProbe.golden.yul` and
  `scripts/evm/conditional-ir-smoke.sh`, then wired the smoke into CI.
- Updated EVM diagnostics, coverage manifest, capability registry, validation
  docs, EVM target docs, and Chinese documentation.

Validation run:

```sh
lake build
lake env proof-forge --emit-conditional-ir-yul -o build/ir/ConditionalProbe.yul
diff -u Examples/Evm/ConditionalProbe.golden.yul build/ir/ConditionalProbe.yul
lake env proof-forge --emit-conditional-ir-psy -o build/psy/ConditionalProbe.psy
diff -u Examples/Psy/ConditionalProbe.golden.psy build/psy/ConditionalProbe.psy
bash -n scripts/evm/*.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/conditional-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- Generated ConditionalProbe Yul matches the checked-in golden fixture and
  contains Yul `switch` blocks for both then and else paths.
- Psy ConditionalProbe output remains unchanged after adding target-specific
  selector metadata.
- `scripts/evm/conditional-ir-smoke.sh` compiles ConditionalProbe to bytecode
  and passes Foundry tests for the expected conditional lifecycle result and
  unknown-selector revert behavior.
- EVM diagnostics now cover the remaining conditional boundary: branch-local
  return statements.

Known limitations:

- Conditional branch early returns are not supported until EVM IR return
  lowering grows Yul `leave`.
- The EVM IR backend still has minimal expression type validation.

Next step:

- Add EVM artifact metadata or scalar context/hash lowering as the next isolated
  feature slice.

### EVM IR Local Assignment

Commit: feature commit for EVM IR local assignment

Summary:

- Treated the capability-complete EVM backend prompt as an incremental
  validation contract: every portable IR node must either gain a positive EVM
  fixture or retain a documented diagnostic.
- Extended `ProofForge.Backend.Evm.IR` so mutable scalar local bindings lower
  to Yul `let` declarations.
- Extended EVM IR assignment lowering for local targets as Yul `:=`
  assignments, while keeping non-local assignment targets and compound
  assignment statements explicitly rejected.
- Added `ProofForge.IR.Examples.AssignmentProbe` with
  `reassignment(uint256)`, covering mutable `U64` and `Bool` locals plus a
  bool guard that depends on assignment.
- Added `--emit-assignment-ir-yul` and
  `--emit-assignment-ir-bytecode` CLI modes.
- Added `Examples/Evm/AssignmentProbe.golden.yul` and
  `scripts/evm/assignment-ir-smoke.sh`, then wired the smoke into CI.
- Updated EVM diagnostics, coverage manifest, validation docs, and the EVM
  target docs.

Validation run:

```sh
lake build
lake env proof-forge --emit-assignment-ir-yul -o build/ir/AssignmentProbe.yul
diff -u Examples/Evm/AssignmentProbe.golden.yul build/ir/AssignmentProbe.yul
bash -n scripts/evm/*.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- Generated AssignmentProbe Yul matches the checked-in golden fixture and
  contains `let total := seed`, `total := add(total, 7)`, and
  `matched := eq(total, 12)`.
- `scripts/evm/assignment-ir-smoke.sh` compiles AssignmentProbe to bytecode and
  passes Foundry tests for the successful assignment path and the bool-guard
  revert path.
- EVM diagnostics now cover the remaining assignment boundaries: non-local
  assignment targets and compound assignment statements.

Known limitations:

- Local assignment support is scalar-only (`U32`, `U64`, `Bool`).
- Compound assignment, aggregate assignment paths, storage assignment paths,
  and artifact metadata remain separate EVM work items.

Next step:

- Add EVM IR statement-level conditional lowering or EVM artifact metadata as
  the next isolated feature slice.

### EVM IR Assertions

Commit: feature commit for EVM IR assertions

Summary:

- Added `assertions.check` to the EVM target profile and capability registry.
- Extended `ProofForge.Backend.Evm.IR` to lower portable IR `assert` into
  `if iszero(condition) { revert(0, 0) }`.
- Extended EVM IR `assertEq` lowering into
  `if iszero(eq(lhs, rhs)) { revert(0, 0) }`.
- Added an EVM selector to `AssertProbe` while preserving Psy's selector-ignore
  behavior.
- Added `--emit-assert-ir-yul` and `--emit-assert-ir-bytecode` CLI modes.
- Added `Examples/Evm/AssertProbe.golden.yul` and
  `scripts/evm/assert-ir-smoke.sh`, then wired the smoke into CI.
- Updated EVM diagnostics and coverage manifest to treat assertions as lowered
  instead of unsupported.

Validation run:

```sh
lake build
lake env proof-forge --emit-assert-ir-yul -o build/ir/AssertProbe.yul
diff -u Examples/Evm/AssertProbe.golden.yul build/ir/AssertProbe.yul
lake env proof-forge --emit-assert-ir-psy -o build/psy/AssertProbe.psy
diff -u Examples/Psy/AssertProbe.golden.psy build/psy/AssertProbe.psy
bash -n scripts/evm/*.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/assert-ir-smoke.sh
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- Generated EVM AssertProbe Yul matches the checked-in golden fixture.
- Psy AssertProbe output remains unchanged after adding target-specific selector
  metadata.
- `scripts/evm/assert-ir-smoke.sh` compiles AssertProbe to bytecode and passes
  Foundry tests for both successful assertion execution and assertion-failure
  revert behavior.
- Existing EVM ABI scalar, IR Counter, SDK example build, and Foundry smoke
  gates still pass.

Known limitations:

- EVM assertions currently revert with empty revert data.
- Expression type validation is still minimal in the EVM IR backend.

Next step:

- Add EVM IR statement-level assignment or conditional lowering so larger
  portable IR fixtures can move from unsupported diagnostics to Foundry-backed
  positive coverage.

### EVM IR Scalar ABI Parameters

Commit: feature commit for EVM IR scalar ABI parameters

Summary:

- Added `ProofForge.IR.Examples.AbiScalarProbe` with `mix(uint256,uint32,bool)`
  and `same(uint256,uint256)` portable IR entrypoints.
- Extended `ProofForge.Backend.Evm.IR` so `U64`, `U32`, and `Bool` entrypoint
  parameters lower to Yul function parameters and dispatcher `calldataload`
  arguments.
- Added dispatcher ABI guards for short calldata, out-of-range `uint32`
  values, and invalid `bool` encodings.
- Added CLI modes:
  `--emit-abi-scalar-ir-yul` and `--emit-abi-scalar-ir-bytecode`.
- Added `Examples/Evm/AbiScalarProbe.golden.yul` and
  `scripts/evm/abi-scalar-ir-smoke.sh`, then wired the smoke into CI.
- Updated EVM diagnostics to reject only non-scalar ABI parameter types instead
  of rejecting every parameterized entrypoint.

Validation run:

```sh
lake build
lake env proof-forge --emit-abi-scalar-ir-yul -o build/ir/AbiScalarProbe.yul
diff -u Examples/Evm/AbiScalarProbe.golden.yul build/ir/AbiScalarProbe.yul
bash -n scripts/evm/*.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- Generated Yul includes selector dispatch for `mix` and `same`, calldata size
  guards, `uint32` range validation, and `bool` encoding validation.
- `scripts/evm/abi-scalar-ir-smoke.sh` compiles the fixture to bytecode,
  verifies the golden Yul snapshot, and passes Foundry tests for valid calls
  and malformed calldata reverts.
- EVM diagnostic smoke passes after replacing the obsolete all-parameter
  rejection with Unit/Hash ABI parameter diagnostics.
- Existing EVM SDK examples still build and the Foundry smoke suite passes all
  four tests.

Known limitations:

- This only covers scalar word ABI parameters and one-word returns.
- Aggregate ABI values, dynamic data, events, and artifact metadata remain
  pending.

Next step:

- Add the next EVM IR positive fixture for either assertions/reverts or
  statement-level assignment before expanding storage layout.

### EVM IR Coverage And Diagnostics Baseline

Commit: feature commit for EVM IR coverage and diagnostics

Summary:

- Added `Tests/EvmCoverage.tsv`, tracking every portable IR constructor as
  `lowered`, `validated`, `unsupported`, or `structural` for the current EVM
  IR backend.
- Added `scripts/evm/check-ir-coverage-manifest.py` so new portable IR nodes
  must be classified for EVM before CI passes.
- Added `Tests/EvmDiagnostics.lean` and `scripts/evm/diagnostic-smoke.sh`,
  covering explicit diagnostics for missing selectors, unsupported ABI
  parameters, missing returns, unsupported aggregate/control/storage/context
  surfaces, events, crosscalls, native value, and Hash expressions.
- Fixed the EVM IR backend to reject non-Unit entrypoints that do not end with
  a return statement instead of emitting an unassigned `result`.
- Wired the new EVM diagnostic and coverage gates into CI.

Validation run:

```sh
lake build
bash -n scripts/evm/*.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/ir-counter-smoke.sh
scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
git diff --check
```

Result:

- `scripts/evm/diagnostic-smoke.sh` passes 25 diagnostic cases.
- `scripts/evm/check-ir-coverage-manifest.py` confirms 91 portable IR
  constructor entries match `ProofForge/IR/Contract.lean`.
- The EVM IR Counter smoke still compiles to bytecode and passes Foundry.
- The existing EVM SDK examples still build and the Foundry smoke suite passes
  all four tests.

Known limitations:

- This feature does not expand EVM lowering support; unsupported surfaces remain
  explicit until implemented with Yul golden, solc, and Foundry coverage.
- EVM artifact metadata is still pending.

Next step:

- Start replacing selected `unsupported` EVM coverage rows with Dapp-style
  Yul/Foundry-backed positive fixtures, one feature at a time.

### Psy Fixed Array Equality

Commit: feature commit for Psy fixed-array equality

Summary:

- Allowed Psy IR equality validation for fixed-array value types after a Dargo
  probe confirmed Psy supports `assert_eq(xs, ys)`, `xs == ys`, and `xs != zs`
  for fixed arrays.
- Extended `ArrayProbe` with `array_predicates`, covering fixed-array
  `assert_eq`, equality, and inequality over `[Felt; 3]` locals.
- Updated `scripts/psy/array-smoke.sh` to compile and execute
  `array_predicates`, record `result_vm: [1]`, and include it in artifact
  metadata validation.

Validation run:

```sh
lake build
lake env proof-forge --emit-array-ir-psy -o build/psy/ArrayProbe.psy
diff -u Examples/Psy/ArrayProbe.golden.psy build/psy/ArrayProbe.psy
bash -n scripts/psy/*.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/array-smoke.sh
git diff --check
```

Result:

- Generated ArrayProbe source includes `array_predicates`, using
  `assert_eq(xs, ys, ...)`, `xs == ys`, and `xs != zs`.
- `scripts/psy/array-smoke.sh` validates `sum_literal`,
  `storage_lifecycle`, and `array_predicates` through Dargo test, compile,
  execute, ABI generation, deploy manifest, and artifact metadata checks.
- Dargo execution returns `result_vm: [1]` for `array_predicates`.

Known limitations:

- This feature covers same-typed fixed-array equality only; mismatched element
  types and lengths still fail through the existing type checker.

Next step:

- Commit and push this single feature before starting the next Psy surface area.

### Psy Native U32 Storage Struct Paths

Commit: feature commit for Psy native U32 storage struct paths

Summary:

- Fixed Psy `storagePathWrite` so U32 paths only cast to Felt for the validated
  Felt-backed U32 storage-array representation.
- Allowed native U32 storage struct field paths to use Psy's own `u32` storage
  reference idiom for path writes, reads, and compound assignment.
- Extended `StorageNestedAggregateProbe` with a native `Profile.rank: u32`
  storage field across scalar struct and storage-array paths.
- Removed the obsolete diagnostic that rejected non-array U32 storage-path
  compound assignment.

Validation run:

```sh
lake build
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
diff -u Examples/Psy/StorageNestedAggregateProbe.golden.psy build/psy/StorageNestedAggregateProbe.psy
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/storage-nested-aggregate-smoke.sh
```

Result:

- Generated StorageNestedAggregateProbe source emits native `pub rank: u32`,
  native U32 path writes such as `c.person.profile.rank = 9u32`, and native
  U32 path compound assignment such as `c.person.profile.rank += 4u32`.
- `scripts/psy/diagnostic-smoke.sh` passes all 48 diagnostic cases after
  removing the obsolete unsupported U32 path case.
- `scripts/psy/storage-nested-aggregate-smoke.sh` passes `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  validation, and artifact metadata validation.
- Dargo execution returns `result_vm: [252]` for `storage_nested_lifecycle`.

Known limitations:

- Direct Psy `[u32; N]` contract storage arrays remain avoided because current
  `psyup` 0.1.0 rejects them with an `ArrayRef<u32, N>` mismatch.
- Map value compound assignment remains outside the supported storage-path
  surface.

Next step:

- Continue shrinking storage and ABI edge cases into Dargo-backed fixtures, one
  committed feature at a time.

### Psy U32 Storage Path Assignment

Commit: feature commit for Psy U32 storage path assignment

Summary:

- Extended Psy lowering for Felt-backed U32 storage arrays so
  `storagePathAssignOp` emits typed read/update/write code instead of raw Felt
  compound assignment.
- Covered all `AssignOp` variants in `U32StorageArrayProbe`: arithmetic,
  modulo, bitwise, and shifts.
- Kept non-array U32 storage-path compound assignment rejected with an explicit
  ProofForge diagnostic until that storage representation is validated.
- Updated the golden Psy source, Dargo smoke expected result, coverage matrix,
  and validation docs.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-storage-array-smoke.sh
```

Result:

- Generated U32StorageArrayProbe source rewrites U32 storage-path compound
  assignment as `.get() as u32`, typed operation, then `as Felt` writeback.
- `scripts/psy/diagnostic-smoke.sh` passes all 49 diagnostic cases, including
  the remaining unsupported non-array U32 storage-path assignment boundary.
- `scripts/psy/u32-storage-array-smoke.sh` passes `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  validation, and artifact metadata validation.
- Dargo execution returns `result_vm: [28]` for `storage_lifecycle`.

Known limitations:

- Direct Psy `[u32; N]` contract storage arrays remain avoided because current
  `psyup` 0.1.0 rejects them with an `ArrayRef<u32, N>` mismatch.
- U32 storage-path compound assignment is supported only for the validated
  Felt-backed storage-array representation, not arbitrary U32 struct paths.
  This struct-path limitation is superseded by the native U32 storage struct
  path entry above.

Next step:

- Continue closing one Psy storage or expression gap per feature branch, with
  Dargo-backed smoke coverage before each commit.

### Psy Hash Storage Coverage

Commit: feature commit for Psy Hash storage coverage

Summary:

- Added `HashStorageProbe` as a portable IR fixture for native Psy scalar
  `Hash` storage and `[Hash; N]` storage arrays.
- Extended Psy state validation so `StateDecl.kind = .scalar` with
  `type = .hash` lowers to `pub root: Hash`.
- Added CLI emission through `--emit-hash-storage-ir-psy` plus a checked
  golden source fixture.
- Added `scripts/psy/hash-storage-smoke.sh` to validate `dargo test`,
  `dargo compile`, two `dargo execute` entrypoints, `dargo generate-abi`,
  deploy manifest generation, and artifact metadata validation.

Validation run:

```sh
lake build
bash -n scripts/psy/*.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake env proof-forge --emit-hash-storage-ir-psy -o build/psy/HashStorageProbe.psy
diff -u Examples/Psy/HashStorageProbe.golden.psy build/psy/HashStorageProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/hash-storage-smoke.sh
git diff --check
```

Result:

- Generated HashStorageProbe source lowers `pub root: Hash`,
  `pub roots: [Hash; 2]`, scalar Hash read/write, indexed Hash array read/write,
  and generic storage-path read/write.
- Dargo execution validates `result_vm: [5, 6, 7, 8]` for scalar storage and
  `result_vm: [55, 66, 77, 88]` for storage-array access.

Known limitations:

- This does not change U32 storage arrays, which remain Felt-backed because
  Dargo v0.1.0 rejects direct `[u32; N]` contract storage arrays.

Next step:

- Continue replacing explicit unsupported storage diagnostics with
  Dargo-validated Psy storage idioms where the upstream toolchain accepts the
  shape.

### Psy Bool Storage Array Coverage

Commit: feature commit for Psy Bool storage array coverage

Summary:

- Added `BoolStorageArrayProbe` as a portable IR fixture for native Psy
  `[bool; N]` fixed arrays and `bool` storage arrays.
- Extended Psy state validation so `StateDecl.kind = .array N` with
  `type = .bool` lowers to `pub flags: [bool; N]`.
- Added CLI emission through `--emit-bool-storage-array-ir-psy` plus a checked
  golden source fixture.
- Replaced the previous unsupported bool storage-array diagnostic with an
  unsupported Unit storage-array diagnostic.
- Added `scripts/psy/bool-storage-array-smoke.sh` to validate `dargo test`,
  `dargo compile`, two `dargo execute` entrypoints, `dargo generate-abi`,
  deploy manifest generation, and artifact metadata validation.

Validation run:

```sh
lake build
bash -n scripts/psy/*.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake env proof-forge --emit-bool-storage-array-ir-psy -o build/psy/BoolStorageArrayProbe.psy
diff -u Examples/Psy/BoolStorageArrayProbe.golden.psy build/psy/BoolStorageArrayProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/bool-storage-array-smoke.sh
git diff --check
```

Result:

- Generated BoolStorageArrayProbe source lowers local `[bool; 3]` arrays,
  `pub flags: [bool; 3]` storage arrays, indexed storage read/write, generic
  storage-path read/write, and `bool as Felt` return casts.
- Dargo execution validates `result_vm: [2]` for both `local_flags_sum` and
  `storage_lifecycle`.

Known limitations:

- This does not change the existing U32 storage-array representation; U32
  arrays remain Felt-backed because Dargo v0.1.0 rejects direct `[u32; N]`
  contract storage arrays.

Next step:

- Continue shrinking explicit unsupported diagnostics into Dargo-validated Psy
  support where the upstream toolchain accepts the target shape.

### Psy Bool Scalar Storage Coverage

Commit: feature commit for Psy Bool scalar storage coverage

Summary:

- Added `BoolStorageScalarProbe` as a portable IR fixture for native Psy
  `bool` scalar storage.
- Added CLI emission through `--emit-bool-storage-scalar-ir-psy` plus a
  checked golden source fixture.
- Added `scripts/psy/bool-storage-scalar-smoke.sh` to validate `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  generation, and artifact metadata validation.
- Extended Psy coverage evidence, validation docs, and CI golden checks.

Validation run:

```sh
lake build
bash -n scripts/psy/*.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake env proof-forge --emit-bool-storage-scalar-ir-psy -o build/psy/BoolStorageScalarProbe.psy
diff -u Examples/Psy/BoolStorageScalarProbe.golden.psy build/psy/BoolStorageScalarProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/bool-storage-scalar-smoke.sh
git diff --check
```

Result:

- Generated BoolStorageScalarProbe source lowers scalar storage to
  `pub flag: bool`, native Bool reads/writes, and `bool as Felt` return casts.
- Dargo execution validates `result_vm: [1]`.

Known limitations:

- This entry covered native scalar `bool` storage only. The later
  BoolStorageArrayProbe entry supersedes the previous bool storage-array
  limitation.

Next step:

- Continue filling the Psy scalar/aggregate storage matrix one feature at a
  time, with Dargo execution backing each newly enabled shape.

### Psy Map Set Expression Return Coverage

Commit: feature commit for Psy map set expression returns

Summary:

- Added Psy lowering and type validation for `storageMapSet` when used as an
  expression, matching upstream `MapRef::set` returning the previous `Hash`.
- Extended `MapProbe` with `set_return_lifecycle` and
  `insert_return_lifecycle` to cover absent-key zero returns, previous-value
  returns, and latest-value reads.
- Updated the MapProbe generated test to bind side-effectful method results
  before assertion, avoiding Dargo repeated-evaluation behavior for direct
  calls inside `assert_eq`.
- Extended the MapProbe smoke to execute the new methods and validate artifact
  metadata against all returned results.

Validation run:

```sh
lake build
lake env proof-forge --emit-map-ir-psy -o build/psy/MapProbe.psy
diff -u Examples/Psy/MapProbe.golden.psy build/psy/MapProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/map-smoke.sh
```

Result:

- `set_return_lifecycle` returns `result_vm: [31, 32, 33, 34]`.
- `insert_return_lifecycle` returns `result_vm: [5, 6, 7, 8]`.

Known limitations:

- Psy map support remains deliberately limited to `Map<Hash, Hash, N>` until
  non-Hash map value semantics are modeled explicitly in the portable IR.

Next step:

- Continue converting upstream Psy map/storage semantics into fixture-backed
  ProofForge IR coverage.

### Psy Generic Test Fallback

Commit: feature commit for generic Psy fallback tests

Summary:

- Replaced the Psy backend's fixture-only test generation failure with a
  generic fallback test that instantiates `<Module>Ref`.
- Added `GenericEntrypointProbe` as a valid non-whitelisted portable IR fixture
  to prove that arbitrary supported modules can render `.psy` source.
- Added a Dargo-backed smoke script, golden source, CI golden check, deploy
  manifest generation, and artifact metadata validation for the new fixture.
- Added an explicit empty-state diagnostic because Dargo v0.1.0 rejects empty
  `#[derive(Storage)]` contracts.

Validation run:

```sh
lake build
bash -n scripts/psy/*.sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake env proof-forge --emit-generic-entrypoint-ir-psy -o build/psy/GenericEntrypointProbe.psy
diff -u Examples/Psy/GenericEntrypointProbe.golden.psy build/psy/GenericEntrypointProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/generic-entrypoint-smoke.sh
git diff --check
```

Result:

- Dargo accepts the generic generated test and executes
  `GenericEntrypointProbe.answer` with `result_vm: [42]`.
- Psy diagnostic smoke now covers 49 malformed or unsupported IR cases.

Known limitations:

- The generic fallback only proves source/package validity and ref
  instantiation. Fixture-specific behavior still needs dedicated assertions
  and smoke scripts when a feature has semantic expectations.

Next step:

- Continue closing expression and storage coverage gaps with one fixture-backed
  feature at a time.

### Psy Identifier Diagnostics

Commit: feature commit for Psy identifier validation

Summary:

- Added Psy backend validation for module, struct, field, state, entrypoint,
  parameter, local, and loop-index identifiers before source generation.
- Added duplicate declaration checks for struct names, state ids, entrypoint
  names, struct field ids, and entrypoint parameter names.
- Added diagnostic fixtures for invalid module identifiers, duplicate state
  ids, duplicate entrypoint names, and reserved local names.

Validation run:

```sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake build
git diff --check
```

Result:

- Psy diagnostic smoke now covers 48 malformed or unsupported IR cases.
- Invalid or ambiguous names fail in ProofForge before Dargo parsing or
  typechecking.

Known limitations:

- The reserved-word list covers Psy keywords and builtin names used by current
  generated source. If Psy adds new reserved identifiers upstream, this list
  should be updated with the toolchain bump.

Next step:

- Continue reducing Dargo-discovered failures into ProofForge diagnostics.

### Psy U32 Scalar Storage Coverage

Commit: feature commit for Psy U32 scalar storage coverage

Summary:

- Added `U32StorageScalarProbe` as a portable IR fixture for native Psy
  `u32` scalar storage.
- Added CLI emission through `--emit-u32-storage-scalar-ir-psy` plus a checked
  golden source fixture.
- Added `scripts/psy/u32-storage-scalar-smoke.sh` to validate `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  generation, and artifact metadata validation.
- Extended Psy coverage evidence, validation docs, and CI golden checks.

Validation run:

```sh
DARGO_STD_PATH=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/lib/psy-std/std.psy \
  /tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  test --file /tmp/proof_forge_probe/u32_scalar_storage.psy
lake build
bash -n scripts/psy/*.sh
lake env proof-forge --emit-u32-storage-scalar-ir-psy -o build/psy/U32StorageScalarProbe.psy
diff -u Examples/Psy/U32StorageScalarProbe.golden.psy build/psy/U32StorageScalarProbe.psy
scripts/psy/check-ir-coverage-manifest.py
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-storage-scalar-smoke.sh
git diff --check
```

Result:

- Generated U32StorageScalarProbe source lowers scalar storage to
  `pub value: u32`, native U32 reads/writes, and scalar `+=`.
- Dargo execution validates `result_vm: [12]`.

Known limitations:

- This covers native scalar `u32` storage only. U32 storage arrays still use the
  existing Felt-backed representation because current `psyup` 0.1.0 rejects
  direct `[u32; N]` contract storage arrays.

Next step:

- Continue broadening Psy storage and ABI validation while keeping unsupported
  storage forms explicit.

### Psy Entrypoint Selector Diagnostic

Commit: feature commit for Psy selector rejection

Summary:

- Added a Psy backend validation rule that rejects `Entrypoint.selector?`
  before source generation.
- Documented that Psy/DPN entrypoints are addressed by contract method name via
  Dargo and the generated Psy ABI, so EVM-style selectors are target-invalid
  rather than ignored.
- Added a `Tests/PsyDiagnostics.lean` case to lock the diagnostic text.

Validation run:

```sh
scripts/psy/diagnostic-smoke.sh
scripts/psy/check-ir-coverage-manifest.py
lake build
git diff --check
```

Result:

- Malformed Psy IR modules with entrypoint selectors now fail with an explicit
  diagnostic instead of silently dropping selector metadata.

Known limitations:

- This does not add a Psy-native selector concept. If Psy later exposes stable
  selector metadata, the backend should model it separately from EVM selectors.

Next step:

- Continue expanding non-fixture-specific Psy package generation and deployment
  validation.

### Psy Shared Dargo Package Writer

Commit: feature commit for shared Psy Dargo package generation

Summary:

- Added `scripts/psy/write-dargo-package.py` as the shared package writer for
  Dargo-backed Psy smoke fixtures.
- Replaced repeated shell `rm`/`mkdir`/`cp`/`Dargo.toml` heredocs across all
  Dargo-backed smoke scripts with a single writer invocation.
- Kept a smoke-directory guard in the writer so it only rewrites `dargo-*`
  package directories.

Validation run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile \
  scripts/psy/write-dargo-package.py \
  scripts/psy/write-artifact-metadata.py \
  scripts/psy/validate-artifact-metadata.py \
  scripts/psy/check-ir-coverage-manifest.py
bash -n scripts/psy/*.sh
scripts/psy/check-ir-coverage-manifest.py
lake build
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/counter-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-storage-array-smoke.sh
```

Result:

- Both representative Dargo smokes generate packages through the shared writer,
  then pass `dargo test`, `dargo compile`, `dargo execute`, `dargo generate-abi`,
  deploy-manifest validation, and artifact metadata validation.
- Existing metadata source/package-source parity and `Dargo.toml` manifest
  validation continue to pass.

Known limitations:

- This factors local Dargo package creation only; upstream compressed genesis
  deploy JSON and live node/prover smoke remain separate deployment work.

Next step:

- Continue toward upstream genesis deploy JSON/local node research.

### Psy Dargo Package Source Metadata

Commit: feature commit for Psy Dargo package source metadata

Summary:

- Extended Psy artifact metadata to record the Dargo package source copy
  (`src/main.psy`) used by every Dargo-backed smoke fixture.
- Updated metadata validation to check the package source path, byte size,
  SHA-256 hash, and hash parity with the generated `.psy` source.
- Updated all Dargo-backed Psy smoke scripts to pass
  `"$PROJECT_DIR/src/main.psy"` into `write-artifact-metadata.py`.

Validation run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile \
  scripts/psy/write-artifact-metadata.py \
  scripts/psy/validate-artifact-metadata.py \
  scripts/psy/check-ir-coverage-manifest.py
bash -n scripts/psy/*.sh
lake build
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/counter-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-storage-array-smoke.sh
```

Result:

- Counter and U32StorageArrayProbe smoke metadata now include
  `artifacts.packageSource`.
- The metadata validator accepts the updated schema and proves the package
  source copy has the same SHA-256 hash as the generated source file.

Known limitations:

- This validates the generated Dargo package source copy, not upstream
  compressed genesis deploy JSON or live node/prover state.

Next step:

- Continue toward upstream genesis deploy JSON/local node research, or factor
  the repeated Dargo package generation into a reusable package writer.

### Psy Dargo Package Manifest Metadata

Commit: feature commit for Psy Dargo package manifest metadata

Summary:

- Extended Psy artifact metadata to record the generated Dargo package manifest
  (`Dargo.toml`) for every Dargo-backed smoke fixture.
- Updated metadata validation to check the manifest path, byte size, SHA-256
  hash, `[package]` section, `type = "bin"`, and `[dependencies]` section.
- Updated all Dargo-backed Psy smoke scripts to pass the generated
  `"$PROJECT_DIR/Dargo.toml"` into `write-artifact-metadata.py`.

Validation run:

```sh
python3 -m py_compile \
  scripts/psy/write-artifact-metadata.py \
  scripts/psy/validate-artifact-metadata.py
bash -n scripts/psy/*.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/counter-smoke.sh
```

Result:

- Counter smoke metadata now includes `artifacts.dargoManifest` with a checked
  hash and package manifest shape.
- The metadata validator accepts the updated schema after Dargo `test`,
  `compile`, `execute`, `generate-abi`, deploy manifest validation, and package
  manifest validation.

Known limitations:

- This records the generated Dargo package manifest, not Psy upstream compressed
  genesis deploy JSON or live node/prover state.

Next step:

- Continue toward upstream genesis deploy JSON/local node research, or factor
  the repeated Dargo package generation into a reusable package writer.

### Psy IR Coverage Manifest Gate

Commit: feature commit for Psy IR coverage manifest validation

Summary:

- Added `Tests/PsyCoverage.tsv` as a constructor-level coverage manifest for
  the portable IR surface used by the Psy backend.
- Added `scripts/psy/check-ir-coverage-manifest.py`, which parses
  `ProofForge/IR/Contract.lean` and fails if any tracked constructor is missing
  from the manifest or if the manifest contains stale/duplicate entries.
- Added CI and validation docs for the new gate so future IR expansion must
  classify each constructor as lowered, validated, unsupported, or structural.

Validation run:

```sh
python3 -m py_compile scripts/psy/check-ir-coverage-manifest.py
scripts/psy/check-ir-coverage-manifest.py
```

Result:

- The checker reports 88 constructor entries matching
  `ProofForge/IR/Contract.lean`.

Known limitations:

- The manifest is a structural guard, not behavioral proof. Supported rows still
  require fixture, golden, Dargo, and metadata validation when they describe
  runtime behavior.

Next step:

- Continue closing behavioral Psy gaps and use the manifest as a tripwire when
  extending the portable IR.

### Psy U32 Storage Array Lowering

Commit: feature commit for Psy U32 storage array coverage

Summary:

- Added `U32StorageArrayProbe` as a dedicated portable IR fixture for U32
  storage-array reads and writes.
- Extended Psy sourcegen so portable U32 storage arrays lower to Felt-backed
  Psy storage arrays. Writes use `u32 as Felt`; reads use `.get() as u32`.
- Reused the same representation for generic storage-path read/write effects
  over U32 array elements.
- Kept U32 storage-path compound assignment explicitly rejected, because direct
  Felt storage `+=` would not preserve a clear U32 storage arithmetic boundary.
- Added CLI, golden source, CI golden coverage, diagnostic coverage, Dargo
  smoke coverage, and validation docs for the new fixture.

Validation run:

```sh
lake build
lake env proof-forge --emit-u32-storage-array-ir-psy -o build/psy/U32StorageArrayProbe.psy
diff -u Examples/Psy/U32StorageArrayProbe.golden.psy build/psy/U32StorageArrayProbe.psy
scripts/psy/diagnostic-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-storage-array-smoke.sh
```

Result:

- Generated U32StorageArrayProbe source matches the checked-in golden fixture.
- `scripts/psy/diagnostic-smoke.sh` passes all 43 diagnostic cases.
- `scripts/psy/u32-storage-array-smoke.sh` passes `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  validation, and artifact metadata validation.
- Dargo execution returns `result_vm: [48]` for `storage_lifecycle`.

Known limitations:

- Direct Psy `[u32; N]` contract storage arrays remain avoided because current
  `psyup` 0.1.0 rejects them with an `ArrayRef<u32, N>` mismatch.
- U32 storage-path compound assignment is still unsupported; use explicit
  read/update/write.

Next step:

- Move the Psy deployment track toward upstream compressed genesis deploy JSON
  and local node/prover smoke work, or continue broadening Lean-to-IR extraction
  into the now-supported Psy surface.

### Psy Storage Compound Assignment Effects

Commit: feature commit for Psy storage-reference compound assignment effects

Summary:

- Added portable IR storage effects for scalar storage compound assignment and
  generic storage-path compound assignment.
- Extended Psy sourcegen to lower storage refs such as `c.total += 3`,
  `c.person.profile.age += 2`, and `c.people[1].score -= 9` to native Psy
  assignment operators.
- Kept EVM IR v0 behavior explicit by rejecting the new storage compound
  effects with target-specific diagnostics.
- Extended `StorageNestedAggregateProbe` to validate scalar storage compound
  assignment, nested scalar storage paths, and storage-array scalar paths under
  Dargo execution.
- Added Psy diagnostics for storage compound effects used as expressions and
  malformed storage compound assignment value types.

Validation run:

```sh
lake build
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
diff -u Examples/Psy/StorageNestedAggregateProbe.golden.psy build/psy/StorageNestedAggregateProbe.psy
scripts/psy/diagnostic-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/storage-nested-aggregate-smoke.sh
```

Result:

- Generated StorageNestedAggregateProbe source matches the checked-in golden
  fixture.
- `scripts/psy/diagnostic-smoke.sh` passes all 42 diagnostic cases.
- `scripts/psy/storage-nested-aggregate-smoke.sh` passes `dargo test`,
  `dargo compile`, `dargo execute`, `dargo generate-abi`, deploy manifest
  validation, and artifact metadata validation.
- Dargo execution returns `result_vm: [229]` for `storage_nested_lifecycle`.

Known limitations:

- Map storage values remain excluded from compound assignment because the
  current supported map shape uses `get`/`set` over `Map<Hash, Hash, N>`.
- U32 storage arrays remain explicitly rejected until a stable Dargo-compatible
  storage idiom is identified.

Next step:

- Continue with U32 storage-array research or move toward upstream genesis
  deploy JSON/local node smoke work.

### Psy Compound Assignment Lowering

Commit: feature commit for Psy compound assignment lowering

Summary:

- Added first-class `AssignOp` and `Statement.assignOp` nodes to the portable
  IR for `+=`, `-=`, `*=`, `/=`, `%=`, `|=`, `&=`, `^=`, `<<=`, and `>>=`.
- Lowered compound assignments to native Psy assignment operators for mutable
  local, array-index, and field-path assignment targets.
- Kept EVM IR v0 explicit by rejecting compound assignment statements with a
  dedicated diagnostic.
- Extended `U32ArithmeticProbe` with arithmetic compound assignment coverage
  and `BitwiseProbe` with Felt/U32 bitwise and shift compound assignment
  coverage.
- Added Psy diagnostics for malformed compound assignment value types and
  immutable compound assignment targets.

Validation run:

```sh
lake build
lake env proof-forge --emit-u32-arithmetic-ir-psy -o build/psy/U32ArithmeticProbe.psy
diff -u Examples/Psy/U32ArithmeticProbe.golden.psy build/psy/U32ArithmeticProbe.psy
lake env proof-forge --emit-bitwise-ir-psy -o build/psy/BitwiseProbe.psy
diff -u Examples/Psy/BitwiseProbe.golden.psy build/psy/BitwiseProbe.psy
scripts/psy/diagnostic-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-arithmetic-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/bitwise-smoke.sh
```

Result:

- Generated U32ArithmeticProbe and BitwiseProbe sources match the checked-in
  golden fixtures.
- `scripts/psy/diagnostic-smoke.sh` passes all 39 diagnostic cases.
- Dargo validates the updated U32ArithmeticProbe and BitwiseProbe sources with
  `test`, `compile`, `execute`, `generate-abi`, deploy manifest validation, and
  artifact metadata validation.

Known limitations:

- Compound assignment currently targets mutable local/aggregate assignment
  paths. Storage-reference compound assignment remains a separate design item
  because portable storage writes are modeled as effects.
- U32 storage arrays remain explicitly rejected until a stable Dargo-compatible
  storage idiom is identified.

Next step:

- Continue with U32 storage-array research or add storage-reference compound
  assignment effects if that becomes the next Psy surface to close.

### Psy Map Storage Path Lowering

Commit: feature commit for Psy map storage path coverage

Summary:

- Added `StoragePathSegment.mapKey` to the portable IR so generic storage path
  effects can target supported `Map<Hash, Hash, N>` state.
- Extended Psy storage path type resolution, validation, and source lowering so
  `storagePathRead "balances" #[.mapKey key]` lowers to `c.balances.get(key)`
  and `storagePathWrite "balances" #[.mapKey key] value` lowers to
  `c.balances.set(key, value)`.
- Added map path key validation and explicit diagnostics for malformed map
  paths or wrong key types.
- Extended `MapProbe` with `path_lifecycle`, updated its golden `.psy`, and
  updated `scripts/psy/map-smoke.sh` to execute both direct map effects and the
  generic map storage path entrypoint.

Validation run:

```sh
lake build
lake env proof-forge --emit-map-ir-psy -o build/psy/MapProbe.psy
diff -u Examples/Psy/MapProbe.golden.psy build/psy/MapProbe.psy
scripts/psy/diagnostic-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/map-smoke.sh
```

Result:

- Generated MapProbe source matches the checked-in golden fixture.
- `scripts/psy/diagnostic-smoke.sh` passes all 37 diagnostic cases.
- `scripts/psy/map-smoke.sh` passes `dargo test`, `dargo compile`,
  `dargo execute`, `dargo generate-abi`, deploy manifest validation, and
  artifact metadata validation.
- Dargo execution returns `result_vm: [55, 66, 77, 88]` for `map_lifecycle`
  and `result_vm: [77, 88, 99, 111]` for `path_lifecycle`.

Known limitations:

- Map storage paths currently support direct `Map<Hash, Hash, N>` key access.
  Nested map value traversal remains unsupported because Psy IR v0 only accepts
  Hash map values.
- U32 storage arrays remain explicitly rejected until a stable Dargo-compatible
  storage idiom is identified.

Next step:

- Continue with U32 storage-array research or decide whether compound
  assignment should become IR sugar.

### Psy Deploy Manifests For All Dargo Smokes

Commit: feature commit for broad Psy deploy manifest coverage

Summary:

- Added `scripts/psy/write-smoke-deploy-manifest.sh` as the shared smoke helper
  for deploy manifest generation and validation.
- Updated every Dargo-backed Psy smoke script to write
  `target/proof-forge-deploy.json`, validate it, and record it as `deployJson`
  inside `target/proof-forge-artifact.json`.
- Restored each smoke's deploy-oriented `dargo compile` artifact after
  `dargo execute` and `dargo generate-abi`, so deploy manifests describe the
  compile method set rather than an execution trace.
- Kept `scripts/psy/diagnostic-smoke.sh` separate because it validates
  pre-codegen diagnostics and does not produce Dargo artifacts.
- Updated validation docs, target notes, and backlog so the remaining deployment
  gap is specifically upstream compressed genesis deploy JSON plus local
  node/prover execution.

Validation run:

```sh
python3 -m py_compile \
  scripts/psy/write-deploy-manifest.py \
  scripts/psy/validate-deploy-manifest.py \
  scripts/psy/write-artifact-metadata.py \
  scripts/psy/validate-artifact-metadata.py
git diff --check
lake build
export PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy
export DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo
for script in scripts/psy/*-smoke.sh; do
  case "$script" in
    scripts/psy/diagnostic-smoke.sh) ;;
    *) "$script" ;;
  esac
done
scripts/psy/diagnostic-smoke.sh
```

Result:

- All Dargo-backed Psy smokes generated DPN circuit JSON, ABI JSON, execute
  logs, `proof-forge-deploy.json`, and `proof-forge-artifact.json`.
- Artifact metadata validation now checks deploy-manifest file hashes whenever
  `deployJson` is present.
- Deploy manifests record the restored compile method set for each fixture.
- `scripts/psy/diagnostic-smoke.sh` still passes all 35 diagnostic cases.

Known limitations:

- `proof-forge-deploy.json` remains ProofForge-owned metadata, not the upstream
  compressed genesis deploy JSON consumed by Psy node setup.
- The local node/prover deployment smoke is still not implemented.

Next step:

- Research whether to vendor or wrap Psy's `gen_deploy_json` path, then add the
  smallest local node/prover smoke that consumes the resulting deployment
  package.

### Psy Counter Deploy Manifest Metadata

Commit: feature commit for Psy Counter deploy manifest coverage

Summary:

- Added `scripts/psy/write-deploy-manifest.py` to produce
  `proof-forge-deploy.json` from the Counter `.psy` source, Dargo circuit JSON,
  and Dargo ABI JSON.
- Added `scripts/psy/validate-deploy-manifest.py` to verify manifest schema,
  deployer format, state-tree height, source/circuit/ABI hashes, function
  whitelist ordering, and upstream genesis JSON status.
- Updated `scripts/psy/counter-smoke.sh` so the Counter Dargo smoke now writes
  and validates `target/proof-forge-deploy.json`.
- Re-runs `dargo compile` after `dargo execute` so deploy metadata points at
  the deploy-oriented compile artifact rather than the method-sequence
  execution trace.
- Extended Psy artifact metadata to optionally record `deployJson` and require
  `validation.deployManifest = "passed"` whenever that artifact is present.
- Documented that this is a ProofForge deploy manifest, not Psy's upstream
  compressed genesis deploy JSON from `gen_deploy_json`.

Validation run:

```sh
python3 -m py_compile \
  scripts/psy/write-deploy-manifest.py \
  scripts/psy/validate-deploy-manifest.py \
  scripts/psy/write-artifact-metadata.py \
  scripts/psy/validate-artifact-metadata.py
git diff --check
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/counter-smoke.sh
```

Result:

- Counter generated source still matches `Examples/Psy/Counter.golden.psy`.
- Dargo `test`, `compile`, `execute`, and `generate-abi` passed.
- `dargo execute` returned `result_vm: [2]` after initialize plus two
  increments.
- `proof-forge-deploy.json` and `proof-forge-artifact.json` were generated and
  validated.

Known limitations:

- The manifest is ProofForge-owned metadata, not the upstream compressed
  genesis deploy JSON consumed by Psy node setup.
- The upstream `psy-dargo-cli/examples/gen_deploy_json.rs` path still requires
  Rust workspace internals; current released `dargo` does not expose it as a
  subcommand.
- Only the Counter smoke emits deploy manifest metadata so far.

Next step:

- Either extend deploy manifest generation to the broader Psy fixture set, or
  research the smallest stable upstream boundary for genesis deploy JSON plus a
  local Psy node/prover smoke.

### Psy U32HashPackingProbe Dynamic Hash Construction

Commit: feature commit for Psy U32 hash packing coverage

Summary:

- Added portable IR `Expr.hashValue` for dynamic `Hash` construction from four
  Felt-backed limbs.
- Extended Psy type validation so each dynamic Hash part must be `U64`/Felt and
  malformed Hash construction fails before `.psy` generation.
- Kept EVM IR v0 explicit by rejecting dynamic Hash value construction with a
  clear diagnostic.
- Added `ProofForge.IR.Examples.U32HashPackingProbe`, aligned with the
  `[u32; 8]` limb packing idioms in the deposit-tree and mining-rewards
  precompiles.
- Covered both local `[u32; 8]` literals and U32 ABI parameters packed into Psy
  `Hash` values through `lo + hi * 2^32`.
- Added an explicit rejection diagnostic for U32 storage arrays after Dargo
  validation showed current `psyup` 0.1.0 rejects direct `[u32; N]` contract
  storage arrays with an `ArrayRef<u32, N>` type mismatch.
- Added CLI support:

```sh
lake env proof-forge --emit-u32-hash-packing-ir-psy -o build/psy/U32HashPackingProbe.psy
```

- Added `Examples/Psy/U32HashPackingProbe.golden.psy`.
- Added `scripts/psy/u32-hash-packing-smoke.sh`, which generates a temporary
  Dargo package, runs `dargo test --file`, `dargo compile`, two
  `dargo execute` checks, `dargo generate-abi`, and validates
  `proof-forge-artifact.json`.
- Added CI coverage for the U32HashPackingProbe Psy golden source snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-u32-hash-packing-ir-psy -o build/psy/U32HashPackingProbe.psy
diff -u Examples/Psy/U32HashPackingProbe.golden.psy build/psy/U32HashPackingProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-hash-packing-smoke.sh
```

Result:

- Generated U32HashPackingProbe source matches the checked-in golden fixture.
- `scripts/psy/u32-hash-packing-smoke.sh` generated DPN JSON, ABI JSON,
  execute log, and `proof-forge-artifact.json`.
- `dargo execute` returned the expected four-Felt Hash values for both
  `pack_literal` and `pack_params`.
- `scripts/psy/diagnostic-smoke.sh` passed all 35 diagnostic cases.

Known limitations:

- This adds Hash value construction and U32 limb packing, not Psy deploy JSON
  or live node/prover execution.
- U32 storage arrays are explicitly rejected until a stable Psy storage idiom is
  validated against Dargo.
- Compound assignment operators remain represented as explicit assignment plus
  expression nodes.
- Map storage paths remain rejected until a stable Psy idiom is identified.

Next step:

- Decide whether to add compound assignment as IR sugar or leave it to a future
  source normalizer, then continue with map storage paths or deploy JSON.

### Psy BitwiseProbe Native Bitwise Expressions

Commit: feature commit for Psy bitwise expression coverage

Summary:

- Added portable IR expression nodes for `&`, `|`, `^`, `<<`, and `>>`.
- Extended Psy source generation for Felt-backed `U64` and `U32` bitwise
  expressions, with same-width numeric validation before `.psy` generation.
- Added EVM IR lowering for the same pure bitwise/shift nodes through Yul
  `and`, `or`, `xor`, `shl`, and `shr` builtins.
- Added explicit diagnostics for malformed bitwise and shift operands.
- Added `ProofForge.IR.Examples.BitwiseProbe`, aligned with upstream
  `psy-compiler/tests/opcode_test.psy`,
  `tests/storage_u32_assign_ops_test.psy`, and precompile Merkle path idioms.
- Added CLI support:

```sh
lake env proof-forge --emit-bitwise-ir-psy -o build/psy/BitwiseProbe.psy
```

- Added `Examples/Psy/BitwiseProbe.golden.psy`.
- Added `scripts/psy/bitwise-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the BitwiseProbe Psy golden source snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-bitwise-ir-psy -o build/psy/BitwiseProbe.psy
diff -u Examples/Psy/BitwiseProbe.golden.psy build/psy/BitwiseProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/bitwise-smoke.sh
```

Result:

- Generated BitwiseProbe source matches the checked-in golden fixture.
- `scripts/psy/bitwise-smoke.sh` generated DPN JSON, ABI JSON, execute log,
  and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [16]` for `bitwise_mix`.
- `scripts/psy/diagnostic-smoke.sh` passed all 33 diagnostic cases.

Known limitations:

- Compound assignment operators such as `|=`, `&=`, `^=`, `<<=`, and `>>=`
  are still represented as explicit assignment plus expression nodes.
- This does not yet add u32 storage arithmetic probes or map storage paths.

Next step:

- Add storage-heavy U32/Hash limb packing probes from the deposit-tree and
  mining-rewards precompiles, then decide whether compound assignment sugar
  belongs in the portable IR or only in sourcegen normalization.

### Psy U32ArithmeticProbe Native U32 Arithmetic

Commit: feature commit for Psy U32 arithmetic coverage

Summary:

- Added portable IR `ValueType.u32` and `Literal.u32`.
- Added portable IR expression nodes for division, modulo, exponentiation, and
  explicit casts.
- Extended Psy source generation for `u32`, `Nu32` literals, `/`, `%`, `**`,
  and casts such as `z as bool` and `bb as Felt`.
- Updated bounded-loop typing so generated `for i in 0u32..Nu32` loop indices
  are tracked as `U32`.
- Extended numeric type validation so `U32` arithmetic remains type-consistent
  and malformed mixed-width arithmetic fails before source generation.
- Added EVM IR lowering for the new pure arithmetic/cast nodes through Yul
  builtins or no-op casts.
- Added `ProofForge.IR.Examples.U32ArithmeticProbe`, mirroring the core
  executable shape of upstream `psy-compiler/tests/u32_test.psy`.
- Added CLI support:

```sh
lake env proof-forge --emit-u32-arithmetic-ir-psy -o build/psy/U32ArithmeticProbe.psy
```

- Added `Examples/Psy/U32ArithmeticProbe.golden.psy`.
- Added `scripts/psy/u32-arithmetic-smoke.sh`, which generates a temporary
  Dargo package, runs `dargo test --file`, `dargo compile`, `dargo execute
  --parameters 2,3`, `dargo generate-abi`, and validates
  `proof-forge-artifact.json`.
- Added CI coverage for the U32ArithmeticProbe Psy golden source snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-u32-arithmetic-ir-psy -o build/psy/U32ArithmeticProbe.psy
diff -u Examples/Psy/U32ArithmeticProbe.golden.psy build/psy/U32ArithmeticProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/u32-arithmetic-smoke.sh
```

Result:

- Generated U32ArithmeticProbe source matches the checked-in golden fixture.
- `scripts/psy/u32-arithmetic-smoke.sh` generated DPN JSON, ABI JSON, execute
  log, and `proof-forge-artifact.json`.
- `dargo execute --parameters 2,3` returned `result_vm: [1]` for
  `u32_arithmetic`.
- `scripts/psy/diagnostic-smoke.sh` passed all 31 diagnostic cases.

Known limitations:

- This does not yet add bitwise shifts, bitwise and/or, u32 storage probes, or
  the full cast matrix used by the token/deposit-tree precompiles.
- Cast lowering is intentionally explicit and rejects unsupported source/target
  pairs before `.psy` source generation.

Next step:

- Add bitwise operations and u32 array/hash-packing probes, since the Psy
  precompiles use `u32` limbs heavily for token addresses and tree roots.

### Psy ArithmeticProbe Sub/Mul Expressions

Commit: feature commit for Psy arithmetic expression coverage

Summary:

- Added portable IR expression nodes for subtraction and multiplication.
- Added Psy source generation for `-` and `*`, including parentheses around
  nested arithmetic operands where precedence would otherwise change meaning.
- Added sourcegen diagnostics for malformed subtraction and multiplication
  operand types.
- Added EVM IR lowering for the same pure arithmetic nodes through Yul builtins.
- Added `ProofForge.IR.Examples.ArithmeticProbe`, covering subtraction,
  multiplication, and nested arithmetic precedence.
- Added CLI support:

```sh
lake env proof-forge --emit-arithmetic-ir-psy -o build/psy/ArithmeticProbe.psy
```

- Added `Examples/Psy/ArithmeticProbe.golden.psy`.
- Added `scripts/psy/arithmetic-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the ArithmeticProbe Psy golden source snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-arithmetic-ir-psy -o build/psy/ArithmeticProbe.psy
diff -u Examples/Psy/ArithmeticProbe.golden.psy build/psy/ArithmeticProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/arithmetic-smoke.sh
```

Result:

- Generated ArithmeticProbe source matches the checked-in golden fixture.
- `scripts/psy/arithmetic-smoke.sh` generated DPN JSON, ABI JSON, execute log,
  and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [60]` for `arithmetic_mix`.
- `scripts/psy/diagnostic-smoke.sh` passed all 29 diagnostic cases.

Known limitations:

- This adds subtraction and multiplication, not division, modulo,
  exponentiation, cast-heavy `u32` arithmetic, or compound assignment operators.
- The IR still represents these values as `U64` mapped to Psy `Felt`; a
  dedicated `U32` surface should be added before copying upstream `u32_test`
  semantics directly.

Next step:

- Add division/modulo only after deciding whether they belong to Felt-backed
  `U64`, a new `U32` value type, or target-specific checked arithmetic helpers.

### Psy ConditionalProbe Statement If/Else

Commit: feature commit for Psy conditional statement coverage

Summary:

- Added portable IR `Statement.ifElse` with a new `control.conditional`
  capability.
- Added Psy source generation for `if condition { ... } else { ... };`, aligned
  with upstream `.psy` conditional syntax.
- Added sourcegen diagnostics for non-Bool if conditions and branch-local
  bindings escaping their branch.
- Kept EVM IR v0 explicit by rejecting statement-level if/else.
- Added `ProofForge.IR.Examples.ConditionalProbe`, covering then and else branch
  execution over scalar storage.
- Added CLI support:

```sh
lake env proof-forge --emit-conditional-ir-psy -o build/psy/ConditionalProbe.psy
```

- Added `Examples/Psy/ConditionalProbe.golden.psy`.
- Added `scripts/psy/conditional-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the ConditionalProbe Psy golden source snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-conditional-ir-psy -o build/psy/ConditionalProbe.psy
diff -u Examples/Psy/ConditionalProbe.golden.psy build/psy/ConditionalProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/conditional-smoke.sh
```

Result:

- Generated ConditionalProbe source matches the checked-in golden fixture.
- `scripts/psy/conditional-smoke.sh` generated DPN JSON, ABI JSON, execute log,
  and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [10]` for `conditional_lifecycle`.
- `scripts/psy/diagnostic-smoke.sh` passed all 27 diagnostic cases.

Known limitations:

- This adds statement-level if/else, not else-if syntax sugar.
- Non-unit entrypoints still need an explicit final top-level return statement;
  return coverage through both conditional branches is not analyzed yet.

Next step:

- Continue broadening Psy expression/arithmetic coverage or add map storage path
  support once a stable upstream Psy idiom is identified.

### Psy ExpressionPredicateProbe Boolean Predicates

Commit: feature commit for Psy predicate expression coverage

Summary:

- Added portable IR expression nodes for equality, inequality, ordering
  comparisons, boolean conjunction, boolean disjunction, and boolean negation.
- Added Psy lowering using upstream `.psy` idioms: `==`, `!=`, `<`, `<=`, `>`,
  `>=`, `&&`, `||`, and `!`.
- Added sourcegen type diagnostics for malformed equality, comparison, and
  boolean operator operands.
- Added EVM IR lowering for the same pure predicate nodes through Yul builtins.
- Added `ProofForge.IR.Examples.ExpressionPredicateProbe`, covering predicate
  locals and assertion predicates.
- Added CLI support:

```sh
lake env proof-forge --emit-expression-predicate-ir-psy -o build/psy/ExpressionPredicateProbe.psy
```

- Added `Examples/Psy/ExpressionPredicateProbe.golden.psy`.
- Added `scripts/psy/expression-predicate-smoke.sh`, which generates a
  temporary Dargo package, runs `dargo test --file`, `dargo compile`,
  `dargo execute`, `dargo generate-abi`, and validates
  `proof-forge-artifact.json`.
- Added CI coverage for the ExpressionPredicateProbe Psy golden source
  snapshot.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-expression-predicate-ir-psy -o build/psy/ExpressionPredicateProbe.psy
diff -u Examples/Psy/ExpressionPredicateProbe.golden.psy build/psy/ExpressionPredicateProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/expression-predicate-smoke.sh
```

Result:

- Generated ExpressionPredicateProbe source matches the checked-in golden
  fixture.
- `scripts/psy/expression-predicate-smoke.sh` generated DPN JSON, ABI JSON,
  execute log, and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [16]` for `predicate_sum`.
- `scripts/psy/diagnostic-smoke.sh` passed all 25 diagnostic cases.

Known limitations:

- This adds expression predicates, not statement-level `if/else` lowering.
- Fixed-array equality was outside this original expression fixture; it is now
  covered separately by the Dargo-backed `ArrayProbe`.

Next step:

- Add statement-level conditional lowering or broaden arithmetic expression
  coverage with upstream/Dargo fixtures.

### Psy Sourcegen Type Diagnostics

Commit: feature commit for Psy expression and statement type diagnostics

Summary:

- Added a lightweight Psy backend type environment for entrypoint parameters,
  local bindings, mutable locals, and bounded-loop indices.
- Added sourcegen-time type inference and validation for literals, locals,
  fixed arrays, struct literals, field access, addition, hash operations,
  storage effects, context reads, assignment targets, assertions, and returns.
- Added diagnostics for unknown locals, local/array/struct/hash type
  mismatches, immutable assignment, missing non-unit returns, and storage write
  type mismatches.
- Kept existing lowering behavior unchanged for valid fixtures; this feature
  blocks malformed IR before `.psy` source is emitted.
- Extended `Tests/PsyDiagnostics.lean` from 12 to 22 explicit rejection cases.

Validation run:

```sh
lake build
scripts/psy/diagnostic-smoke.sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
diff -u Examples/Psy/Counter.golden.psy build/psy/Counter.psy
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
diff -u Examples/Psy/StorageNestedAggregateProbe.golden.psy build/psy/StorageNestedAggregateProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/{counter,context,hash,map,assert,loop,array,struct,struct-array,abi-aggregate,nested-aggregate,storage-nested-aggregate}-smoke.sh
```

Result:

- `scripts/psy/diagnostic-smoke.sh` passed all 22 diagnostic cases.
- All checked Psy golden source snapshots remain unchanged.
- All Psy Dargo smokes passed and revalidated source snapshots, DPN JSON, ABI
  JSON, execute logs, and `proof-forge-artifact.json`.

Known limitations:

- This is a sourcegen validation layer, not a formal type system for every
  future portable IR extension.
- Assignment mutability is enforced for local/index/field paths rooted in local
  bindings; storage mutation continues to use explicit storage effects.

Next step:

- Continue closing Psy valid-surface gaps with either Dargo-backed fixtures or
  explicit diagnostics before adding new IR nodes.

### Psy StorageNestedAggregateProbe Storage Paths

Commit: feature commit for storage nested aggregate Psy IR coverage

Summary:

- Added generic storage path read/write effects to the portable IR.
- Added `StructField.isRef` so the IR can explicitly model Psy `#[ref]`
  fields for nested storage references.
- Added Psy lowering for storage paths such as `c.person.profile.age` and
  `c.people[1].profile.age`, plus validation for empty paths and missing
  nested `#[ref]` markers.
- Kept EVM IR v0 behavior explicit by rejecting storage path effects.
- Added `ProofForge.IR.Examples.StorageNestedAggregateProbe`, covering scalar
  struct storage and fixed storage arrays of structs.
- Added CLI support:

```sh
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
```

- Added `Examples/Psy/StorageNestedAggregateProbe.golden.psy`.
- Added `scripts/psy/storage-nested-aggregate-smoke.sh`, which generates a
  temporary Dargo package, runs `dargo test --file`, `dargo compile`,
  `dargo execute`, `dargo generate-abi`, and validates
  `proof-forge-artifact.json`.
- Extended `Tests/PsyDiagnostics.lean` with invalid storage path cases.
- Added CI coverage for the StorageNestedAggregateProbe Psy golden source
  snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
diff -u Examples/Psy/StorageNestedAggregateProbe.golden.psy build/psy/StorageNestedAggregateProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/storage-nested-aggregate-smoke.sh
scripts/psy/diagnostic-smoke.sh
```

Result:

- Generated StorageNestedAggregateProbe source matches the checked-in golden
  fixture.
- `scripts/psy/storage-nested-aggregate-smoke.sh` generated DPN JSON, ABI JSON,
  execute log, and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [220]` for
  `storage_nested_lifecycle`.
- `scripts/psy/diagnostic-smoke.sh` passed all 12 diagnostic cases.

Known limitations:

- Storage path lowering intentionally rejects map storage paths until a stable
  Psy idiom is identified and covered by an upstream-style fixture.
- This does not yet produce deploy JSON or exercise a live Psy node/prover.

Next step:

- Research deploy JSON/live node execution for Psy artifacts, or continue
  expanding expression/path coverage behind diagnostic gates.

### Psy NestedAggregateProbe Mixed Aggregate Updates

Commit: feature commit for nested aggregate Psy IR coverage

Summary:

- Added portable IR statements for mutable local bindings and assignment.
- Added Psy lowering for `let mut` and nested assignment targets made from
  local names, array indexes, and field paths.
- Kept EVM IR v0 behavior explicit by rejecting mutable local bindings and
  assignment statements.
- Added `ProofForge.IR.Examples.NestedAggregateProbe`, covering a mutable
  `[Family; 2]` value whose `Family.children` field is `[Member; 2]`.
- Added CLI support:

```sh
lake env proof-forge --emit-nested-aggregate-ir-psy -o build/psy/NestedAggregateProbe.psy
```

- Added `Examples/Psy/NestedAggregateProbe.golden.psy`.
- Added `scripts/psy/nested-aggregate-smoke.sh`, which generates a temporary
  Dargo package, runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Extended `Tests/PsyDiagnostics.lean` with an invalid assignment target case.
- Added CI coverage for the NestedAggregateProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-nested-aggregate-ir-psy -o build/psy/NestedAggregateProbe.psy
diff -u Examples/Psy/NestedAggregateProbe.golden.psy build/psy/NestedAggregateProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/nested-aggregate-smoke.sh
scripts/psy/diagnostic-smoke.sh
```

Result:

- `lake build` passed.
- Generated NestedAggregateProbe source matches the checked-in golden fixture.
- `scripts/psy/nested-aggregate-smoke.sh` generated DPN JSON, ABI JSON,
  execute log, and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [51]` for `nested_update_sum`.
- `scripts/psy/diagnostic-smoke.sh` passed all 10 diagnostic cases.

Known limitations:

- This feature covers local nested aggregate mutation, not storage-backed
  nested aggregate mutation.
- Assignment targets are intentionally limited to local/index/field paths.

Next step:

- Add storage-backed nested aggregate updates or deploy JSON metadata.

### Psy Unsupported Diagnostic Gate

Commit: feature commit for Psy diagnostic regression coverage

Summary:

- Added `Tests/PsyDiagnostics.lean`, a runnable Lean diagnostic regression
  suite for Psy IR rejection paths.
- Added `scripts/psy/diagnostic-smoke.sh`.
- Covered explicit diagnostics for:
  - Unit entrypoint parameters
  - zero-length ABI fixed arrays
  - unknown ABI struct types
  - unsupported map key/value shapes
  - structs used in storage without `deriveStorage`
  - empty struct declarations
  - invalid bounded loop ranges
  - storage writes used as expressions
  - storage reads used as statements
  - invalid assignment targets
- Added the diagnostic smoke to CI.
- Documented the gate in README, validation gates, and `psy-dpn` target notes.

Validation run:

```sh
scripts/psy/diagnostic-smoke.sh
lake build
```

Result:

- `scripts/psy/diagnostic-smoke.sh` passed all 10 diagnostic cases.
- `lake build` passed.

Known limitations:

- This is a regression gate for representative unsupported shapes, not an
  exhaustive formal proof over every impossible IR construction.
- Cross-target capability rejection matrices still need broader coverage.

Next step:

- Expand diagnostics as new Psy IR nodes are added, then continue with deeper
  mixed aggregate update coverage or deploy JSON metadata.

### Psy AbiAggregateProbe ABI Aggregates

Commit: feature commit for ABI aggregate Psy IR coverage

Summary:

- Added entrypoint ABI type validation for Psy IR parameters and returns.
- Rejected Unit parameters before source generation, while keeping Unit returns
  valid for void methods.
- Validated entrypoint fixed-array ABI types as non-empty and struct ABI types
  as declared.
- Added `ProofForge.IR.Examples.AbiAggregateProbe`, covering a struct
  parameter, fixed-array parameter, and struct return value.
- Added CLI support:

```sh
lake env proof-forge --emit-abi-aggregate-ir-psy -o build/psy/AbiAggregateProbe.psy
```

- Added `Examples/Psy/AbiAggregateProbe.golden.psy`.
- Added `scripts/psy/abi-aggregate-smoke.sh`, which generates a temporary
  Dargo package, runs `dargo test --file`, `dargo compile`, three
  `dargo execute` calls, `dargo generate-abi`, and validates
  `proof-forge-artifact.json`.
- Added CI coverage for the AbiAggregateProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-abi-aggregate-ir-psy -o build/psy/AbiAggregateProbe.psy
diff -u Examples/Psy/AbiAggregateProbe.golden.psy build/psy/AbiAggregateProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/abi-aggregate-smoke.sh
```

Result:

- `lake build` passed.
- Generated AbiAggregateProbe source matches the checked-in golden fixture.
- `scripts/psy/abi-aggregate-smoke.sh` generated DPN JSON, ABI JSON, execute
  log, and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [15]` for `sum_pair`.
- `dargo execute` returned `result_vm: [6]` for `sum_array`.
- `dargo execute` returned `result_vm: [9, 4]` for `make_pair`.

Known limitations:

- Dargo CLI aggregate execution is flattened to Felt vectors.
- This feature validates flat struct and one-dimensional fixed-array ABI
  shapes, not deeply nested mixed aggregate ABI shapes.

Next step:

- Add deeper nested mixed aggregate update and ABI coverage from the upstream
  Psy syntax corpus, then continue toward deploy JSON metadata.

### Psy StructArrayProbe Struct Arrays

Commit: feature commit for struct-array Psy IR coverage

Summary:

- Extended portable IR storage effects with indexed storage array struct field
  read/write nodes.
- Extended Psy sourcegen to lower storage arrays of structs, whole struct array
  element writes, and indexed struct field reads through `.get()`.
- Extended Psy state validation so fixed storage arrays can use `deriveStorage`
  struct element types.
- Kept EVM IR v0 behavior explicit by rejecting storage array struct field
  effects.
- Added `ProofForge.IR.Examples.StructArrayProbe`, covering local `[Person; 2]`
  struct arrays plus fixed storage arrays of structs.
- Added CLI support:

```sh
lake env proof-forge --emit-struct-array-ir-psy -o build/psy/StructArrayProbe.psy
```

- Added `Examples/Psy/StructArrayProbe.golden.psy`.
- Added `scripts/psy/struct-array-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, two `dargo execute`
  calls, `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the StructArrayProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-struct-array-ir-psy -o build/psy/StructArrayProbe.psy
diff -u Examples/Psy/StructArrayProbe.golden.psy build/psy/StructArrayProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/struct-array-smoke.sh
```

Result:

- `lake build` passed.
- Generated StructArrayProbe source matches the checked-in golden fixture.
- `scripts/psy/struct-array-smoke.sh` generated DPN JSON, ABI JSON, execute
  log, and `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [100]` for
  `local_struct_array_sum`.
- `dargo execute` returned `result_vm: [102]` for
  `storage_struct_array_lifecycle`.

Known limitations:

- This feature covers one-dimensional arrays of flat structs.
- Deeply nested mixed aggregate updates still need dedicated coverage.
- EVM IR v0 explicitly rejects struct-array storage field effects.

Next step:

- Add ABI-facing entrypoint aggregate parameters or return-shape validation,
  then continue toward deployment/deploy JSON metadata.

### Psy StructProbe Struct Values And Storage

Commit: feature commit for struct Psy IR coverage

Summary:

- Extended portable IR with struct declarations, struct value types, struct
  literals, and field access expressions.
- Registered `data.struct` as a target capability for struct values and field
  access.
- Extended portable IR storage effects with scalar storage struct field
  read/write nodes.
- Extended Psy sourcegen to emit `#[derive(Storage)]` struct declarations,
  `new Struct { ... }` literals, local field access, scalar storage struct
  assignment, and storage struct field reads through `.get()`.
- Kept EVM IR v0 behavior explicit by rejecting struct literals, field access,
  struct typed let bindings, struct returns, and storage struct field effects.
- Added `ProofForge.IR.Examples.StructProbe`, covering local struct literals
  plus scalar storage struct read/write behavior.
- Added CLI support:

```sh
lake env proof-forge --emit-struct-ir-psy -o build/psy/StructProbe.psy
```

- Added `Examples/Psy/StructProbe.golden.psy`.
- Added `scripts/psy/struct-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, two `dargo execute`
  calls, `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the StructProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-struct-ir-psy -o build/psy/StructProbe.psy
diff -u Examples/Psy/StructProbe.golden.psy build/psy/StructProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/struct-smoke.sh
```

Result:

- `lake build` passed.
- Generated StructProbe source matches the checked-in golden fixture.
- `scripts/psy/struct-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [30]` for `local_sum`.
- `dargo execute` returned `result_vm: [26]` for `storage_lifecycle`.

Known limitations:

- This feature covers flat struct values and scalar storage structs.
- Struct arrays, nested structs, and methods on structs still need dedicated
  coverage.
- EVM IR v0 explicitly rejects struct IR nodes.

Next step:

- Combine structs with fixed arrays in a follow-up fixture aligned with
  upstream `array_test.psy` and `array_ref_struct_index_test.psy`.

### Psy ArrayProbe Fixed Arrays

Commit: feature commit for fixed-array Psy IR coverage

Summary:

- Extended portable IR types with fixed arrays, represented as `[T; N]` in Psy.
- Added `data.fixed_array` for fixed-size array values and `storage.array` for
  fixed array storage fields.
- Extended portable IR expressions with fixed array literals and index reads.
- Extended portable IR storage effects with fixed array index read/write nodes.
- Extended Psy sourcegen to lower local array literals, index reads, storage
  array writes, and storage array reads through `.get()` when used as values.
- Kept EVM IR v0 behavior explicit by rejecting fixed-array literals, index
  access, storage array effects, and fixed-array returns.
- Added `ProofForge.IR.Examples.ArrayProbe`, covering local `[Felt; 3]`
  literals plus fixed storage array read/write behavior.
- Added CLI support:

```sh
lake env proof-forge --emit-array-ir-psy -o build/psy/ArrayProbe.psy
```

- Added `Examples/Psy/ArrayProbe.golden.psy`.
- Added `scripts/psy/array-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, three `dargo execute`
  calls, `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the ArrayProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-array-ir-psy -o build/psy/ArrayProbe.psy
diff -u Examples/Psy/ArrayProbe.golden.psy build/psy/ArrayProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/array-smoke.sh
```

Result:

- `lake build` passed.
- Generated ArrayProbe source matches the checked-in golden fixture.
- `scripts/psy/array-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [60]` for `sum_literal`.
- `dargo execute` returned `result_vm: [31]` for `storage_lifecycle`.
- `dargo execute` returned `result_vm: [1]` for `array_predicates`.

Known limitations:

- This feature covers one-dimensional fixed arrays over `Felt` and `Hash`
  storage elements. Struct arrays and nested arrays still need dedicated
  coverage.
- Dynamic arrays and unbounded indexing are still unsupported.
- EVM IR v0 explicitly rejects fixed-array IR nodes.

Next step:

- Add struct coverage next, then combine structs with arrays in a follow-up
  fixture aligned with upstream `array_test.psy`.

### Psy LoopProbe Bounded Loops

Commit: feature commit for bounded-loop Psy IR coverage

Summary:

- Extended portable IR statements with a static `boundedFor` node.
- Registered `control.bounded_loop` as a target capability and enabled it for
  `psy-dpn`.
- Extended Psy sourcegen to lower `boundedFor` to Psy fixed-range `for` loops
  such as `for _i in 0u32..3u32`.
- Kept EVM IR v0 behavior explicit by rejecting bounded loops with a diagnostic.
- Added `ProofForge.IR.Examples.LoopProbe`, which resets scalar storage, runs a
  three-iteration loop, and returns the final count.
- Added CLI support:

```sh
lake env proof-forge --emit-loop-ir-psy -o build/psy/LoopProbe.psy
```

- Added `Examples/Psy/LoopProbe.golden.psy`.
- Added `scripts/psy/loop-smoke.sh`, which generates a temporary Dargo package,
  runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the LoopProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-loop-ir-psy -o build/psy/LoopProbe.psy
diff -u Examples/Psy/LoopProbe.golden.psy build/psy/LoopProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/loop-smoke.sh
```

Result:

- `lake build` passed.
- Generated LoopProbe source matches the checked-in golden fixture.
- `scripts/psy/loop-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [3]` for `count_to_three`.

Known limitations:

- Loop lowering is deliberately static and bounded; dynamic or unbounded loops
  are still unsupported.
- The portable IR still lacks array and struct coverage.
- EVM IR v0 explicitly rejects bounded loops.

Next step:

- Add array coverage next, because upstream Psy tests and precompiles use
  fixed arrays heavily alongside bounded loops.

### Psy AssertProbe IR Assertions

Commit: pending

Summary:

- Extended portable IR with statement-level `assert` and `assertEq` nodes.
- Registered the `assertions` capability for target profiles and artifact
  metadata.
- Extended Psy sourcegen to lower assertion statements into method bodies as
  `assert(condition, "message")` and `assert_eq(lhs, rhs, "message")`.
- Added basic string escaping for generated Psy assertion messages.
- Added `ProofForge.IR.Examples.AssertProbe`, which validates assertions inside
  a contract method body.
- Added CLI support:

```sh
lake env proof-forge --emit-assert-ir-psy -o build/psy/AssertProbe.psy
```

- Added `Examples/Psy/AssertProbe.golden.psy`.
- Added `scripts/psy/assert-smoke.sh`, which generates a temporary Dargo
  package, runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the AssertProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-assert-ir-psy -o build/psy/AssertProbe.psy
diff -u Examples/Psy/AssertProbe.golden.psy build/psy/AssertProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/assert-smoke.sh
```

Result:

- `lake build` passed.
- Generated AssertProbe source matches the checked-in golden fixture.
- `scripts/psy/assert-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [12]` for `checked_sum(5,7)`.

Known limitations:

- Assertion conditions still depend on the currently narrow expression subset.
- EVM IR v0 rejects assertion statements through capability diagnostics.

Next step:

- Add bounded-loop coverage next, because loops are heavily used by Psy
  precompiles and are required for array/tree-style contracts.

### Psy MapProbe Storage Map Coverage

Commit: pending

Summary:

- Extended portable IR with fixed-capacity map state and `storage.map` effects:
  `contains`, `get`, `insert`, and `set`.
- Extended Psy sourcegen to lower the supported map shape to
  `Map<Hash, Hash, Nu32>` and to reject unsupported map key/value types with an
  explicit diagnostic.
- Added `ProofForge.IR.Examples.MapProbe` with scalar fields adjacent to the
  map to mirror upstream Psy storage-layout regression tests.
- Added CLI support:

```sh
lake env proof-forge --emit-map-ir-psy -o build/psy/MapProbe.psy
```

- Added `Examples/Psy/MapProbe.golden.psy`.
- Added `scripts/psy/map-smoke.sh`, which generates a temporary Dargo package,
  runs `dargo test --file`, `dargo compile`, `dargo execute`,
  `dargo generate-abi`, and validates `proof-forge-artifact.json`.
- Added CI coverage for the MapProbe Psy golden source snapshot.

Validation run:

```sh
lake build
lake env proof-forge --emit-map-ir-psy -o build/psy/MapProbe.psy
diff -u Examples/Psy/MapProbe.golden.psy build/psy/MapProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/map-smoke.sh
```

Result:

- `lake build` passed.
- Generated MapProbe source matches the checked-in golden fixture.
- `scripts/psy/map-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [55, 66, 77, 88]` for
  `map_lifecycle`.

Known limitations:

- Psy map lowering currently supports only `Map<Hash, Hash, N>`.
- The portable IR still lacks first-class assertions, bounded loops, arrays,
  and structs.
- EVM IR v0 explicitly rejects portable map storage.

Next step:

- Add IR-level assertions or bounded-loop coverage next, then validate the new
  node through Psy golden output and Dargo smoke.

### Psy HashProbe And Experimental Target Slice

Commit: pending

Summary:

- Extended portable IR with `Hash`, four-Felt hash literals, typed `let`
  bindings, `hash`, and `hash_two_to_one` expressions.
- Extended Psy sourcegen to lower hash values through upstream Psy idioms:
  `Hash`, `[a, b, c, d]`, `hash(data)`, and `hash_two_to_one(left, right)`.
- Added `ProofForge.IR.Examples.HashProbe` with two contract methods:
  `poseidon_hash` and `poseidon_pair_hash`.
- Added CLI support:

```sh
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
```

- Added `Examples/Psy/HashProbe.golden.psy`.
- Added `scripts/psy/hash-smoke.sh`, which generates a temporary Dargo package,
  runs `dargo test --file`, `dargo compile`, two `dargo execute` calls,
  `dargo generate-abi`, and writes `proof-forge-artifact.json`.
- Added `scripts/psy/validate-artifact-metadata.py`; the Counter, ContextProbe,
  and HashProbe smokes now validate artifact hashes, byte sizes, capability
  records, validation flags, and expected execution results.
- Added CI coverage for Psy golden source generation without requiring Dargo on
  GitHub Actions.

Validation run:

```sh
lake build
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
diff -u Examples/Psy/HashProbe.golden.psy build/psy/HashProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/counter-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/context-smoke.sh
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/hash-smoke.sh
```

Result:

- `lake build` passed.
- Generated HashProbe source matches the checked-in golden fixture.
- `scripts/psy/hash-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- All three Psy smoke scripts validated `proof-forge-artifact.json` against the
  generated files and expected execution output.
- `dargo execute` returned the expected four-Felt output for `poseidon_hash`.
- `dargo execute` returned the expected four-Felt output for
  `poseidon_pair_hash`.

Known limitations:

- Hash support is deliberately narrow: fixed four-Felt `Hash` values only.
- Psy storage maps, bounded loops, and deploy JSON are still not implemented.
- EVM IR v0 explicitly rejects Hash values and hash expressions.

Next step:

- Add map/storage-map coverage from upstream `psy-compiler/tests` and
  `psy-precompiles`, then factor the repeated Dargo package generation logic.

### Psy ContextProbe Fixture And Artifact Metadata

Commit: pending

Summary:

- Extended portable IR with `context.read` effects for `userId`, `contractId`,
  and `checkpointId`.
- Extended Psy sourcegen to lower entrypoint parameters and context reads.
- Added `ProofForge.IR.Examples.ContextProbe`, the first non-Counter Psy IR
  fixture.
- Added CLI support:

```sh
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
```

- Added `Examples/Psy/ContextProbe.golden.psy`.
- Added `scripts/psy/context-smoke.sh`, which mirrors the Counter Dargo smoke:
  `dargo test --file`, `dargo compile`, `dargo execute`, and
  `dargo generate-abi`.
- Added `scripts/psy/write-artifact-metadata.py` and wired both Psy smoke
  scripts to emit `proof-forge-artifact.json` with hashes for source, circuit
  JSON, ABI JSON, and execute logs.

Validation run:

```sh
lake build
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
diff -u Examples/Psy/ContextProbe.golden.psy build/psy/ContextProbe.psy
scripts/psy/context-smoke.sh
scripts/psy/counter-smoke.sh
git diff --check
```

Result:

- `lake build` passed.
- ContextProbe emits reviewable Psy source with parameters and context reads.
- Generated ContextProbe source matches the checked-in golden fixture.
- `scripts/psy/context-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [15]` for `sum_context(2,3)`.
- `scripts/psy/counter-smoke.sh` now also emits `proof-forge-artifact.json`.

Known limitations:

- ContextProbe uses `_proof_forge_marker` storage because Dargo v0.1.0 panics on
  an empty `#[contract] #[derive(Storage)]` struct.
- The IR still lacks maps, fixed arrays, assertions, hashes, bounded loops, and
  reusable package generation.
- Dargo does not expose a `--version` flag, so metadata records the Dargo path
  and leaves the version null for now.

Next step:

- Add a curated upstream syntax regression subset from `psy-compiler/tests`,
  then expand the IR/sourcegen surface toward maps, arrays, assertions, and
  hashes.

## 2026-06-30

### Psy Counter IR Sourcegen And Smoke

Commit: pending

Summary:

- Added `ProofForge.Backend.Psy.IR`, a strict v0 source generator for the
  hand-written portable Counter IR fixture.
- Added CLI support:

```sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
```

- Added `Examples/Psy/Counter.golden.psy` as the reviewed source snapshot.
- Added `scripts/psy/counter-smoke.sh`, which:
  - regenerates Counter Psy source
  - compares it against the golden fixture
  - runs `dargo test --file`
  - creates a temporary Dargo package
  - runs `dargo compile --contract-name Counter --method-names initialize increment get`
  - checks the Dargo JSON artifact is non-empty
  - runs `dargo execute --contract-name Counter --method-names initialize increment increment get`
  - checks the local execution log contains `result_vm: [2]`
  - runs `dargo generate-abi --contract-name Counter --output-dir target --pretty`
  - checks the ABI JSON artifact is non-empty
- Verified `psyup install 0.1.0` as a working macOS arm64 toolchain path for
  this smoke.
- Recorded the upstream syntax/CI corpus: `psy-precompiles`, `tests`, and
  `psy-compiler`'s Makefile `build`/`ci` targets.

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
diff -u Examples/Psy/Counter.golden.psy build/psy/Counter.psy
psyup install 0.1.0
scripts/psy/counter-smoke.sh
```

Result:

- `lake build` passed.
- Counter IR emits reviewable Psy source.
- Generated Psy source matches the checked-in golden fixture.
- `scripts/psy/counter-smoke.sh` generated `build/psy/Counter.psy`, ran
  `dargo test --file`, ran `dargo compile`, produced
  `build/psy/dargo-counter/target/proof_forge_counter.json`, ran
  `dargo execute`, and verified `get` returned `result_vm: [2]` after two
  increments in the same local execution session.
- The same smoke generated non-empty ABI output at
  `build/psy/dargo-counter/target/Counter.json`.
- Direct `cargo install --git https://github.com/PsyProtocol/psy-compiler dargo`
  fetched `psy-compiler` but failed while Cargo updated the `psy-node`
  `psy-contracts` submodule URL.
- `psyup` v0.1.1 currently has only a Linux x86_64 release asset; macOS arm64
  was validated by pinning `psyup install 0.1.0`.

Known limitations:

- The generator supports only the current no-argument Counter IR subset:
  `u64` scalar state, scalar read/write, `add`, let-bind, and return.
- No deploy JSON, artifact metadata, or live Psy node smoke exists yet.
  `dargo execute` covers local user/contract execution, not network deployment.

Next step:

- Add `proof-forge-artifact.json` metadata to the Psy smoke, then decide
  whether CI should pin `psyup` v0.1.0 or wait for a newer macOS release asset.

### Psy/DPN SDK Skeleton

Commit: `feat: add Psy DPN SDK skeleton`

Summary:

- Added `ProofForge.Psy` as the first Lean SDK surface for the `psy-dpn` ZK
  target.
- Added primitive types and helpers:
  - `Felt`
  - `U32`
  - `Hash`
  - `ContractMetadata`
- Added context, storage, IMT map, hash, and deferred invocation externs under
  the `lean_psy_*` naming convention.
- Added a small `Examples/Psy/Counter.lean` SDK example.

Validation run:

```sh
lake build
lake env lean Examples/Psy/Counter.lean
```

Result:

- Passed.

Notes:

- The example uses `initCounter` instead of `initialize` because `initialize`
  is a Lean command keyword.

Known limitations:

- The SDK is a source-generation boundary only; no Psy backend lowers these
  externs yet.
- There is no Dargo package generation or `.psy` output yet.

Next step:

- Add a `psy-dpn` source generator for the hand-written Counter IR fixture.

### Portable IR Counter Runtime Dispatch

Commit: `824f5f8 feat: add IR counter EVM runtime smoke`

Summary:

- Added EVM selector metadata to the hand-written Counter IR fixture.
- Extended IR-to-Yul lowering to emit runtime selector dispatch for:
  - `initialize()`
  - `increment()`
  - `get()`
- Added `proof-forge --emit-counter-ir-bytecode`, which compiles Counter IR
  through runtime Yul and `solc --strict-assembly`.
- Added a dedicated Foundry smoke script for the IR Counter path:

```sh
scripts/evm/ir-counter-smoke.sh
```

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
lake env proof-forge --emit-counter-ir-bytecode -o build/ir/Counter.bin --yul-output build/ir/Counter.bytecode.yul
solc --strict-assembly build/ir/Counter.yul --bin
scripts/evm/ir-counter-smoke.sh
```

Result:

- `lake build` passed.
- Counter IR emits selector-dispatch Yul.
- Counter IR emits non-empty EVM bytecode.
- `solc --strict-assembly` accepts the generated runtime Yul.
- Foundry smoke passes for `initialize`/`increment`/`get` and unknown-selector
  revert behavior.

Known limitations:

- The IR fixture is still hand-written; there is no Lean-source-to-IR extractor.
- Only no-argument entrypoints are supported in the IR EVM dispatcher.

Next step:

- Promote the IR Counter path into CI once external tool gating is in place, and
  generalize the dispatcher beyond no-argument entrypoints.

### Portable IR Counter Lowering

Commit: `787d437 feat: add portable IR counter lowering`

Summary:

- Added the first target registry modules:
  - `ProofForge.Target.Capability`
  - `ProofForge.Target.Registry`
  - `ProofForge.Target.Check`
- Added the first portable contract IR:
  - `ValueType`
  - `StateDecl`
  - `Expr`
  - `Effect`
  - `Statement`
  - `Entrypoint`
  - `Module`
- Added a hand-written Counter IR fixture in `ProofForge.IR.Examples.Counter`.
- Added an EVM/Yul lowering path for the Counter-shaped IR subset.
- Added CLI smoke command:

```sh
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
```

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
solc --strict-assembly build/ir/Counter.yul --bin
```

Result:

- `lake build` passed.
- Counter IR lowers to Yul.
- `solc --strict-assembly` accepts the generated Yul.

Known limitations:

- The IR-generated Yul currently contains function definitions only.
- It does not yet generate EVM calldata selector dispatch.
- `solc` emits `00` for this debug object because no runtime dispatcher calls
  the generated functions yet.
- Existing `--evm-bytecode` smoke still requires Foundry `cast`; it was not
  revalidated locally because `cast` was not on `PATH`.

Next step:

- Generate an EVM dispatcher/runtime wrapper from IR entrypoints so the IR path
  can produce callable bytecode and run through Foundry smoke.

### Psy DPN Target Research

Commit: `ce5ab3e docs: add Psy DPN target research`

Summary:

- Added `psy-dpn` as a Research-stage target.
- Classified Psy as a ZK circuit source-generation target.
- Documented why the first integration path should generate `.psy` source and
  call Dargo instead of directly emitting DPN internals.
- Added `zk.circuit` and `zk.proof` capability ids.
- Added Chinese analysis for the Psy/DPN target.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- No Psy source generator exists yet.
- No Dargo smoke exists in this repository.

Next step:

- Reuse the portable Counter IR fixture once the IR-to-sourcegen path exists.

### Portable IR And Target Planning Docs

Commit: `9b7fce3 docs: add portable IR, capability registry, validation gates, and dev standards`

Summary:

- Added the first portable IR spec.
- Added canonical capability ids.
- Added shared Counter scenario.
- Added validation gates and development standards.
- Added implementation backlog slices for target registry, IR, metadata, EVM
  hardening, Wasm, Solana, Move, CI, and Psy.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- These were planning docs only; no IR code existed yet.

Next step:

- Implement the Target registry and Counter-shaped IR v0 in Lean.

### Multi-Chain Target Design

Commit: `a5555e5 docs: add multichain target design`

Summary:

- Added the first multi-chain platform RFCs and Chinese feasibility/technical
  analysis.
- Established the direction: Lean business logic plus target-specific adapters.
- Documented EVM, Solana, Wasm-family, Move-family, and cloud platform tracks.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- Design-only milestone.

Next step:

- Split the design into concrete target registry, IR, and validation tasks.

### EVM Baseline

Commits:

- `34b1708 Initial ProofForge EVM backend`
- `b7a5343 Add EVM examples and Foundry smoke tests`
- `a97dd21 Add CI and integrate EVM bytecode CLI`

Summary:

- Added the initial EVM SDK and Yul backend.
- Added EVM examples and Foundry smoke tests.
- Added bytecode compilation through `solc --strict-assembly`.
- Added CI around the baseline build and EVM smoke path.

Current role:

- EVM remains the first working target.
- New IR work should use EVM as the first executable backend to validate
  semantics before adding more chains.

### EVM Nested Local Fixed Arrays

Commit: pending

Summary:

- Extended portable IR EVM local fixed-array lowering to static nested scalar
  arrays.
- Added deterministic Yul locals for nested leaves such as `matrix[1][0]`.
- Covered static nested reads, mutable leaf assignment, numeric leaf compound
  assignment, nested whole-local assignment, and RHS snapshotting.

Validation run:

```sh
lake build
scripts/evm/array-value-ir-smoke.sh
```

Result:

- Lean build passed.
- Array value smoke produced reproducible golden Yul, compiled bytecode with
  `solc --strict-assembly`, validated metadata, and passed 14 Foundry tests.

Known limitations:

- Dynamic nested local indexes and nested local arrays with non-scalar leaves
  remain explicit unsupported surfaces.
