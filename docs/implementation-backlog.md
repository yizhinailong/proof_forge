> **Note:** public validation command changes must update
> [validation-gates.md](validation-gates.md) in the same change.

# Implementation Backlog

This backlog turns the multi-chain design into reviewable engineering slices.
It is intentionally scoped to local compiler, artifact, and smoke-test work.
The cloud platform should wait until at least two materially different targets
are working locally.

Related docs:

- [Design decisions](decisions.md)
- [Portable Contract IR](portable-ir.md)
- [Capability registry](capability-registry.md)
- [Shared scenario: Counter](shared-scenario.md)
- [RFC 0002](rfcs/0002-target-implementation-design.md)
- [Target notes](targets/README.md)
- [Validation gates](validation-gates.md)

## Workstream 1: Target Registry

Goal: make target selection explicit before adding more backends.

Tasks:

- Add target ids: `evm`, `wasm-near`, `wasm-cosmwasm`,
  `solana-sbpf-asm`, `solana-sbpf-linker` (superseded), `solana-zig-fork`,
  `move-sui`, `move-aptos`, `psy-dpn`.
- Define target family, artifact kind, required tools, and capability set
  (see [capability-registry.md](capability-registry.md)).
- Add a target lookup function for CLI and scripts.
- Done: add an EVM-compatible chain profile layer for deployment metadata,
  starting with `robinhood-chain-testnet` under the `evm` compiler target.
- Add diagnostics for unknown targets and unsupported capabilities.

Acceptance criteria:

- `evm` can be represented as a target profile without changing current EVM
  behavior.
- EVM-compatible chain profiles can reuse the `evm` compiler target without
  being returned by target-id lookup.
- A target profile can declare external tool requirements.
- Unsupported capability errors include target id, capability id, and source
  location when available.

## Workstream 1.5: Portable IR and Shared Scenario

Goal: define the contract IR and Counter scenario before non-EVM spikes.

Tasks:

- Implement IR node types per [portable-ir.md](portable-ir.md).
- Express Counter per [shared-scenario.md](shared-scenario.md).
- Lower Counter IR to EVM (directly or via EmitYul adapter).
- Wire capability checker to [capability-registry.md](capability-registry.md).

Acceptance criteria:

- Counter module is representable in IR without EVM opcodes in the IR layer.
- EVM build from IR matches existing Counter behavior.
- At least one unsupported capability is rejected with a clear diagnostic.
- IR version appears in artifact metadata when emitted.

## Workstream 2: Artifact Metadata

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: every build should produce a machine-readable result that can later feed
CI and the cloud platform.

Tasks:

- Done for EVM: add a `proof-forge-artifact.json` schema for EVM bytecode
  builds.
- Done for EVM: emit metadata for `--evm-bytecode` and portable IR EVM bytecode
  fixture builds.
- Done for EVM: include source module, target id, artifact paths, SHA-256, byte
  sizes, solc path/version, selector/signature metadata, and validation status.
- Done for EVM: preserve SDK `.evm-methods` Solidity signatures in
  `abi.methods[].signature` for both `proof-forge-artifact.json` and
  `proof-forge-deploy.json`; validators check selector shape, duplicate method
  selectors/functions/signatures, generated Yul function names, and
  signature/arg-count consistency, and SDK example gates require signatures.
- Done for EVM: emit and validate a ProofForge deploy manifest for every EVM
  bytecode build, recording runtime bytecode inputs, ABI selectors, deployable
  initcode, and the current `not-generated` transaction-broadcast status.
- Done for EVM: generate an artifact-linked `.init.bin` creation bytecode file
  for each EVM bytecode build, record it in both `proof-forge-artifact.json`
  and `proof-forge-deploy.json`, and validate that the initcode header copies
  and returns the referenced runtime bytecode.
- Done for EVM: add `--evm-chain-profile <id>` so bytecode builds can record a
  known EVM chain profile such as `robinhood-chain-testnet` or `anvil-local` in
  `proof-forge-deploy.json`; validators check profile id, chain id, RPC URLs,
  explorer, verifier, and deployment-block consistency without broadcasting.
- Done for EVM: add `--evm-constructor-args-hex <hex>` so bytecode builds can
  append explicit ABI-encoded constructor arguments to generated `.init.bin`,
  record normalized hex/byte-size/SHA-256 constructor metadata in
  `proof-forge-deploy.json`, and validate that the initcode tail matches the
  manifest.
- Done for EVM: add `--evm-constructor-param <name:type>` so bytecode builds
  can record static-word constructor ABI schema in artifact metadata and deploy
  manifests, validate supported schema types, and verify that an explicit
  ABI-encoded constructor-argument blob has the expected 32-byte word length.
- Done for EVM: add `--evm-constructor-arg <name=value>` so bytecode builds can
  ABI-encode typed constructor values for `uint256`, `uint64`, `uint32`,
  `bool`, `bytes32`, and `address`, record whether constructor args came from
  typed values or raw hex, reject missing/duplicate/out-of-range values, and
  validate the generated initcode tail against metadata and deploy manifests.
- Done for EVM: record structured portable IR selector-facing entrypoint ABI
  metadata in `abi.entrypoints`, including Solidity-style selector signatures,
  IR type names, ABI parameter/return types, flattened calldata word
  types/counts, and flattened return word types/counts; validators check
  selector/signature consistency with `cast sig` and
  `EvmAbiAggregateProbe` locks aggregate word layouts with
  `--expect-entrypoint-abi`.
- Done for EVM: record portable IR event ABI metadata in `abi.events`, including
  Solidity-style event signatures, `topic0`, indexed/data fields, flattened ABI
  word types, and topic/data encodings; EventProbe validates every emitted event
  with `--expect-event` and `cast keccak`.
- Done for EVM: extend `scripts/evm/diagnostic-smoke.sh` to lock constructor
  CLI diagnostics for unsupported dynamic constructor ABI types, missing or
  duplicate typed values, mixed typed/raw constructor argument sources,
  overflow, and malformed static-word values such as short addresses.
- Done for EVM: add an Anvil deploy smoke that sends generated Counter
  `.init.bin` with `cast send --create`, records constructor ABI schema and
  typed constructor args plus a `proof-forge-deploy-run.json` artifact,
  records the `eth_getTransactionByHash` creation transaction JSON, validates
  the `anvil-local` chain profile, receipt/deployed address/runtime-code match
  and transaction input initcode, and exercises the Counter lifecycle over
  JSON-RPC.
- Keep schema versioned from day one.

Acceptance criteria:

- EVM bytecode build writes runtime bytecode, deployable initcode, metadata,
  and deploy manifest next to each other.
- Metadata and deploy manifests can be parsed independently by CI scripts.
- Portable IR bytecode metadata and deploy manifests can describe ABI-facing
  entrypoints, including selector signatures, flattened calldata word layout,
  and flattened return-data word layout.
- Portable IR bytecode metadata and deploy manifests can describe ABI-facing
  events, including indexed topic encoding and non-indexed data-word encoding.
- Deploy manifests can carry optional EVM chain profile metadata from the
  target registry while keeping transaction broadcast artifacts explicitly
  `not-generated`.
- Local Anvil deployment can consume the generated deploy manifest and initcode,
  produce a validated deploy-run artifact, and prove the deployed runtime code
  matches the generated bytecode even when the initcode includes a typed or raw
  ABI-encoded constructor-argument tail with a recorded static constructor ABI
  schema; the deploy-run artifact also links the observed creation transaction
  JSON and validates that its input equals the generated initcode and that the
  deployment profile chain id matches the actual local chain.
- EVM metadata can represent missing optional version data as `null`, not
  malformed metadata.

## Workstream 3: EVM Baseline Hardening

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: keep EVM stable while the target model is introduced.

Tasks:

- Keep `proof-forge --evm-bytecode` working.
- EVM semantic plan migration TODO:
  - Done: make `ModulePlan` target-driven so helper planning is derived from
    `Target.resolveModule/resolveSpec Target.evm` before Yul generation.
  - Split `ProofForge.Backend.Evm.IR` into `Validate`, `Lower`, `ToYul`, and
    `Metadata` modules while keeping `IR.lean` as a compatibility facade until
    callers have moved.
  - Done: move scalar and map storage slot Yul construction to
    `StorageSlotPlan -> ToYul`, starting with map value/presence slots used by
    storage paths.
  - Extend `StorageSlotPlan -> ToYul` to array slots and struct-array field
    slots, then remove the old direct slot-expression builders from
    `IR.lean`.
  - Add `ExprPlan` and `StmtPlan` so expression and statement validation,
    helper discovery, and target-specific lowering happen before Yul AST
    assembly.
  - Add `EntrypointPlan` for selector dispatch, calldata guards, ABI word
    flattening, return-data encoding, and metadata selector layout.
  - Add `EventPlan` for event signature topics, indexed-topic hashing,
    non-indexed data flattening, and metadata event layout.
  - Add `CrosscallPlan` for typed `call`, value-bearing `call`, `staticcall`,
    `delegatecall`, `create`, and `create2` helpers.
  - Add `MetadataPlan` and deploy-artifact planning so bytecode metadata,
    initcode, deployment manifests, and chain profile references are produced
    from the same semantic plan.
  - Delete the old custom semantic `IR.lean -> Yul` lowering only after each
    migrated capability is covered by plan-level diagnostics, golden Yul, solc
    bytecode generation, Foundry smokes, artifact metadata validation, and the
    EVM IR coverage manifest.
  - Keep `ProofForge.Compiler.Yul.AST` and
    `ProofForge.Compiler.Yul.Printer`; the migration replaces backend semantic
    lowering, not the target AST/printer boundary.
- Done: add EVM IR diagnostic smoke so unsupported portable IR shapes fail
  before Yul generation with stable messages.
- Done: add an EVM IR coverage manifest gate so every portable IR constructor
  must be classified as lowered, validated, unsupported, or structural for the
  EVM backend.
- Done: add `AbiScalarProbe` for portable IR EVM scalar ABI parameter decoding
  over `U64`, `U32`, and `Bool`, with golden Yul, solc bytecode, and Foundry
  malformed-calldata validation.
- Done: add EVM IR `assert` and `assert_eq` lowering as Yul revert guards,
  with `AssertProbe` golden Yul, solc bytecode, and Foundry success/revert
  validation.
- Done: add EVM IR mutable scalar local bindings and local assignment lowering,
  with `AssignmentProbe` golden Yul, solc bytecode, and Foundry success/revert
  validation.
- Done: add EVM IR local and scalar storage compound assignment lowering for
  all portable `AssignOp` variants, with `EvmAssignOpProbe` golden Yul, solc
  bytecode, Foundry runtime/raw-slot validation, metadata capability
  validation, and explicit diagnostics for malformed targets/types.
- Done: add EVM IR statement-level `if/else` lowering as Yul `switch` blocks,
  with `ConditionalProbe` golden Yul, solc bytecode, Foundry runtime
  validation, plus EVM-specific branch-local early-return validation through
  `EvmLoopProbe`.
- Done: add EVM IR `boundedFor` lowering as Yul `for` loops with static
  bounds, with `EvmLoopProbe` golden Yul, solc bytecode, Foundry runtime/raw
  storage validation, metadata capability validation, branch-local and
  loop-local early-return lowering through Yul `leave`, and explicit invalid
  range diagnostics.
- Done: add EVM IR context read lowering for `userId`, `contractId`, and
  `checkpointId` as Yul `caller()`, `address()`, and `number()`, with
  `ContextProbe` golden Yul, solc bytecode, Foundry runtime validation, and
  metadata capability validation.
- Done: add EVM IR `nativeValue` lowering as Yul `callvalue()`, with
  `ContextProbe` golden Yul, solc bytecode, Foundry value-bearing call
  validation, and `value.native` metadata capability validation.
- Done: add EVM IR `eventEmit` lowering to Yul `log1` with
  `keccak256(Solidity-style event signature)` topic0 and 32-byte word data
  fields, with `EventProbe` golden Yul, solc bytecode, Foundry recorded-log
  validation, metadata capability validation, and explicit malformed event
  diagnostics.
- Done: add EVM IR `eventEmitIndexed` lowering to Yul `log2`/`log3`/`log4`
  for up to three scalar indexed fields, with signature topic0, indexed topics,
  non-indexed 32-byte word data, `EventProbe` golden Yul, solc bytecode,
  Foundry recorded-log validation, metadata capability validation, and explicit
  indexed event diagnostics.
- Done: close the EventProbe validation gap for multi-topic scalar indexed
  events. `IndexedTwoValues(uint64,uint64,uint64)` and
  `IndexedThreeValues(uint64,uint64,uint64,uint64)` now prove the generated Yul
  emits `log3` and `log4`, preserves ordered scalar indexed topics, validates
  metadata selectors, compiles with `solc`, and passes Foundry recorded-log
  assertions.
- Done: close the EventProbe validation gap for typed scalar event fields.
  `TypedScalarEvent(bool,uint32,bytes32)` and
  `IndexedTypedScalar(bool,uint32,bytes32,uint64)` now prove Bool, U32, and
  Hash event data words and indexed topics lower correctly, with Bool/U32
  dispatcher guards, golden Yul, metadata selector checks, `solc`, and Foundry
  recorded-log assertions.
- Done: extend EVM IR event data lowering beyond scalar words so non-indexed
  flat struct fields, scalar fixed-array fields, and fixed arrays of flat
  structs emit ABI-style flattened data words, with canonical Solidity-style
  event signatures such as `PairEvent((uint64,uint64))`,
  `ArrayEvent(uint64[2])`, and `PairArrayEvent((uint64,uint64)[2])`,
  `EventProbe`
  golden Yul, solc bytecode, Foundry recorded-log validation, metadata selector
  validation, and explicit diagnostics for unsupported aggregate indexed fields.
- Done: extend EVM IR `eventEmitIndexed` lowering so flat struct indexed fields
  and fixed-array indexed fields whose elements are flat structs hash their
  ABI-style flattened words into indexed topics. `EventProbe` now covers
  `IndexedPair((uint64,uint64),uint64)` and
  `IndexedPairArray((uint64,uint64)[2],uint64)` with golden Yul, solc bytecode,
  metadata selector validation, Foundry recorded-log topic-hash checks, and a
  diagnostic for nested/unsupported aggregate indexed shapes.
- Done: close the EventProbe validation gap for scalar fixed-array indexed
  topics by adding `IndexedArray(uint64[2],uint64)` golden Yul, metadata selector
  validation, solc bytecode generation, and Foundry recorded-log topic-hash
  checks.
- Done: extend EventProbe nested fixed-array event aggregate coverage.
  `MatrixEvent(uint64[2][2])` and
  `PairMatrixEvent((uint64,uint64)[2][2])` prove recursive non-indexed data
  flattening for scalar and flat-struct leaves, while
  `IndexedMatrix(uint64[2][2],uint64)` and
  `IndexedPairMatrix((uint64,uint64)[2][2],uint64)` prove indexed aggregate
  topic hashing over recursively flattened ABI-style words. The smoke now locks
  the new selectors, event ABI metadata, golden Yul, `solc` bytecode, and
  Foundry recorded-log assertions; nested arrays with unsupported or non-flat
  leaves remain explicit diagnostics.
- Done: add EventProbe coverage for storage-backed flat struct event data and
  indexed aggregate topics. `StoragePairEvent((uint64,uint64))` and
  `IndexedStoragePair((uint64,uint64),uint64)` now prove that a whole scalar
  storage struct write can be read back through `storageScalarRead`, flattened
  into event data words, hashed into indexed topics, validated in golden Yul,
  checked in metadata selectors, compiled by `solc`, and decoded by Foundry
  recorded logs.
- Done: add EventProbe coverage for storage-backed fixed-array event aggregates.
  `StorageArrayEvent(uint64[2])`,
  `StoragePairArrayEvent((uint64,uint64)[2])`,
  `IndexedStorageArray(uint64[2],uint64)`, and
  `IndexedStoragePairArray((uint64,uint64)[2],uint64)` now prove that storage
  array reads and storage array struct field reads can feed non-indexed event
  data flattening and indexed aggregate topic hashing, with golden Yul,
  metadata selector checks, `solc`, and Foundry recorded-log validation.
- Done: add EVM IR `crosscallInvoke` lowering to synchronous EVM `call`
  helpers with selector packing, word arguments, one-word returns, failed-call
  and short-return reverts, with `EvmCrosscallProbe` golden Yul, solc bytecode,
  Foundry runtime validation, metadata capability validation, and explicit
  malformed crosscall type diagnostics.
- Done: add EVM IR `crosscallInvokeTyped` lowering for typed scalar-word
  crosscalls over `Bool`, `U32`, `U64`, and `Hash`, with return-type-specific
  Yul helpers, Bool/U32 return-data guards, `EvmCrosscallProbe` golden Yul,
  solc bytecode, Foundry valid/invalid typed-return validation, metadata
  entrypoint validation, diagnostics for aggregate argument/return shapes not
  covered at that stage, and explicit Psy unsupported diagnostics.
- Done: extend EVM IR normal `crosscallInvokeTyped` return lowering beyond
  scalar words for direct entrypoint returns of flat structs and scalar fixed
  arrays, with ABI-word-shape-specific Yul helpers, multi-word return-data
  size checks, Bool/U32 range guards across aggregate return words,
  `EvmCrosscallProbe` golden Yul, solc bytecode, Foundry aggregate
  struct/array return validation, metadata selector validation, and explicit
  diagnostics for aggregate return shapes not covered at that stage.
- Done: extend EVM IR typed crosscall argument lowering beyond scalar words so
  normal, value-bearing, static, and delegate typed calls can flatten flat
  struct and scalar fixed-array arguments into ABI words. `EvmCrosscallProbe`
  now covers normal struct and fixed-array arguments plus value/static/delegate
  struct arguments through golden Yul, solc bytecode, Foundry runtime checks,
  metadata selector validation, and explicit diagnostics for aggregate argument
  shapes not covered at that stage.
- Done: add EVM IR `crosscallInvokeValueTyped` lowering for value-bearing typed
  crosscalls, forwarding an explicit U64 call-value expression through
  value-specific Yul helpers for scalar returns plus flat struct and scalar
  fixed-array entrypoint aggregate returns, with `EvmCrosscallProbe` golden Yul,
  solc bytecode, Foundry `msg.value`/callee-balance validation, aggregate
  Bool/U32 malformed-return guards, metadata entrypoint validation, EVM
  malformed value/return diagnostics, and explicit Psy unsupported diagnostics.
- Done: add EVM IR `crosscallInvokeStaticTyped` lowering for typed staticcalls,
  using value-free Yul `staticcall` helpers with selector/scalar/flat-aggregate
  argument packing, scalar returns, flat struct and scalar fixed-array
  entrypoint aggregate returns, and Bool/U32 return guards, with
  `EvmCrosscallProbe` golden Yul, solc bytecode, Foundry U64 read-only return,
  Bool/U32/Hash static typed return, aggregate return validation, invalid
  typed-return, static-context state-write failure validation, metadata
  entrypoint validation, EVM malformed nested aggregate diagnostics, and
  explicit Psy unsupported diagnostics.
- Done: add EVM IR `crosscallInvokeDelegateTyped` lowering for typed
  delegatecalls, using value-free Yul `delegatecall` helpers with
  selector/scalar/flat-aggregate argument packing, scalar returns, flat struct
  and scalar fixed-array entrypoint aggregate returns, and Bool/U32 return
  guards, with `EvmCrosscallProbe` golden Yul, solc bytecode, Foundry
  caller-storage read/write validation, Bool/U32/Hash delegate typed return
  validation, aggregate return validation, invalid typed-return validation,
  metadata entrypoint validation, EVM malformed nested aggregate diagnostics,
  and explicit Psy unsupported diagnostics.
- Done: extend EVM IR typed crosscall aggregate coverage to fixed arrays of
  flat structs across normal, value-bearing, static, and delegate typed call
  arguments and direct entrypoint returns. `EvmCrosscallProbe` now validates
  `RemotePair[2]` ABI-word flattening, Bool/U32 field return guards, golden
  Yul, solc bytecode, Foundry runtime behavior, and metadata selectors across
  all four call modes.
- Done: extend EVM IR typed crosscall aggregate coverage to nested scalar fixed
  arrays across normal, value-bearing, static, and delegate typed call
  arguments and direct entrypoint returns. `EvmCrosscallProbe` now validates
  `uint64[2][2]` ABI-word flattening, golden Yul, solc bytecode, metadata
  selectors, Foundry runtime behavior, value forwarding, staticcall behavior,
  and delegatecall behavior across all four call modes. At that milestone,
  diagnostics still rejected struct and other non-scalar nested fixed-array
  leaves; flat struct leaves are now covered by the follow-up item below.
- Done: extend EVM IR typed crosscall aggregate coverage to nested fixed arrays
  whose leaves are flat structs. `EvmCrosscallProbe` now validates
  `RemotePair[2][2]` arguments and direct entrypoint returns across normal,
  value-bearing, static, and delegate typed calls, including ABI word
  flattening, Bool/U32 field guards, golden Yul, solc bytecode, metadata
  selectors, Foundry runtime behavior, value forwarding, staticcall behavior,
  and delegatecall behavior. Diagnostics still reject nested fixed-array leaves
  whose structs are non-flat or otherwise unsupported.
- Done: add EVM IR `crosscallCreate` and `crosscallCreate2` lowering for fixed
  init-code hex. Creation helpers write init code to memory, call Yul
  `create`/`create2`, revert on zero-address failure, return the deployed
  address word, and validate golden Yul, solc bytecode, metadata selectors,
  Foundry deployed runtime calls, deterministic CREATE2 address derivation,
  EVM malformed creation diagnostics, and Psy unsupported diagnostics.
- Done: add EVM IR direct scalar expression validation for `U64`/`U32`
  arithmetic, `U64` exponentiation, `U64`/`U32` bitwise operations and shifts,
  predicates, boolean operators, literals, immutable locals, supported casts,
  one-word returns, dispatcher guards, and assertion guards, with
  `EvmExpressionProbe` golden Yul, solc bytecode, Foundry runtime/malformed
  calldata validation, metadata capability validation, and CI coverage.
- Done: add EVM IR `Hash` word lowering, `hash4`/`hashValue` packing, and
  `hash`/`hash_two_to_one` lowering through Yul `keccak256` helpers, with
  `EvmHashProbe` golden Yul, solc bytecode, Foundry ABI/storage validation,
  metadata capability validation, and explicit Hash/U64 mismatch diagnostics.
- Done: add EVM IR `Map<U64, U64, N>` storage lowering through
  Solidity-style `keccak256(key, slot)` mapping slots, with `EvmMapProbe`
  golden Yul, solc bytecode, Foundry runtime/raw-slot validation, metadata
  capability validation, and explicit diagnostics for unsupported map shapes
  and statement-position misuse.
- Done: add EVM IR single-segment `mapKey` storage path compound assignment
  over `Map<U64, U64, N>`, with `EvmMapProbe` golden Yul, solc bytecode,
  Foundry runtime/raw-slot validation, metadata capability validation, and
  explicit diagnostics for expression-position and nested-path misuse.
- Done: generalize EVM IR storage maps to word key/value shapes over `U32`,
  `U64`, `Bool`, and `Hash`, reusing Solidity-style `keccak256(key, slot)`
  mapping slots, with `EvmTypedMapProbe` golden Yul, solc bytecode, Foundry
  runtime/raw-slot validation, `U32`/`Bool` calldata guards, metadata
  capability validation, CI coverage, and explicit diagnostics for non-word map
  shapes.
- Done: add EVM IR `storage.map.contains` lowering through ProofForge-managed
  presence slots rooted at `keccak256(slot || PROOF_FORGE_MAP_PRESENCE)`,
  with `EvmMapProbe` and `EvmTypedMapProbe` golden Yul, solc bytecode, Foundry
  value/presence-slot validation for U64/U32/Bool/Hash maps, zero-valued
  present-key coverage, metadata validation, and explicit diagnostics for
  statement-position misuse.
- Done: add EVM IR nested map storage paths over consecutive `mapKey`
  segments, folding Solidity-style mapping slots for value storage and
  ProofForge-managed presence slots for final keys, with `EvmMapProbe` and
  `EvmTypedMapProbe` golden Yul, solc bytecode, Foundry raw-slot validation,
  U32 dispatcher guard coverage, metadata validation, and explicit diagnostics
  for mixed map/aggregate storage paths.
- Done: add EVM IR `U64` fixed storage array lowering as contiguous storage
  slots with runtime bounds checks, with `EvmStorageArrayProbe` golden Yul,
  solc bytecode, Foundry runtime/raw-slot validation, metadata capability
  validation, and explicit diagnostics for unsupported array element types.
- Done: add EVM IR single-segment `index` storage path read/write/compound
  assignment over `U64` fixed storage arrays, reusing the bounded array slot
  helper and extending `EvmStorageArrayProbe` validation.
- Done: generalize EVM IR word storage to `Bool` scalar storage and
  `U32`/`Bool`/`Hash` fixed storage arrays, reusing the bounded array slot
  helper, with `EvmTypedStorageProbe` golden Yul, solc bytecode, Foundry
  runtime/raw-slot validation, `U32` calldata range guards, metadata capability
  validation, CI coverage, and explicit diagnostics for unsupported non-word
  storage element types.
- Done: add EVM IR immutable local fixed-array value lowering for `U64`,
  `U32`, `Bool`, and `Hash` elements with static literal indexes, direct
  fixed-array literal indexing, `EvmArrayValueProbe` golden Yul, solc
  bytecode, Foundry runtime validation, metadata capability validation, and
  explicit diagnostics for static out-of-bounds indexes.
- Done: extend EVM IR local fixed-array lowering to mutable aggregate locals,
  including static element assignment, numeric element compound assignment, and
  `U32`/`Bool`/`Hash` element writes, with `EvmArrayValueProbe` golden Yul,
  solc bytecode, Foundry runtime validation, metadata entrypoint validation,
  CI coverage, and explicit diagnostics for immutable element assignment.
- Done: extend EVM IR local fixed-array lowering to dynamic local/literal
  indexes by threading a lowering environment through expressions, generating
  length-specific Yul getter helpers for dynamic reads, lowering dynamic local
  element assignment and numeric compound assignment to `switch` blocks, and
  validating dynamic in-bounds/out-of-bounds behavior through
  `EvmArrayValueProbe` golden Yul, metadata entrypoints, solc bytecode, and
  Foundry runtime checks.
- Done: add EVM IR whole local fixed-array assignment from local values and
  literals, snapshotting RHS elements into temporary Yul locals before writing
  target elements, and validating local-source and self-referential literal RHS
  behavior through `EvmArrayValueProbe` golden Yul, metadata entrypoints, solc
  bytecode, and Foundry runtime checks.
- Done: extend EVM IR local fixed-array lowering to static nested scalar arrays,
  including immutable reads, mutable leaf assignment, numeric leaf compound
  assignment, nested whole-local assignment, and RHS snapshotting, with
  `EvmArrayValueProbe` golden Yul, metadata entrypoints, solc bytecode, and
  Foundry runtime checks. Flat struct nested leaves are covered by
  `EvmStructArrayValueProbe`; other unsupported aggregate leaves remain
  explicit diagnostics.
- Done: extend EVM IR local fixed-array lowering to dynamic nested scalar array
  indexes, including nested getter helpers for reads, nested `switch` lowering
  for mutable leaf assignment and compound assignment, mixed static/dynamic
  path coverage, runtime out-of-bounds reverts, `EvmArrayValueProbe` golden
  Yul, metadata entrypoints, solc bytecode, and Foundry runtime checks.
- Done: add EVM IR flat immutable local struct value lowering for `U64`,
  `U32`, `Bool`, and `Hash` fields, direct struct literal field access,
  `EvmStructValueProbe` golden Yul, solc bytecode, Foundry runtime validation,
  metadata capability validation, and explicit diagnostics for whole-struct
  storage misuse and nested fields.
- Done: extend EVM IR flat local struct lowering to mutable aggregate locals,
  including static field assignment, numeric field compound assignment, and
  `U32`/`Bool`/`Hash` field writes, with `EvmStructValueProbe` golden Yul,
  solc bytecode, Foundry runtime validation, metadata entrypoint validation,
  CI coverage, and explicit diagnostics for immutable field assignment.
- Done: add EVM IR whole local struct assignment from local values and literals,
  snapshotting RHS fields into temporary Yul locals before writing target
  fields, and validating local-source and self-referential literal RHS behavior
  through `EvmStructValueProbe` golden Yul, metadata entrypoints, solc bytecode,
  and Foundry runtime checks.
- Done: add EVM IR local fixed arrays of flat structs, expanding each element
  field into deterministic Yul locals, supporting static and dynamic
  `field(arrayGet(localArray, index), name)` reads, mutable field assignment,
  numeric field compound assignment, whole local assignment from local arrays
  and self-referential array literals with RHS snapshotting,
  `U64`/`U32`/`Bool`/`Hash` field coverage, dynamic out-of-bounds reverts,
  `EvmStructArrayValueProbe` golden Yul, metadata entrypoint/capability
  validation, solc bytecode generation, Foundry runtime checks, and CI
  coverage.
- Done: extend EVM IR nested local fixed arrays to flat struct leaves, expanding
  each nested element field into deterministic Yul locals, supporting static and
  dynamic nested field reads, nested mutable field assignment, numeric nested
  field compound assignment, whole nested local assignment from local arrays and
  self-referential nested array literals with RHS snapshotting, dynamic
  out-of-bounds reverts, refreshed `EvmStructArrayValueProbe` golden Yul,
  metadata entrypoint validation, solc bytecode generation, Foundry runtime
  checks, and coverage manifest updates.
- Done: add EVM IR flat storage struct lowering for scalar storage structs and
  fixed storage arrays of flat structs, including direct struct field effects,
  scalar `field` storage paths, array `index`+`field` storage paths, numeric
  field compound assignment, whole scalar storage struct read/write with RHS
  snapshotting, storage-backed ABI struct returns, `Bool`/`U32`/`Hash` field
  coverage, `EvmStorageStructProbe` golden Yul, solc bytecode, Foundry
  runtime/raw-slot validation, metadata capability validation, CI coverage, and
  explicit diagnostics for missing fields and non-flat storage structs.
- Done: validate storage-backed aggregate ABI returns for EVM IR by extending
  `EvmStorageArrayProbe` with `return_values()` over storage-array element
  reads and `EvmStorageStructProbe` with `return_points()` over fixed
  storage-array-of-struct field reads, including golden Yul, solc bytecode,
  metadata selector validation, Foundry ABI decoding, and raw-slot checks.
- Done: add EVM IR static aggregate ABI lowering for fixed-array and struct
  parameters/returns, including nested scalar fixed arrays and fixed arrays of
  flat structs, with calldata word flattening, `U32`/`Bool` aggregate word
  guards, multi-word return-data encoding, `EvmAbiAggregateProbe` golden Yul,
  solc bytecode, Foundry runtime/malformed calldata validation, metadata
  capability validation, structured `abi.entrypoints` selector/calldata/return
  word-layout validation, CI coverage, and explicit diagnostics for Unit,
  zero-length arrays, non-flat struct fields, and crosscall-only unsupported
  nested fixed-array leaf shapes.
- Done: close the EVM aggregate ABI validation gap for `Hash` leaves.
  `HashPair(bytes32,bytes32)`, `pick_hash(bytes32[2])`, and
  `make_hash_array(bytes32,bytes32)` now prove `Hash`/`bytes32` fields and
  fixed arrays flatten through calldata and return-data encoding, with golden
  Yul, metadata selector checks, `solc`, Foundry ABI decoding, and short
  `bytes32[2]` calldata rejection.
- Done: add golden Yul outputs for SDK EVM examples (`Counter`,
  `ArrayExample`, `SimpleToken`, `ERC20`, `Ownable`, `Pausable`, and
  `VerifiedVault`) and make `scripts/evm/build-examples.sh` diff generated Yul
  against those fixtures before validating metadata.
- Done: add metadata emission and validation around the current
  `solc --strict-assembly` flow for SDK and portable IR EVM bytecode builds.
- Keep Foundry smoke as the mature EVM smoke test.

Acceptance criteria:

- `lake build` passes.
- `scripts/evm/diagnostic-smoke.sh` passes.
- `scripts/evm/check-ir-coverage-manifest.py` passes.
- `scripts/evm/build-examples.sh` succeeds on a machine with `solc`.
- `scripts/evm/foundry-smoke.sh` succeeds on a machine with Foundry.
- The generated metadata points to the bytecode artifact and records `target:
  evm`.

## Workstream 4: Wasm Host Runtime Split

Goal: make Wasm host adapters target-driven instead of assuming every Wasm
contract is NEAR.

Tasks:

- Move chain extern declarations out of generic EmitZig runtime externs.
- Add a target-selected host bridge list.
- Keep NEAR bridge as the reference implementation.
- Add a CosmWasm bridge skeleton with allocator and region ABI.

Acceptance criteria:

- A Wasm build can select NEAR or CosmWasm bridge explicitly.
- Generic Wasm runtime does not force-link NEAR host functions.
- `wasm-near` and `wasm-cosmwasm` can have different required exports.

## Workstream 5: CosmWasm Spike

Goal: prove that ProofForge can target another Wasm host besides NEAR.

Tasks:

- Add `Lean.CosmWasm` SDK skeleton (see [wasm-family.md](targets/wasm-family.md)).
- Add `zigc-cosmwasm` wrapper.
- Add `cosmwasm_contract_root.zig`.
- Export `interface_version_8`, `allocate`, `deallocate`, `instantiate`,
  `execute`, and `query`.
- Add Counter example using JSON-backed messages.
- Add `cosmwasm-check` smoke.

Acceptance criteria:

- Counter Wasm passes `cosmwasm-check`.
- `instantiate`, `execute`, and `query` are present in exports.
- The smoke test can increment and query counter state.

## Workstream 6: Solana sBPF Assembly Toolchain Integration (Phase 0)

Goal: validate the direct-assembly route end to end — a canned `.s` file
round-trips through the blueshift-gg/sbpf toolchain into a loadable ELF.
Supersedes the old sbpf-linker spike (D-026).

Tasks:

- Install `sbpf` via `cargo install --git https://github.com/blueshift-gg/sbpf.git`.
- Add `--emit-sbpf-asm` CLI mode to `proof-forge` that writes a canned
  `entrypoint.s` (returns success, no account parsing).
- Run `sbpf build` on the canned `.s`; verify a valid eBPF ELF is produced.
- Verify `sbpf disassemble` round-trips the ELF.
- Record toolchain version in artifact metadata.

Acceptance criteria:

- [x] `sbpf build` produces a `.so` recognized as `ELF 64-bit LSB ... eBPF`.
- [x] `sbpf disassemble` produces assembly matching the input.
- [x] `--emit-sbpf-asm` writes valid `.s` without assembly errors.
- [x] `proof-forge-artifact.json` records `target: "solana-sbpf-asm"`.
- [ ] `sbpf` installed to PATH via `cargo install` (currently built from source).

Reference: [solana-sbpf-asm design doc](targets/solana-sbpf-asm.md),
[RFC 0005](rfcs/0005-solana-sbpf-assembly-backend.md).

## Workstream 7: Solana sBPF Assembly Counter Codegen (Phase 1)

Goal: lower the portable IR Counter module to sBPF assembly and pass `sbpf test`.
This is the first real codegen backend for the assembly route.

Tasks:

- Implement `ProofForge.Backend.Solana.StateLayout` — compute per-account field
  offsets from the instruction manifest; emit `.equ` constants.
- Implement `ProofForge.Backend.Solana.SbpfAsm` — lower `IR.Module` to `.s`:
  - Entrypoint adapter: parse serialized accounts, dispatch on instruction
    discriminant.
  - Account validation: signer, writable, owner checks per manifest.
  - Expression lowering: literals, locals, add/sub, comparisons, casts.
  - Statement lowering: letBind, assign, assignOp, ifElse, return, assert.
  - Effect lowering: storageScalar read/write at account-data offsets.
- Add `--solana-elf` CLI mode: emit `.s` then invoke `sbpf build`.
- Generate instruction manifest (`manifest.toml`) alongside the `.s`.
- Create `Examples/Solana/Counter.lean` + manifest.
- Run `sbpf test` (Mollusk) and a Surfpool/Web3.js live deployment smoke.

Acceptance criteria:

- Counter scenario (initialize, increment, get) passes `sbpf test`.
- Surfpool/Web3.js live smoke passes (optional, gated on tool availability).
- Capability checker rejects IR modules using unsupported capabilities with a
  clear diagnostic citing target id and capability id.
- Same portable IR Counter module lowers to both EVM and Solana.
- Artifact metadata records `target: "solana-sbpf-asm"`, `irVersion`,
  entrypoints, and capabilities used.

Out of scope (Phase 2+): maps, struct types, events, bounded loops, Borsh
serialization, full SPL Token data layouts, complete live CPI matrix coverage,
and Rust/Pinocchio equivalence. CPI and PDA stay Solana-specific (D-027): the
SDK routes them through target capability calls and sBPF helper actions instead
of adding them to the portable IR.

Reference: [solana-sbpf-asm design doc](targets/solana-sbpf-asm.md) § Phased
Implementation Plan.

### Phase 1 progress (incremental sub-items)

The Workstream 7 Phase 1 backend (`ProofForge.Backend.Solana.SbpfAsm`) lands
incrementally. Each sub-item carries its own runnable validation gate so
partial progress is visible before the full acceptance criteria close:

- [x] IR → sBPF AST → text pipeline; entrypoint adapter dispatches on the
      first instruction-data byte (V-GATE-SOLANA-01/02; Phase 0 baseline).
- [x] Counter codegen (literals, locals, `add`, scalar storage
      read/write/`assignOp`, `letBind`/`letMutBind`, `assign`, `return`);
      Mollusk smoke covers initialize / increment 0→1 / increment 5→6 /
      get→return_data (V-GATE-SOLANA-03).
- [x] Control-flow + assertion coverage: comparison expressions
      (`.eq`/`.ne`/`.lt`/`.le`/`.gt`/`.ge`), boolean expressions
      (`.boolAnd`/`.boolOr`/`.boolNot`), statement-level `.ifElse` then/else
      lowering with fresh named labels, `.assert` and `.assertEq` lowering to
      the shared `assert_fail` (exit 2) / `assert_eq_fail` (exit 3) labels.
      Fixture: `ProofForge.IR.Examples.ControlFlowAssertProbe` (three
      entrypoints: `lifecycle`, `guarded_increment`, `equality_guard`);
      CLI mode `--emit-control-ir-sbpf`; deterministic emission gate
      `scripts/solana/emit-control-smoke.sh` (no `sbpf` required); Mollusk
      runtime gate `scripts/solana/control-smoke.sh` (six checks: lifecycle
      x2, guarded_increment success + assert revert, equality_guard success
      + assertEq revert) (V-GATE-SOLANA-08).
- [x] Instruction manifest (`manifest.toml`) generation alongside the `.s`.
      `ProofForge.Backend.Solana.SbpfAsm.renderManifest` emits a TOML with
      target, program placeholder id, and per-entrypoint instruction tables
      using the Phase 1 default account convention (writable, signer=false,
      owner=program). `--emit-counter-ir-sbpf` and `--emit-control-ir-sbpf`
      write `manifest.toml` next to the `.s` and include it as an artifact.
- [x] `--solana-elf` CLI mode: emits `.s`, writes `manifest.toml`, scaffolds an
      `sbpf` project, invokes `sbpf build`, copies the resulting `.so` to the
      requested output, and records `sbpfBuild: passed` in artifact metadata.
- [x] Account validation: signer / writable / owner checks per manifest. Each
      entrypoint emits a prologue that checks `is_writable` at account-header
      offset 10 and verifies the account owner equals the serialized program
      id. Failure exits are 4 (`error_not_writable`), 5 (`error_signer`), and
      6 (`error_owner`). Phase 1 Mollusk runtime gates disable the
      direct-account-mapping ABI so the legacy embedded account-data layout
      is exercised.
- [x] `Examples/Solana/Counter.lean` + manifest as a self-contained example.
      Includes a tracked `Counter.golden.s` and `Counter.manifest.toml` and a
      CI-runnable `scripts/solana/build-examples.sh` that emits and diffs.
- [x] Capability checker rejects unsupported capability/target combinations
      with a clear diagnostic citing target id and capability id. Basis for
      V-GATE-SOLANA-05; exercised by `Tests/SolanaDiagnostics.lean` and
      `scripts/solana/diagnostic-smoke.sh`.
- [x] Solana SDK target extensions route `ProofForge.Solana` PDA/CPI APIs
      through capability plan metadata, emit `manifest.toml` extension
      definitions plus entrypoint action sections, and inject handler-level
      helper calls (`sol_pda_derive_<name>`, `sol_cpi_<name>`) before the IR
      body while preserving the Solana input pointer in `r1`. Covered by
      `Tests/SolanaSdk.lean`, `Tests/SolanaSdkManifest.lean`, and
      `scripts/solana/sdk-smoke.sh` with `sbpf build` when available.
- [x] Surfpool/Web3.js live deployment smoke (V-GATE-SOLANA-04). The optional
      `scripts/solana/surfpool-web3-smoke.sh` gate builds the Counter ELF,
      starts Surfpool, deploys with the Solana CLI, creates a program-owned
      counter account via `@solana/web3.js`, invokes initialize/increment/get,
      checks account data 0→1→2, and validates `get` return data. The script
      passes `--solana-sbpf-arch v0` to produce a Solana CLI deploy-compatible
      ELF directly and uses `--use-rpc` for Surfpool.
- [x] `--solana-elf` exposes `--solana-sbpf-arch v0|v3` and records the chosen
      architecture in `proof-forge-artifact.json`. Default stays `v3`; Surfpool
      live deployment uses `v0` until the deployed CLI/runtime stack accepts
      the newer sbpf feature set without `--skip-feature-verify`.
- [x] PDA helper runtime packing now emits static ASCII seed byte buffers, Solana
      `Slice { ptr, len }` seed tables, dynamic program-id pointer calculation,
      and a 32-byte PDA result buffer before calling `sol_create_program_address`.
      Covered by `Tests/SolanaSdkManifest.lean` and
      `scripts/solana/sdk-smoke.sh`.
- [x] PDA typed seed lowering now keeps the compatibility `seeds` field while
      adding target-facing typed descriptors for literal/UTF-8 bytes, account
      pubkeys, bump seeds, and scalar instruction-data seeds. The Solana target
      extension consumes those descriptors, appends `bump?` to the effective
      syscall seed list, emits `typed_seeds`/`typedSeeds` in manifest/artifact
      metadata, and validates the derived PDA pubkey against the declared
      account when `account?` is present. Covered by `Tests/SolanaSdk.lean`,
      `Tests/SolanaSdkManifest.lean`, `Tests/SolanaPdaSeeds.lean`,
      `scripts/solana/sdk-smoke.sh`, and
      `scripts/solana/pda-web3-smoke.sh`.
- [x] Standard Solana protocol SDK helpers now cover System Program
      transfer/create-account and SPL Token transfer_checked/mint_to/burn/
      approve/revoke. They route through target capability metadata with
      `solana.cpi.protocol`, canonical `data_layout`, account metas, signer
      seeds, and instruction-data source names, and are included in the
      generated manifest plus artifact JSON. Covered by `Tests/SolanaSdk.lean`,
      `Tests/SolanaSdkManifest.lean`, and `scripts/solana/sdk-smoke.sh`.
- [x] Runtime allocator target extension now models Solana's default
      downward-bump allocator (`heap_start = "0x300000000"`,
      `heap_bytes = 32768`) plus a `noAllocator`/deny-dynamic option aligned
      with Pinocchio-style no-heap entrypoints. The selected allocator routes
      through `runtime.allocator` capability metadata and appears in
      `manifest.toml`, `proof-forge-artifact.json`, and assembly metadata.
      Covered by `Tests/SolanaAllocator.lean`, `Tests/SolanaSdk.lean`,
      `Tests/SolanaSdkManifest.lean`, and `scripts/solana/sdk-smoke.sh`.
- [x] Runtime memory target extension now routes Solana-only SDK actions through
      `runtime.memory` capability metadata and lowers entrypoint actions to
      `sol_memcpy_`, `sol_memcmp_`, and `sol_memset_` helpers over generated
      state-account offsets. The generated manifest and artifact JSON record
      `[[solana.entrypoint_memory]]` / `memoryActions`; Web3.js verifies copied
      bytes, compare result, and fill pattern on a program-owned account.
      Covered by `Tests/SolanaMemory.lean` and
      `scripts/solana/memory-web3-smoke.sh`.
- [x] Return-data and compute-budget target extensions now route Solana-only
      SDK actions through `runtime.return_data` and `runtime.compute_units`
      capability metadata. Return-data actions lower state-backed byte slices
      to `sol_set_return_data` and can read the most recent CPI return-data
      buffer/program id through `sol_get_return_data`; compute-budget actions
      lower the feature-gated `sol_remaining_compute_units` syscall and write
      the observed remaining CU value into state, and profiling actions lower
      `sol_log_compute_units_`. The generated manifest records
      `[[solana.entrypoint_return_data]]` and
      `[[solana.entrypoint_compute_units]]`. Covered by
      `Tests/SolanaReturnDataCompute.lean`.
- [x] Generated Solana SDK instruction schemas now use a module-wide
      multi-account account list instead of the old single-account manifest.
      The schema includes the state account, PDA accounts, CPI accounts, and
      executable CPI program accounts, and the sBPF backend computes
      `INSTRUCTION_DATA` offsets from that same schema. The generated prologue
      validates signer/writable constraints and program-owned accounts from the
      schema. The account list is emitted in both `manifest.toml` and
      `proof-forge-artifact.json`. Covered by `Tests/SolanaSdkManifest.lean`,
      `Tests/SolanaCpiPacking.lean`, and `scripts/solana/sdk-smoke.sh`.
- [x] System Program transfer/create-account and SPL Token CPI instruction-data
      packing emit the standard instruction bytes into the C `SolInstruction`
      payload. System transfer/create-account use bincode-style `u32`
      discriminators plus `u64` lamports/space and owner pubkey fields; SPL
      Token `transfer_checked`, `mint_to`, `burn`, `approve`, and `revoke` use
      the standard token instruction tags and amount/decimals layouts. Value
      sources can bind to generated scalar state offsets, numeric literals, or
      decoded scalar entrypoint parameters. The CPI helper also packs program id
      bytes, C `SolAccountMeta[]`,
      `SolAccountInfo[]` entries bound to the generated multi-account input
      layout, signer seed tables, and syscall register setup. Covered by
      `Tests/SolanaCpiPacking.lean`, `Tests/SolanaSdkManifest.lean`, and
      `scripts/solana/sdk-smoke.sh`.
- [x] System Program transfer CPI now has a live Surfpool/Web3.js behavior
      gate. `ProofForge.Solana.Examples.SystemCpi` builds a generated
      `--solana-system-cpi-elf` fixture whose entrypoint reads a scalar
      `lamports` instruction parameter, performs a System Program transfer CPI,
      and records the transferred amount in a program-owned state account.
      `scripts/solana/system-cpi-web3-smoke.sh` validates the artifact schema,
      deploys the ELF on Surfpool with Solana CLI, invokes it through
      `@solana/web3.js`, and checks both recipient lamport delta and state data.
      The sBPF lowering computes the instruction-data pointer from the
      serialized account layout under direct account mapping and keeps it in
      `r9` so internal helper calls do not lose it across callee stack frames.
      Coverage: `just solana-system-cpi-web3` / V-GATE-SOLANA-10.
- [x] System Program `create_account` CPI now has a live Surfpool/Web3.js
      behavior gate. `ProofForge.Solana.Examples.SystemCreateAccountCpi`
      builds a generated `--solana-system-create-account-cpi-elf` fixture whose
      entrypoint reads scalar `lamports` and `space` instruction parameters,
      performs a System Program `create_account` CPI with payer and new-account
      signers, creates a program-owned account, and records both values in the
      existing program-owned state account. The Web3.js harness checks the new
      account owner, data length, lamports, and recorded state values. Coverage:
      `just solana-system-create-account-cpi-web3` / V-GATE-SOLANA-11.
- [x] SPL Token `transfer_checked` CPI now has a live Surfpool/Web3.js behavior
      gate. `ProofForge.Solana.Examples.SplTokenTransferCheckedCpi` builds a
      generated `--solana-spl-token-transfer-cpi-elf` fixture whose entrypoint
      reads a scalar `amount` instruction parameter, performs an SPL Token
      `transfer_checked` CPI with the source authority signer, and records the
      amount in program-owned state. The Web3.js harness creates a mint plus
      source/destination token accounts through `@solana/spl-token`, checks the
      token balance deltas, and checks the state record. The sBPF lowering now
      builds a runtime account pointer table in each entry/helper stack frame so
      variable-size SPL Token account data does not invalidate account offsets
      across internal helper calls. Coverage:
      `just solana-spl-token-transfer-cpi-web3` / V-GATE-SOLANA-12.
- [x] Entry instruction-data decoding now treats byte 0 as the entrypoint tag
      and decodes packed scalar parameters from `instruction_data+1` into
      stack locals. The initial scalar ABI supports `U64`, `U32`, and `Bool`,
      emits per-entrypoint parameter schemas and minimum instruction-data
      lengths in `manifest.toml`/`proof-forge-artifact.json`, rejects short
      payloads with `error_instruction_data`, and exposes the same fixed input
      offsets to CPI value bindings, so SDK calls such as SPL Token
      `transfer_checked` can source `amount` from a user instruction parameter
      instead of a placeholder. Covered by `Tests/SolanaCpiPacking.lean`,
      `Tests/SolanaSdkManifest.lean`, and `scripts/solana/sdk-smoke.sh`.

### Solana SDK completion roadmap

Reference docs driving this roadmap:

- Solana CPI and PDA docs:
  <https://solana.com/docs/core/cpi> and
  <https://solana.com/docs/core/pda>.
- Anchor CPI/account-constraint docs:
  <https://www.anchor-lang.com/docs/basics/cpi> and
  <https://www.anchor-lang.com/docs/references/account-constraints>.
- Pinocchio no-dependency / no-std program model:
  <https://docs.rs/pinocchio> and
  <https://github.com/anza-xyz/pinocchio>.

Baseline: as of 2026-07-02, the Solana path has direct sBPF assembly emission,
Counter deployment through Surfpool/Web3.js, SDK capability metadata, generated
manifest/artifact output, module-wide multi-account schemas, standard
System/SPL Token CPI data packing, bump-allocator metadata, scalar entrypoint
parameter decoding, typed PDA seed lowering, live System Program transfer plus
create-account CPI validation, live SPL Token `transfer_checked` CPI
validation, and live SPL Token `mint_to`/`burn`/`approve`/`revoke` CPI
validation, plus live scalar `events.emit` log validation through
`sol_log_64_`, live account-pubkey log validation through `sol_log_pubkey`,
live state-backed data-log validation through `sol_log_data`, and live
`Clock.slot` sysvar validation for `contextRead checkpointId`, plus live
`runtime.memory` validation through `sol_memcpy_`, `sol_memmove_`,
`sol_memcmp_`, and `sol_memset_`, plus live Solana-only `crypto.hash`
validation through `sol_sha256`, `sol_keccak256`, and feature-gated
`sol_blake3`, plus live `Rent.lamports_per_byte_year` sysvar validation
through `sol_get_rent_sysvar`.
It also covers live validation for all current RPC-exposed `EpochSchedule`
fields through `sol_get_epoch_schedule_sysvar`: `slots_per_epoch`,
`leader_schedule_slot_offset`, `warmup`, `first_normal_epoch`, and
`first_normal_slot`, plus live `EpochRewards` validation through
`sol_get_epoch_rewards_sysvar` for
`distribution_starting_block_height`, `num_partitions`,
`parent_blockhash_word0..3`, `total_points_low/high`, `total_rewards`,
`distributed_rewards`, and `active`, plus feature-gated live
`LastRestartSlot.last_restart_slot` validation through `sol_get_sysvar` with
the `SysvarLastRestartS1ot1111111111111111111111` sysvar id. Live SDK
coverage now includes `runtime.return_data` lowering to `sol_set_return_data`
and `sol_get_return_data`, with empty-read, set-return simulation, and
same-instruction set/get roundtrip checks, plus `runtime.compute_units`
lowering to feature-gated `sol_remaining_compute_units` state writes and
profiling logs through `sol_log_compute_units_`.
The estimates below assume one engineer working on this branch,
the current direct-assembly architecture staying stable, and local
`sbpf`/Surfpool/Solana CLI tooling remaining available.

| Level | Estimated effort | Done when |
|---|---:|---|
| SDK alpha: usable Solana programs | 3-5 focused engineering days | Simple programs can use state, PDA seeds, scalar instruction parameters, System Program CPI, SPL Token CPI, logs/return data, and Web3.js behavior tests without hand-written assembly patches. |
| SDK beta: reference-comparable Solana backend | 2-3 focused weeks | ProofForge output is compared against Rust/Pinocchio fixtures for the same account schema, covers key syscalls, validates live CPI behavior, and supports per-entrypoint account schemas. |
| Anchor/Pinocchio-class developer surface | 4-6 focused weeks after beta | The SDK offers account constraints, typed account/data helpers, IDL/client generation, richer SPL/Token-2022 coverage, and stable diagnostics comparable to a framework-level workflow. |

Completed alpha slices:

- Instruction ABI hardening: parameter payload length bounds checks,
  per-entrypoint parameter schemas in `manifest.toml` and
  `proof-forge-artifact.json`, and stable scalar parameter metadata are now in
  place.
- PDA typed seed lowering: `literalSeed`/`utf8Seed`, `accountSeed`,
  `bumpSeed`, and `paramSeed` descriptors now lower to Solana seed slices,
  `bump?` participates in the effective seed list, and declared PDA accounts
  can be checked against the derived pubkey.
- PDA/Web3.js derivation fixture: `scripts/solana/pda-web3-smoke.sh` reads the
  generated SDK Vault `typedSeeds` artifact data and verifies literal/account/
  bump descriptor semantics against `PublicKey.findProgramAddressSync` and
  `PublicKey.createProgramAddressSync`; the harness also covers UTF-8 and
  instruction-parameter resolver behavior.
- Live System Program transfer CPI fixture:
  `scripts/solana/system-cpi-web3-smoke.sh` builds and deploys a generated
  transfer CPI program on Surfpool, invokes it through Web3.js, and proves both
  the lamport movement and state write.
- Live System Program create-account CPI fixture:
  `scripts/solana/system-create-account-cpi-web3-smoke.sh` builds and deploys a
  generated create-account CPI program on Surfpool, invokes it through Web3.js,
  and proves the new account owner/space/lamports plus state writes.
- Live SPL Token transfer-checked CPI fixture:
  `scripts/solana/spl-token-transfer-cpi-web3-smoke.sh` builds and deploys a
  generated transfer_checked CPI program on Surfpool, creates SPL Token test
  accounts with `@solana/spl-token`, invokes it through Web3.js, and proves the
  source/destination token balance deltas plus state writes.
- Live SPL Token ops CPI fixture:
  `scripts/solana/spl-token-ops-cpi-web3-smoke.sh` builds and deploys a
  generated `mint_to`/`burn`/`approve`/`revoke` CPI program on Surfpool,
  validates the generated four-entrypoint artifact schema, creates SPL Token
  test accounts with `@solana/spl-token`, invokes all four generated
  entrypoints through Web3.js, and proves supply/balance/delegate changes plus
  state writes.
- Live scalar event, pubkey log, and data log fixture: `scripts/solana/log-event-web3-smoke.sh`
  builds and deploys a generated `events.emit` program on Surfpool, invokes it
  through Web3.js, verifies the generated `sol_log_64_` transaction log
  contains the stable `AmountEvent` tag and scalar `amount` field, and proves
  the program-owned state account recorded the same value. The same fixture now
  validates Solana-only `logAccountPubkey` metadata, invokes the generated
  `log_state_pubkey` entrypoint, and proves `sol_log_pubkey` logs the state
  account's base58 pubkey. It also validates Solana-only `logStateData`
  metadata, invokes `log_state_data`, and proves `sol_log_data` emits a base64
  `Program data:` payload for the state-backed `amount` bytes.
- Live Clock sysvar fixture: `scripts/solana/clock-sysvar-web3-smoke.sh`
  builds and deploys a generated `contextRead checkpointId` program on
  Surfpool, lowers it to `sol_get_clock_sysvar`, invokes it through Web3.js,
  and proves the recorded `Clock.slot` matches the observed transaction slot.
- Live memory syscall fixture: `scripts/solana/memory-web3-smoke.sh` builds and
  deploys a generated `runtime.memory` program on Surfpool, invokes it through
  Web3.js, and proves `sol_memcpy_`, `sol_memmove_`, `sol_memcmp_`, and
  `sol_memset_` effects by reading copied value, moved value, compare result,
  and fill bytes from program-owned state.
- Return-data/compute-units SDK fixture:
  `Tests/SolanaReturnDataCompute.lean` proves `runtime.return_data` and
  `runtime.compute_units` route through Solana-only capability metadata, rejects
  on EVM, and render manifest sections plus sBPF helper calls for
  `sol_set_return_data`, `sol_get_return_data`, feature-gated
  `sol_remaining_compute_units`, and `sol_log_compute_units_`.
  `scripts/solana/return-data-compute-web3-smoke.sh` builds and deploys the
  generated `--solana-return-data-compute-elf` fixture on Surfpool, validates
  artifact action metadata, verifies no-data `sol_get_return_data` reads,
  confirms `sol_set_return_data` through Web3.js simulation returnData, checks a
  same-instruction set/get roundtrip including program id words, records a
  nonzero remaining-compute-units value, and confirms compute-unit logging.
- Live SHA-256/Keccak-256/Blake3 syscall fixture:
  `scripts/solana/crypto-hash-web3-smoke.sh` builds and deploys a generated
  Solana-only `crypto.hash` program on Surfpool, invokes `set_preimage`,
  `hash_preimage`, `keccak_preimage`, and `blake3_preimage` through Web3.js, and
  proves the account-stored 32-byte digests match Node SHA-256 and
  `@noble/hashes` Keccak-256/Blake3 references for the same little-endian
  preimage. The Blake3 action is recorded as feature-gated in manifest and
  artifact metadata.
- Live Rent sysvar fixture: `scripts/solana/rent-sysvar-web3-smoke.sh` builds
  and deploys a generated Solana-only `sysvar` target-extension program on
  Surfpool, invokes `record_rent` through Web3.js, and proves the recorded
  `Rent.lamports_per_byte_year` matches the Rent sysvar account data.
- Live EpochSchedule sysvar fixture:
  `scripts/solana/epoch-schedule-sysvar-web3-smoke.sh` builds and deploys a
  generated Solana-only `sysvar` target-extension program on Surfpool, invokes
  `record_epoch_schedule` through Web3.js, and proves the recorded
  `EpochSchedule.slots_per_epoch`,
  `EpochSchedule.leader_schedule_slot_offset`, `EpochSchedule.warmup`,
  `EpochSchedule.first_normal_epoch`, and `EpochSchedule.first_normal_slot`
  match RPC `getEpochSchedule()` fields.
- Live EpochRewards sysvar fixture:
  `scripts/solana/epoch-rewards-sysvar-web3-smoke.sh` builds and deploys a
  generated Solana-only `sysvar` target-extension program on Surfpool, invokes
  `record_epoch_rewards` through Web3.js, and proves that
  `sol_get_epoch_rewards_sysvar` records `EpochRewards` fields into state.
  `parent_blockhash` is exposed as four little-endian `u64` word views and
  `total_points` is exposed as low/high `u64` word views until the portable
  scalar layer has first-class wide-value output states.
- Live LastRestartSlot sysvar fixture:
  `scripts/solana/last-restart-slot-sysvar-web3-smoke.sh` builds and deploys a
  generated Solana-only `sysvar` target-extension program on Surfpool, invokes
  `record_last_restart_slot` through Web3.js, and proves the feature-gated
  `LastRestartSlot.last_restart_slot` read lowers through `sol_get_sysvar` and
  matches the LastRestartSlot sysvar account data. The action is marked
  `feature_gated` in manifest and artifact metadata.

Completed beta scaffolding slices:

- Pinocchio System transfer reference contract:
  `references/solana/pinocchio/system-transfer` contains a checked-in
  no-allocator Pinocchio reference for the same System transfer account schema
  as `ProofForge.Solana.Examples.SystemCpi`. The gate
  `scripts/solana/pinocchio-system-transfer-equivalence.sh` emits the
  ProofForge System CPI artifact and compares its instruction tag, parameter
  ABI, account order, signer/writable constraints, CPI protocol/data layout,
  and state-write contract against the reference manifest/source.
- Pinocchio System transfer live-equivalence harness:
  `scripts/solana/pinocchio-system-transfer-live-equivalence.sh` is wired to
  build the ProofForge ELF and the checked-in Pinocchio reference ELF, deploy
  both programs to one Surfpool instance, invoke the same Web3.js transfer
  scenario for each, and compare recipient lamport deltas plus state writes.
  The harness currently skips when `cargo-build-sbf` cannot find Solana rustc/
  platform-tools.
- Pinocchio System create-account reference contract:
  `references/solana/pinocchio/system-create-account` contains a checked-in
  no-allocator Pinocchio reference for the same System Program
  `create_account` account schema as
  `ProofForge.Solana.Examples.SystemCreateAccountCpi`. The gate
  `scripts/solana/pinocchio-system-create-account-equivalence.sh` emits the
  ProofForge create-account CPI artifact and compares its instruction tag,
  two-parameter ABI, account order, signer/writable constraints, CPI
  protocol/data layout, lamports/space/owner contract, and two-field
  state-write contract against the reference manifest/source. With
  `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`, the same gate typechecks the
  reference against `pinocchio-system`.
- Pinocchio SPL Token transfer reference contract:
  `references/solana/pinocchio/spl-token-transfer` contains a checked-in
  no-allocator Pinocchio reference for the same SPL Token `transfer_checked`
  account schema as `ProofForge.Solana.Examples.SplTokenTransferCheckedCpi`.
  The gate `scripts/solana/pinocchio-spl-token-transfer-equivalence.sh` emits
  the ProofForge SPL Token CPI artifact and compares its instruction tag,
  parameter ABI, account order, signer/writable constraints, CPI
  protocol/data layout, decimals/amount contract, and state-write contract
  against the reference manifest/source. With
  `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`, the same gate typechecks the reference
  against `pinocchio-token`.

Completed developer-surface slices:

- Portable ValueVault surface source:
  `ProofForge.Contract.Surface` now lets examples declare state slots,
  parameters, methods, and event fields once, then write entrypoint bodies
  through typed refs (`read`, `write`, `bind`, `emit`, `ret`) instead of raw
  `ContractSpec` string plumbing. `ProofForge.Contract.Examples.ValueVault`
  uses this layer and intentionally leaves `selector? = none` in the source.
- Declaration-derived IR names:
  `state_decl`, `binding_decl`, `method_decl`, `method_return_decl`, and
  `event_decl` macros now derive IR names from Lean declarations, so the
  portable Counter and ValueVault sources no longer repeat raw strings for
  state slots, inputs, locals, method names, or event names. Tests assert the
  derived snake-case state/parameter/method names and PascalCase event names
  before routing the same source across EVM and Solana.
- Source-facing declaration facade:
  `contract_decl Name do ...` derives the module name from a Lean identifier
  and keeps `ContractSpec` as the compiler-owned intermediate product rather
  than the user-visible authoring model. `ProofForge.Contract.Examples.Counter`
  and `ProofForge.Contract.Examples.ValueVault` now use this facade; the older
  `*_ref` macros remain as compatibility shims for older downstream source.
- Contract Source Syntax v1:
  `ProofForge.Contract.Source` adds scoped `contract_source` syntax for
  state declarations, events, entrypoints, queries, source-local bindings,
  state assignment, event emission, returns, typed arithmetic operators, and
  Solana extension declarations for allocator, accounts, PDA derivation, and
  SPL Token CPI calls.
  `ProofForge.Contract.Examples.Counter` and
  `ProofForge.Contract.Examples.ValueVault` now author portable logic through
  this source block while the macro emits the same `ContractSpec`/portable IR
  boundary used by routing, EVM selector hydration, Solana instruction tags,
  IDL, and client artifact generation.
- Learn source parser/lowering seed:
  `ProofForge.Contract.Learn` now lexes and parses checked-in `.learn` files
  under `Examples/Learn/` into a small source AST for the portable scalar/event
  subset, lowers that AST to `ContractSpec`/portable IR, and proves that
  `Counter.learn` and `ValueVault.learn` produce the same IR modules as the
  current `contract_source` examples. The CLI now accepts `.learn` files
  through `--learn --target evm` and `--learn --target solana-sbpf-asm`, with
  `--learn-yul`, `--learn-bytecode`, and `--learn-sbpf` retained as lower-level
  convenience paths.
  `scripts/portable/value-vault-smoke.sh` uses
  `Examples/Learn/ValueVault.learn` as the source of record and proves that the
  Learn-authored contract can route to EVM Yul/bytecode metadata and Solana sBPF
  assembly/manifest/IDL/client artifacts without hand-authoring `ContractSpec`.
- Learn Solana target-extension syntax:
  `ProofForge.Contract.Learn` now parses `SolanaVault.learn` forms for
  `solana allocator`, `solana account`, `solana pda`, `solana cpi
  ... spl_token_transfer_checked(...)`, and entry-level `solana derive` /
  `solana invoke`. The lowering reuses `ProofForge.Solana` builder helpers, so
  account/PDA/CPI metadata still flows through the existing capability plan,
  manifest, IDL, client, and sBPF assembly paths. `Tests/LearnSource.lean`
  checks that Learn-lowered SolanaVault has the same IR module and generated
  manifest as `ProofForge.Solana.Examples.Vault`.
- Learn System Program CPI syntax:
  `SystemCpi.learn` and `SystemCreateAccountCpi.learn` now cover
  `solana cpi ... system_transfer(...)`, `solana cpi ...
  system_create_account(...) owner ...`, and matching entry-level
  `solana invoke` statements. `Tests/LearnSource.lean` proves both Learn files
  lower to the same IR modules and generated manifests as the existing
  `ProofForge.Solana.Examples.SystemCpi` and
  `ProofForge.Solana.Examples.SystemCreateAccountCpi` source examples.
- Learn SPL Token ops syntax:
  `SplTokenOpsCpi.learn` now covers selector-bearing Learn entrypoints plus
  `spl_token_mint_to`, `spl_token_burn`, `spl_token_approve`, and
  `spl_token_revoke` declarations/invocations. `Tests/LearnSource.lean` proves
  the Learn file lowers to the same IR module and generated manifest as
  `ProofForge.Solana.Examples.SplTokenOpsCpi`, keeping the string-heavy Builder
  code as an internal expected fixture rather than the user-facing syntax.
- Learn log/return-data/compute-unit syntax:
  `LogEvent.learn` and `ReturnDataCompute.learn` now cover Solana pubkey/data
  log helper statements, return-data set/get statements, and remaining
  compute-unit read/log statements. `Tests/LearnSource.lean` proves both Learn
  files lower to the same IR modules and generated manifests as
  `ProofForge.Solana.Examples.LogEvent` and
  `ProofForge.Solana.Examples.ReturnDataCompute`, moving another syscall-facing
  SDK slice from Builder-only fixtures into user-facing Learn source.
- Learn memory/crypto/sysvar syntax:
  `Memory.learn`, `Crypto.learn`, `Rent.learn`, `EpochSchedule.learn`,
  `EpochRewards.learn`, `LastRestartSlot.learn`, and `Clock.learn` now cover
  Solana memory helpers, SHA-256/Keccak-256/BLAKE3 helpers, and
  sysvar/context reads in user-facing Learn source. `Tests/LearnSource.lean`
  proves these Learn files lower to the same IR modules and generated
  manifests as the corresponding `ProofForge.Solana.Examples.*` fixtures.
- Learn reference diagnostics:
  `ProofForge.Contract.Learn` now builds a declaration reference index while
  lowering and rejects unknown or mismatched Solana CPI invocations, unknown
  PDA derivations, invalid signer seeds, CPI declarations that use undeclared
  accounts, CPI account declarations that do not satisfy required writable or
  signer constraints, and helper statements that reference undeclared
  state/account names. `Tests/LearnDiagnostics.lean` pins these messages so
  Learn behaves like a checked language frontend instead of asking users to
  hand-author unchecked `ContractSpec` data.
- Solana typed account surface:
  `ProofForge.Solana.Surface` now adds `account_ref`, `pda_ref`, and `cpi_ref`
  declarations plus typed PDA seed, account constraint, and SPL/System CPI
  helpers. `ProofForge.Solana.Examples.Vault` now uses dedicated
  `contract_source` items such as `allocator bump`, `account ... writable`,
  `pda ... seeds [...]`, `cpi ... spl_token_transfer_checked(...)`, `derive
  pda ...`, and `invoke ... spl_token_transfer_checked(...)` instead of raw
  account/PDA/CPI strings or `use`/`do` helper plumbing. The target extension
  emits declared account constraints into `manifest.toml`,
  `proof-forge-artifact.json` (`solanaExtensions.accounts`), and the generated
  account-validation schema.
- System create-account source syntax:
  `ProofForge.Contract.Source` now exposes source-level
  `cpi ... system_create_account(...) owner ...` and
  `invoke ... system_create_account(...) owner ...` forms.
  `ProofForge.Solana.Examples.SystemCreateAccountCpi` uses those forms instead
  of the lower-level builder API while preserving the existing generated
  assembly, manifest, artifact, and Surfpool/Web3.js behavior gate.
- Target-stage ABI selector hydration:
  the Learn/ValueVault CLI emit paths derive EVM selectors from each
  entrypoint's Solidity ABI signature with `cast sig` immediately before EVM
  Yul/bytecode emission, validate any explicit selector against the derived
  value, and keep Solana routing independent by continuing to use target
  instruction tags. `scripts/portable/value-vault-smoke.sh` proves the same
  `.learn` source emits EVM Yul/bytecode metadata plus Solana sBPF
  assembly/manifest/artifact metadata.
- Solana IDL and TypeScript client package output:
  `ProofForge.Backend.Solana.Idl` renders `proof-forge-idl.json` from the same
  instruction/account/PDA/CPI schema used by `manifest.toml` and artifact
  metadata. `ProofForge.Backend.Solana.Client` renders
  `proof-forge-client.ts` with Web3.js `TransactionInstruction` helpers,
  instruction-data encoding, and account-meta construction. Solana package
  printing, `--emit-solana-sdk-sbpf`, `--emit-value-vault-ir-sbpf`, and the
  Solana ELF contract-sdk path now emit and hash both files.

Current boundary:

- `ProofForge.Contract.Learn` is now the first standalone Learn parser/lowering
  seed. It covers the portable Counter/ValueVault subset and the Vault-level
  Solana account/PDA/SPL Token transfer CPI subset, System Program
  transfer/create-account CPI, SPL Token mint/burn/approve/revoke CPI, and
  Solana log/return-data/compute-unit/memory/crypto/sysvar helper statements.
  During lowering, Solana CPI/PDA declarations and entrypoint helper statements
  are cross-checked against declared references. CPI account operands must be
  declared with `solana account ...`; CPI writable/signer requirements are
  checked against those declarations, so the remaining string names are
  compiler-owned identifiers rather than unchecked user-authored specs.
  `ProofForge.Contract.Source` remains the richer embedded macro frontend for
  examples not yet expressed in Learn, but portable ValueVault artifact emission
  now starts from `.learn` and dispatches by compile-time target id. The next
  authoring gap is to extend Learn parsing to typed target-extension forms for
  Token-2022, typed account/data references, and richer Pinocchio-style account
  validation ergonomics, then broaden `--learn --target <id>` package emission
  beyond EVM and Solana sBPF.

Remaining priority slices:

1. Rust/Pinocchio equivalence fixtures (2-4 days): make the System transfer
   live-equivalence harness pass in CI/local environments by installing Solana
   rustc/platform-tools reliably, then extend live dual-deploy equivalence to
   the System create-account and SPL Token transfer_checked references. The
   key comparison points are account order, signer/writable checks, CPI
   instruction data, and observable state changes.
2. Richer structured logs, account data, and typed return helpers (3-5 days):
   extend the current scalar `sol_log_64_`/`sol_log_data` event path to
   string logs, Anchor-style discriminator/Borsh payloads, and indexed event
   forms; add typed return payload helpers beyond `u64`, portable `Expr.hash`
   routing where the hash semantics match the target, and broader account/data
   packing helpers that reuse the new memory/syscall path, with JavaScript
   reference checks.
3. Runtime allocation lowering (1-2 days): route heap-backed SDK structures
   through `runtime.allocator`, emit actual downward bump-pointer allocation
   code when needed, and reject allocation-using structures under
   `noAllocator`.
4. Dynamic per-entrypoint account schemas (3-5 days): replace the current
   module-wide fixed schema with runtime account parsing before dispatch, so
   instruction-data offsets no longer depend on every entrypoint sharing the
   same account list.
5. Token-2022 and richer SPL coverage (3-5 days per iteration): add checked
   mint/burn/approve variants, authority changes, associated-token account
   setup flows, and Token-2022 extension routes without moving those details
   into portable IR.
6. Developer ergonomics and framework surface (3-5 days per iteration): extend
   the new surface layer toward real Learn-level contract syntax with richer
   typed account/data wrappers, richer generated client APIs, broader
   SPL/Token-2022 helper coverage, and diagnostics that map generated assembly
   failures back to SDK declarations.

The fastest credible route to a more complete SDK is therefore: the alpha
observability baseline is now in place, so next close the richer beta syscall
and return-data slices, then remove remaining architecture shortcuts before adding
Anchor/Pinocchio-class ergonomics.

## Workstream 8: Move Source Generation POC (Aptos first)

Goal: avoid pretending Move is another Lean runtime target.

Tasks:

- Define a Move-compatible subset of the portable IR.
- Generate one **Aptos** Move counter package (Sui follows in a separate slice).
- Run `aptos move compile/test`.
- Document verifier restrictions that must feed back into IR design.

Acceptance criteria:

- Generated Aptos Move source compiles.
- Generated package has tests.
- Unsupported Lean constructs fail before codegen.
- Follow-up Sui object POC is documented as a separate milestone.

## Workstream 9: CI Expansion

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: keep CI useful without requiring every external chain tool on day one.

Tasks:

- Keep `lake build` as always-on CI.
- Add EVM smoke only when `solc` and Foundry are available.
- Add optional jobs for CosmWasm, Solana, and Move with clear tool checks.
- Add artifact metadata validation as a tool-independent job.

Acceptance criteria:

- Base CI does not fail because optional chain tools are missing.
- Target-specific CI jobs fail loudly when their toolchain is present but the
  target build fails.
- Metadata schema validation runs without chain tools.

## Workstream 10: Psy DPN ZK Target Spike

Goal: validate a ZK circuit sourcegen target without coupling ProofForge to Psy
compiler internals.

Tasks:

- Done: generate one Counter `.psy` source file from a portable IR fixture.
- Done: add a temporary Dargo package generator in `scripts/psy/counter-smoke.sh`.
- Done: document `dargo test --file` as the first local smoke runner.
- Done: run `dargo compile` with the `psyup` v0.1.0 macOS arm64 toolchain and
  capture DPN circuit JSON.
- Done: run `dargo execute` as a local user/contract session and assert the
  Counter result after two increments.
- Done: call `dargo generate-abi` and capture non-empty ABI JSON.
- Done: emit `proof-forge-artifact.json` with target id `psy-dpn` for Psy smoke
  artifacts.
- Done: add ContextProbe as a non-Counter fixture for parameter lowering and
  context reads.
- Done: add HashProbe for `Hash`, typed hash let-bindings, `hash`, and
  `hash_two_to_one`, aligned with upstream Psy hash tests.
- Done: validate Psy artifact metadata, including hashes, byte sizes,
  capabilities, validation flags, and expected execution results.
- Done: add map/storage-map, assertions, bounded-loop, array, struct,
  aggregate ABI, nested aggregate, storage nested aggregate, U32 arithmetic,
  and bitwise coverage from the upstream `psy-compiler/tests` and
  `psy-precompiles` corpus.
- Done: add U32/Hash limb packing coverage for local arrays and ABI parameters
  from the upstream `psy-precompiles` corpus.
- Done: emit and validate ProofForge deploy manifests for all Dargo-backed Psy
  smoke compile outputs.
- Done: add map storage path coverage for `Map<Hash, Hash, N>` with Dargo
  compile/execute validation.
- Done: add expression-position `storageMapSet` lowering and MapProbe coverage
  for upstream map edge semantics where `set` and repeated `insert` return the
  previous `Hash` value.
- Done: add storage-reference compound assignment coverage for scalar storage
  and generic storage paths with Dargo compile/execute validation.
- Done: add native U32 scalar storage coverage using Psy `pub value: u32`
  storage plus scalar `+=` assignment, with Dargo compile/execute validation.
- Done: add native Bool scalar storage coverage using Psy `pub flag: bool`
  storage plus `bool as Felt` return casts, with Dargo compile/execute
  validation.
- Done: add native Bool fixed-array and storage-array coverage using Psy
  `[bool; N]` literals/indexing plus `pub flags: [bool; N]` storage, with
  Dargo compile/execute validation.
- Done: add native Hash scalar and storage-array coverage using Psy
  `pub root: Hash` and `pub roots: [Hash; N]`, with Dargo compile/execute
  validation.
- Done: add fixed-array equality coverage using Psy `assert_eq`, `==`, and
  `!=` over `[Felt; N]` locals, with Dargo compile/execute validation.
- Done: add U32 storage array coverage using Felt-backed storage plus explicit
  U32 read/write casts, with Dargo compile/execute validation.
- Done: add Felt-backed U32 storage-array path compound assignment lowering as
  explicit read/update/write casts, with Dargo compile/execute validation.
- Done: add native U32 storage struct field path writes, reads, and compound
  assignment coverage, with Dargo compile/execute validation.
- Done: add a Psy IR coverage manifest gate so every portable IR constructor
  must be classified as lowered, validated, unsupported, or structural for the
  Psy backend.
- Done: factor Dargo smoke package generation into a shared writer so every
  Psy smoke creates the same `src/main.psy` and `Dargo.toml` layout before
  metadata validation.
- Done: allow EVM-style entrypoint selectors in the Psy backend as target-specific
  ABI metadata; Psy source generation uses method names only and may record the
  selector in artifact metadata for cross-target traceability.
- Done: validate Psy identifiers and duplicate declarations before source
  generation so invalid names do not fall through to Dargo parser/typechecker
  failures.
- Done: add a generic generated test fallback for valid Psy IR modules that do
  not have fixture-specific assertions, backed by `GenericEntrypointProbe`,
  golden source, Dargo compile/execute validation, ABI generation, deploy
  manifest generation, and artifact metadata validation.
- Convert the deploy manifest path to upstream compressed genesis deploy JSON
  once the Psy tooling exposes a stable boundary, then exercise a local
  node/prover deployment smoke.
- Record Dargo/Psy compiler version or commit once the toolchain exposes a
  stable value.

Acceptance criteria:

- Generated `.psy` source is readable and checked into a golden fixture or
  snapshot.
- `dargo compile` produces a non-empty JSON artifact on a machine with the Psy
  toolchain.
- `dargo execute` returns `result_vm: [2]` for the Counter lifecycle.
- `dargo execute` returns `result_vm: [15]` for ContextProbe's
  `sum_context(2,3)` lifecycle.
- `dargo execute` returns deterministic four-Felt outputs for HashProbe's
  `poseidon_hash` and `poseidon_pair_hash` entrypoints.
- `dargo generate-abi` produces a non-empty ABI JSON artifact.
- `dargo execute` returns `result_vm: [42]` for the generic non-whitelisted
  `GenericEntrypointProbe`.
- Artifact metadata records target id, fixture id, used capabilities, artifact
  paths, hashes, byte sizes, Dargo package source copy, Dargo package manifest,
  and validation status.
- Artifact metadata is machine-validated by the Psy smoke scripts.
- Artifact metadata records Dargo/Psy compiler version or commit once available.
- Unsupported non-circuit-friendly IR nodes fail before source generation.
- CI either pins a known-good `psyup` release or skips this gate clearly when a
  matching toolchain tarball is unavailable.

## Workstream 11: Kaspa Toccata Research Target

Goal: decide whether and how ProofForge should support Kaspa's Toccata
programmability stack without pretending it is an EVM, account-state, or generic
ZK circuit target.

Tasks:

- Done: add a docs-first target note for candidate id `kaspa-toccata`.
- Classify the target as UTXO covenant/based-app research, not
  `zk-circuit-sourcegen`.
- Review candidate capabilities for UTXO state, covenant lineage, transaction
  v1, user lanes, compute budgets, and inline proof verification.
- Decide whether the first spike should generate Silverscript or only produce a
  target manifest around hand-authored covenant source.
- Define a tiny L1 covenant Counter-like scenario with successor-output
  validation.
- Define the minimal artifact metadata shape for covenant source, transaction v1
  manifest, covenant lineage manifest, and optional proof verifier manifest.
- Defer based-app support until the L1 covenant artifact shape is clear.

Acceptance criteria:

- `docs/targets/kaspa-toccata.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish inline ZK verification from `psy-dpn`-style circuit
  source generation.

## Workstream 12: Stellar Soroban Research Target

Goal: decide whether and how ProofForge should support Stellar smart contracts
without treating all Wasm contract chains as one target.

Tasks:

- Done: add a docs-first target note for candidate id `wasm-stellar-soroban`.
- Classify Soroban as a Wasm-host candidate, not a generic Wasm artifact target.
- Decide whether the first spike should generate a native Rust/Soroban package
  or wait for a direct Lean-to-Wasm host bridge.
- Review candidate capabilities for address authorization, contract-account
  authorization, storage TTL, contract spec metadata, and Stellar assets.
- Define a tiny Counter-like scenario that exercises storage and event output.
- Define artifact metadata for Wasm, contract spec, deployment manifest,
  toolchain versions, and validation result.
- Identify the local smoke command set: `stellar contract build`, sandbox or
  testnet deploy, and invoke.

Acceptance criteria:

- `docs/targets/stellar-soroban.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Soroban from NEAR and CosmWasm despite all three using
  Wasm artifacts.

## Workstream 13: Internet Computer Research Target

Goal: decide whether and how ProofForge should support Internet Computer
canisters without treating every Wasm artifact as the same contract target.

Tasks:

- Done: add a docs-first target note for candidate id `wasm-icp-canister`.
- Classify ICP canisters as a Wasm-host candidate, not a generic Wasm artifact
  target.
- Decide whether the first spike should generate a native Motoko/Rust CDK
  package or wait for a direct Lean-to-Wasm canister bridge.
- Review candidate capabilities for Candid, update/query method modes, stable
  memory, orthogonal persistence, principals, cycles, async inter-canister
  calls, canister lifecycle, certified data, and management canister APIs.
- Define a tiny Counter-like scenario with one update method and one query
  method.
- Define artifact metadata for Wasm, Candid, canister manifest, stable-state or
  upgrade policy, toolchain versions, and validation result.
- Identify the local smoke command set: local replica, PocketIC, or ICP CLI
  canister install/call flow.

Acceptance criteria:

- `docs/targets/internet-computer.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish ICP canisters from NEAR, CosmWasm, and Soroban despite
  all using Wasm artifacts.

## Workstream 14: TON TVM Research Target

Goal: decide whether and how ProofForge should support TON smart contracts
without pretending TVM contracts are EVM, Wasm-host, Move, or ZK targets.

Tasks:

- Done: add a docs-first target note for candidate id `ton-tvm`.
- Classify TON as a TVM/Tolk sourcegen candidate.
- Decide whether the first spike should generate Tolk source/package artifacts
  or wait for a lower-level TVM/cell IR.
- Review candidate capabilities for cells, TL-B metadata, inbound messages,
  outbound messages, get methods, action lists, `StateInit`, account status,
  TVM gas, and jetton/token integration.
- Define a tiny Counter-like scenario with one internal message and one get
  method.
- Define artifact metadata for source, TVM/BOC output, interface metadata,
  initial state, message/action schema, toolchain versions, and validation
  result.
- Identify the local smoke command set: Acton/Tolk compile and local test or
  emulator validation.

Acceptance criteria:

- `docs/targets/ton-tvm.md` records the target classification and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish TON TVM from Wasm-host, EVM, Move, and ZK targets.

## Workstream 15: Bitcoin Cash CashScript Research Target

Goal: decide whether and how ProofForge should support Bitcoin Cash smart
contracts without pretending UTXO spend paths are stateful contract method calls.

Tasks:

- Done: add a docs-first target note for candidate id `bch-cashscript`.
- Classify BCH/CashScript as a UTXO script/covenant sourcegen candidate.
- Decide whether the first spike should generate CashScript source/package
  artifacts before any lower-level BCH Script path.
- Review candidate capabilities for UTXO state, P2SH scripts, unlockers,
  transaction introspection, covenants, local state, CashTokens, timelocks,
  signature checks, CashScript artifacts, and transaction-builder validation.
- Define a tiny UTXO spend scenario with at least one contract function and a
  transaction-builder smoke.
- Define artifact metadata for `.cash` source, cashc artifact JSON, bytecode,
  constructor/unlocker manifest, transaction scenario, toolchain versions, and
  validation result.
- Identify the local smoke command set: `cashc`, CashScript SDK,
  `MockNetworkProvider`, and optional chipnet/node-backed validation.

Acceptance criteria:

- `docs/targets/bitcoin-cash-cashscript.md` records the target classification
  and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish BCH/CashScript from EVM, Wasm-host, Move, generic
  Bitcoin, and Kaspa/Toccata targets.

## Workstream 16: Algorand AVM Research Target

Goal: decide whether and how ProofForge should support Algorand smart contracts
without pretending AVM applications are EVM, Wasm-host, Move, Solana, TVM,
UTXO, or ZK circuit targets.

Tasks:

- Done: add a docs-first target note for candidate id `algorand-avm`.
- Classify Algorand as an AVM/TEAL source or package-generation candidate.
- Decide whether the first spike should generate Algorand Python or Algorand
  TypeScript package artifacts before any direct TEAL emitter path.
- Review candidate capabilities for stateful applications, LogicSig programs,
  ARC-4 ABI/app specs, global/local/box storage, transaction groups, resource
  references, inner transactions, Algorand Standard Assets, AVM budget, and
  AlgoKit/Puya artifacts.
- Define a tiny stateful Counter-like application with one update method, one
  read/query path, explicit storage schema, and localnet or simulator-backed
  validation.
- Define artifact metadata for source, approval bytecode, clear-state bytecode,
  optional LogicSig bytecode, ABI/app spec, storage schema, resource references,
  toolchain versions, and validation result.
- Identify the local smoke command set: AlgoKit/Puya compile plus LocalNet or
  simulator-backed create/call/query validation.

Acceptance criteria:

- `docs/targets/algorand-avm.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Algorand AVM from Wasm-host, EVM, Move, Solana, TVM,
  UTXO, and ZK targets.

## Workstream 17: Cardano Plutus/Aiken Research Target

Goal: decide whether and how ProofForge should support Cardano smart contracts
without pretending eUTXO validators are stateful method-call contracts.

Tasks:

- Done: add a docs-first target note for candidate id `cardano-plutus-aiken`.
- Classify Cardano as an eUTXO validator sourcegen candidate.
- Decide whether the first spike should generate Aiken source before any direct
  Plutus/UPLC path.
- Review candidate capabilities for eUTXO state, validator roles, datum,
  redeemer, script context, validity ranges, transaction balancing, native
  tokens, execution units, and Plutus blueprints.
- Define a tiny Counter-like eUTXO state-machine scenario with successor-output
  validation.
- Define artifact metadata for Aiken source, UPLC/Plutus validators, blueprint,
  datum/redeemer schemas, transaction scenario, execution units, toolchain
  versions, and validation result.
- Identify the local smoke command set: Aiken compile/test plus emulator,
  SDK-backed transaction, or cardano-node-backed validation.

Acceptance criteria:

- `docs/targets/cardano-plutus-aiken.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Cardano from EVM, Wasm-host, Move, Solana, TVM, AVM,
  generic Bitcoin, BCH/CashScript, and Kaspa/Toccata targets.

## Workstream 18: Tezos Michelson/LIGO Research Target

Goal: decide whether and how ProofForge should support Tezos smart contracts
without hiding Michelson operation-list semantics behind generic contract calls.

Tasks:

- Done: add a docs-first target note for candidate id `tezos-michelson-ligo`.
- Classify Tezos as a Michelson source/artifact target with LIGO as the first
  sourcegen path.
- Review candidate capabilities for Michelson code, entrypoints, typed
  Micheline storage, `big_map`, operation lists, views, events, tickets,
  Sapling, delegation, gas/storage burn, and LIGO artifacts.
- Define a tiny Counter-like contract with one entrypoint, one view, typed
  storage, and a local test or sandbox validation flow.
- Define artifact metadata for LIGO source, Michelson output, parameter/storage
  schema, operation list, view/event manifest, toolchain versions, and
  validation result.
- Identify the local smoke command set: LIGO compile/test plus Octez sandbox or
  equivalent Tezos local validation.

Acceptance criteria:

- `docs/targets/tezos-michelson-ligo.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Tezos from EVM, Wasm-host, Move, Solana, TVM, AVM, UTXO,
  and ZK targets.

## Workstream 19: Starknet Cairo Research Target

Goal: decide whether and how ProofForge should support Starknet smart contracts
without treating Cairo chain contracts as generic ZK circuits.

Tasks:

- Done: add a docs-first target note for candidate id `starknet-cairo`.
- Classify Starknet as a Cairo/Sierra/CASM sourcegen candidate.
- Review candidate capabilities for Cairo source, Sierra, CASM, class
  declaration, class hash, Starknet ABI, storage, account abstraction, syscalls,
  L1/L2 messaging, Starknet fee/resource constraints, and Starknet Foundry
  validation.
- Define a tiny Counter-like contract with storage, an increment external
  function, a read function, and one event.
- Define artifact metadata for Cairo source, Sierra/CASM artifacts, ABI,
  selector/class-hash metadata, deployment manifest, toolchain versions, and
  validation result.
- Identify the local smoke command set: Scarb build plus `snforge` or
  devnet-backed tests.

Acceptance criteria:

- `docs/targets/starknet-cairo.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Starknet from EVM, Wasm-host, Move, Solana, TVM, AVM,
  UTXO, and `psy-dpn`-style ZK circuit targets.

## Workstream 22: Aleo Leo Research Target

Goal: decide whether and how ProofForge should support Aleo programs without
treating Aleo as only a generic ZK circuit target or confusing Aleo VM with
Algorand AVM.

Tasks:

- Done: add a docs-first target note for candidate id `aleo-leo`.
- Classify Aleo as a ZK application sourcegen candidate with Leo as the first
  source boundary, Aleo Instructions as the lower-level compiler target, and
  Aleo VM bytecode as the deployable execution artifact.
- Review candidate capabilities for Leo source, Aleo Instructions, Aleo VM,
  AVM bytecode, ABI, prover/verifier artifacts, transitions, finalization,
  records, mappings, storage, public/private inputs and outputs, program
  imports/upgrades, execute/deploy transactions, Credits fees, Leo tests, and
  devnet validation.
- Define a tiny Counter-like program with one entry `fn`, one public `mapping`,
  and one `final { }` block.
- Define a second private-record scenario that consumes one encrypted record,
  creates a successor record, and records public/finalization effects only when
  required.
- Define artifact metadata for Leo source, program id/imports, record/mapping
  schemas, finalization manifest, Aleo Instructions, Aleo VM bytecode, ABI,
  prover/verifier artifacts, execute/deploy transaction metadata, toolchain
  versions, and validation result.
- Identify the local smoke command set: `leo build`, `leo test`, optional
  `leo test --prove`, `leo execute --print`, and devnet/devnode-backed deploy
  or execute validation.

Acceptance criteria:

- `docs/targets/aleo-leo.md` records the target classification and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Aleo from `psy-dpn`, Zcash Shielded, Kaspa/Toccata
  inline ZK, Starknet Cairo, Algorand AVM, and generic source-generation
  targets.

## Workstream 20: Bitcoin Script/Miniscript Research Target

Goal: decide whether and how ProofForge should support Bitcoin base-layer
spending policies without pretending Bitcoin Script is a general smart-contract
runtime.

Tasks:

- Done: add a docs-first target note for candidate id
  `bitcoin-script-miniscript`.
- Classify Bitcoin as a limited UTXO spending-policy target through Script,
  Miniscript, descriptors, PSBT, and Bitcoin Core validation.
- Review candidate capabilities for Bitcoin Script, Miniscript, descriptors,
  SegWit, Taproot, Tapscript, witness stacks, sighash modes, hash locks,
  threshold multisig, PSBT flows, standardness, weight/fee constraints, and
  Bitcoin Core regtest validation.
- Define a tiny spending-policy scenario such as "A can spend immediately, or B
  can spend after a relative timelock."
- Define artifact metadata for policy, descriptor, output script, witness
  requirements, PSBT/raw transaction scenario, weight/fee, toolchain versions,
  and validation result.
- Identify the local smoke command set: Bitcoin Core regtest, descriptor import
  or address derivation, PSBT signing/finalization, and `testmempoolaccept` or
  equivalent spend validation.

Acceptance criteria:

- `docs/targets/bitcoin-script-miniscript.md` records the target classification
  and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Bitcoin Script/Miniscript from EVM, Wasm-host, Move,
  Solana, TVM, AVM, Cardano eUTXO, BCH/CashScript, Kaspa/Toccata, and generic
  smart-contract targets.

## Workstream 21: Zcash Shielded Research Target

Goal: decide whether and how ProofForge should support Zcash shielded payments
without treating Zcash as either plain Bitcoin Script or a generic ZK
smart-contract chain.

Tasks:

- Done: add a docs-first target note for candidate id `zcash-shielded`.
- Classify Zcash as a privacy UTXO/ZK payment candidate with transparent
  Zcash flows plus Sapling/Orchard shielded pools.
- Review candidate capabilities for shielded privacy, transparent pool
  crossings, Sapling, Orchard, shielded notes, note commitments, nullifiers,
  commitment tree anchors, Zcash protocol proofs, private witnesses,
  value-balance constraints, viewing keys, unified addresses, privacy policy,
  and zcashd/library validation.
- Define a tiny shielded payment scenario such as "spend one Orchard note,
  create one Orchard note, reveal one nullifier, preserve value balance, and
  pay a transparent fee."
- Define how a JDL-Z11-like script may express `shield`, `spendNote`,
  `createNote`, `revealNullifier`, `selectAnchor`, and `privacyPolicy` while
  rejecting global mutable shielded storage, method dispatch, and arbitrary
  proof verification.
- Define artifact metadata for transparent inputs/outputs, shielded pool,
  note input/output schema, nullifiers, anchors, value balance, witness/proving
  requirements, viewing-key disclosure, toolchain versions, and validation
  result.
- Identify the local smoke command set: zcashd RPC or a compatible Rust
  wallet/protocol library, with an explicit fallback blocker if local proving is
  too heavy for CI.

Acceptance criteria:

- `docs/targets/zcash-shielded.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Zcash from Bitcoin Script/Miniscript, BCH/CashScript,
  Kaspa/Toccata inline ZK, `psy-dpn` circuit sourcegen, and generic smart
  contracts.

## Workstream 23: Multi-Chain Token SDK

Goal: let users describe fungible token intent once, then let `--target`
choose ERC-20 contract generation on EVM or SPL Token / Token-2022 plans on
Solana without exposing chain-specific code at the user-facing SDK layer.

Tasks:

- Done: add RFC 0006, `ProofForge.Contract.Token.TokenSpec`, target token
  plans, and `Tests/TokenSpec.lean`.
- Done: add legacy Learn token intent source syntax,
  `ProofForge.Contract.Token.Learn`,
  `Examples/Learn/ProofToken.learn`, `Examples/Learn/FeeToken.learn`,
  `Tests/TokenLearn.lean`, and `proof-forge --learn-token --target <id>` plan
  emission as a compatibility path into `TokenSpec`.
- Done: add the first EVM ERC-20 artifact emitter for Learn token sources:
  `ProofForge.Contract.Token.Evm`, `Tests/TokenEvm.lean`, standard ERC-20
  selectors/events in metadata, Yul generation, and `solc --strict-assembly`
  bytecode validation through `--learn-token --target evm`.
- Done: add `scripts/portable/learn-token-smoke.sh` / `just
  learn-token-smoke` to validate the EVM ERC-20 token artifact path and the
  Solana Token-2022 plan path from Learn source.
- Done: add `scripts/evm/learn-token-erc20-vm-smoke.sh` / `just
  learn-token-evm-vm` to deploy the generated ERC-20 creation bytecode in an
  EthereumJS VM and validate standard ERC-20 calls, Transfer/Approval topics,
  and insufficient-balance revert behavior.
- Done: implement Solana SPL Token / Token-2022 deployment plan rendering at
  the Lean `TokenSpec` layer. `solanaTokenDeploymentPlan` now records mint
  account creation, associated token accounts, `mint_to`, `transfer_checked`,
  `approve`, `burn`, `revoke`, authority changes, Token-2022 extension
  initialization, Solana program ids, and source documentation references.
- Done: route Token-2022 features such as `transfer_fee`,
  `non_transferable`, `confidential_transfer`, and `transfer_hook` to
  Token-2022 extension metadata rather than custom per-token programs. The
  planner rejects the documented incompatible `transfer_fee` +
  `non_transferable` combination.
- Done: extend `scripts/portable/learn-token-smoke.sh` so the legacy `.learn`
  input path reuses the Lean `TokenSpec` plan, emits both SPL Token and
  Token-2022 structured plan JSON, and validates the plan offline with
  `@solana/spl-token` / `@solana/web3.js` instruction builders.
- Done: add `scripts/solana/token-plan-web3-smoke.sh` / `just
  solana-token-plan-web3` to execute the structured legacy SPL Token plan on
  Surfpool. The live runner creates the mint and associated token accounts,
  mints initial supply, executes the planned `mint_to`, `transfer_checked`,
  `approve`, `burn`, `revoke`, and mint-authority `set_authority` operations,
  and validates balances, supply, delegate state, and authority revocation with
  Web3.js reads.
- Done: add `scripts/solana/token-2022-transfer-fee-web3-smoke.sh` / `just
  solana-token-2022-transfer-fee-web3` to execute the structured Token-2022
  transfer-fee plan on Surfpool. The live runner initializes `TransferFeeConfig`,
  creates Token-2022 associated token accounts, mints initial supply, executes
  `TransferCheckedWithFee`, validates the source balance, recipient net balance,
  and recipient withheld fee, directly withdraws withheld fees from a token
  account, then runs a second transfer, harvests withheld fees to the mint,
  withdraws them from the mint, and validates the fee receiver balance plus
  cleared account/mint withheld amounts with Web3.js reads.
- Done: add `ProofForge.Contract.Token.Examples.SoulboundToken`,
  `Tests/TokenPlanEmit.lean`,
  `scripts/solana/token-2022-non-transferable-web3-smoke.sh`, and `just
  solana-token-2022-non-transferable-web3` to execute a Lean `.lean`
  TokenSpec-backed Token-2022 non-transferable plan on Surfpool. The live
  runner initializes `NonTransferable`, creates Token-2022 associated token
  accounts, mints initial supply, verifies mint/account extensions, proves
  `TransferChecked` is rejected, then burns the token and validates balances
  and supply with Web3.js reads.
- Implement EVM ERC-20 lowering: ABI/selectors, balance/allowance storage,
  total supply, transfer/approve/transferFrom, mint/burn options, events, and
  broader Foundry/Web3 behavior tests.
- Continue Surfpool live validation for Token-2022 extension plans beyond the
  transfer-fee initialization, checked-transfer, direct withdraw, and
  harvest-to-mint withdraw paths plus non-transferable transfer rejection:
  confidential transfer setup and transfer-hook routing.
- Add optional Solana wrapper/authority/transfer-hook program generation for
  custom policies such as capped supply or custom transfer restrictions.
- Extend token-specific artifact metadata with live deployment accounts, tool
  versions, and validation-run results once the Surfpool plan runner lands.

Acceptance criteria:

- A Lean-authored `TokenSpec` has deterministic EVM and Solana token plans; the
  legacy Learn token source lowers to the same `TokenSpec` boundary.
- EVM output emits ERC-20 Yul/bytecode and passes ERC-20 behavior tests using
  standard Web3/Foundry calls.
- Solana output renders structured SPL Token / Token-2022 plans, validates the
  instruction builders offline with `@solana/spl-token`, and now executes the
  legacy SPL Token plan plus the Token-2022 transfer-fee and non-transferable
  plans on Surfpool to create mints and token accounts, mint supply, transfer
  tokens where allowed, validate balances, verify withheld transfer fees,
  collect those fees through both direct account withdraw and harvest-to-mint
  plus mint withdraw, reject non-transferable `TransferChecked`, and burn
  non-transferable supply. Confidential transfer and transfer-hook behavior
  remains follow-up.
- Documentation clearly says Solana does not default to a per-token SPL
  contract; it uses SPL Token / Token-2022 programs by plan and CPI.

## Workstream 24: Architecture Convergence Follow-ups (post-merge)

The 2026-07 branch consolidation merged `solana-supprot`, `lookdown`
(Wasm/NEAR), `aleo-support`, and `cloudflare-support` into the trunk, resolved
the D-025/D-026/D-027 decision-id collisions (NEAR decisions renumbered to
D-029–D-031, Aleo to D-032, Cloudflare to D-033), unified the capability
matrix, and fixed the `IR.Statement.release` semantic conflicts in the EVM
event walker, Leo emitter, and TS emitter. Remaining follow-ups:

Tasks:

- Record the branch policy in `development-standards.md`: chains are
  directories and target ids, not branches; changes to `ProofForge/IR/*`,
  `ProofForge/Target/*`, `ProofForge/Contract/{Spec,Intent,Source}*`,
  `docs/capability-registry.md`, `docs/decisions.md`, and
  `docs/portable-ir.md` land on `main` in standalone PRs.
- Record the i18n rule: feature branches do not touch `docs/zh/*.zh.md` or
  `scripts/i18n/manifest.json`; translation sync runs on `main` only.
- Retire the merged remote branches (`DaviRain-Su/solana-supprot`,
  `DaviRain-Su/lookdown`, `DaviRain-Su/aleo-support`,
  `DaviRain-Su/cloudflare-support`) after the consolidation PR lands.
- Regenerate stale `docs/zh` translations flagged by the post-merge manifest
  (hand-merged decision/capability tables are synced; narrative docs that
  changed under auto-merge should be re-run through `translate-docs.py`).
- Decide whether the Solana bump-allocator selection unifies under the
  merged `TargetProfile.deploymentAllocator?` abstraction or stays
  target-local; record the outcome in `decisions.md`.
- Unify the CI workflow: the merged `.github/workflows/ci.yml` now carries
  EVM, Solana-light, NEAR, and Psy gates; add the Aleo and TS/Cloudflare
  smokes as optional jobs once their toolchains (`leo`, `tsc`/`wrangler`)
  are pinned.
- Naming cleanup: decide the public SDK name, schedule the `Lean.Evm` →
  `ProofForge.*` namespace rename, and enforce the Learn freeze
  ([authoring-model](authoring-model.md)).
- Declare `ContractSpec` → EVM Plan → Yul the EVM product pipeline in
  RFC 0004; label LCNF → `EmitYul` as the Lean-native experimental path.
- Decide whether `wasm-cloudflare-workers` keeps its registry entry under
  `wasmHost` or moves to a distinct off-chain host family (no consensus, no
  on-chain state) so it does not dilute capability semantics; record in
  `decisions.md` alongside D-033.
- Record the phase completion criterion in `decisions.md`: the current
  phase's completion standard is the shared scenario (Counter, then
  ValueVault) passing on `evm`, `solana-sbpf-asm`, and `wasm-near`; until
  then, new research targets add docs only — no registry or capability-file
  changes.

Acceptance criteria:

- `docs/decisions.md` shows one linear decision log (D-001…D-033, no
  duplicate ids) and records the allocator-unification outcome.
- Development standards contain the branch and i18n rules.
- All four merged chain branches are deleted or archived.

## Workstream 25: Formal Verification Roadmap

Goal: convert the platform's core promises into machine-checked theorems,
per [formal-verification.md](formal-verification.md).

Tasks (see the roadmap for full statements):

- FV-1: prove capability routing soundness, rejection completeness, and
  Solana target-extension isolation for `resolveSpec` (D-027/D-028 as
  theorems).
- FV-2: extend `ProofForge/IR/Semantics.lean` beyond the scalar subset
  (maps, arrays, structs, `ifElse`, `boundedFor`, events) and prove
  determinism plus bounded-loop termination.
- FV-3: prove the `IR/Ownership.lean` checker sound against release-aware
  semantics (no use-after-release, no double release), justifying the three
  divergent `release` lowerings (EmitWat allocator, EVM/Psy reject, TS
  no-op).
- FV-4: add an EVM Counter trace obligation mirroring
  `Backend/WasmNear/Refinement.lean`, backed by a Yul-subset interpreter;
  keep Psy/Solana on differential gates until interpreters exist.
- FV-5: state checked-arithmetic overflow/division semantics once in the IR
  value domain and add the overflow branch to backend obligations.
- FV-6: prove `.learn`-vs-`contract_source` lowering equivalence for the
  paired fixture subset (decidable `ContractSpec` equality).
- FV-7: prove Token SDK plan invariants (total feature routing, documented
  incompatibility diagnostics, plan well-formedness).
- FV-8: user-facing contract invariants over IR semantics, ValueVault as the
  worked example.

Acceptance criteria:

- Each landed FV item is a `decide`-checkable theorem or Lean test wired
  into CI, not an external-tool dependency.
- A backend cannot move from Experimental to Supported without its FV-4
  trace obligation and shared-scenario differential gate.

## Suggested Order

0. Architecture convergence follow-ups (Workstream 24) and FV-1/FV-2 from the
   formal verification roadmap (Workstream 25).
1. Target registry (Workstream 1).
2. Portable IR + shared Counter scenario (Workstream 1.5).
3. EVM artifact metadata and deploy manifest (Workstreams 2–3).
4. Wasm runtime split (Workstream 4).
5. **Parallel:** CosmWasm spike (Workstream 5) and Solana sBPF assembly
   toolchain integration (Workstream 6 — D-026 supersedes the old sbpf-linker
   spike).
6. Solana sBPF assembly Counter codegen (Workstream 7 — D-026).
7. Move Aptos POC (Workstream 8).
8. Psy DPN sourcegen spike (Workstream 10) once the IR fixture exists.
9. Kaspa Toccata research target review (Workstream 11) before any registry
   changes.
10. Stellar Soroban research target review (Workstream 12) before any registry
    changes.
11. Internet Computer research target review (Workstream 13) before any registry
    changes.
12. Algorand AVM research target review (Workstream 16) before any registry
    changes.
13. Cardano Plutus/Aiken research target review (Workstream 17) before any
    registry changes.
14. Tezos Michelson/LIGO research target review (Workstream 18) before any
    registry changes.
15. Starknet Cairo research target review (Workstream 19) before any registry
    changes.
16. Aleo Leo research target review (Workstream 22) before any registry
    changes.
17. TON TVM research target review (Workstream 14) before any registry changes.
18. Bitcoin Script/Miniscript research target review (Workstream 20) before any
    registry changes.
19. Zcash Shielded research target review (Workstream 21) before any registry
    changes.
20. Bitcoin Cash CashScript research target review (Workstream 15) before any
    registry changes.
21. Multi-chain Token SDK (Workstream 23) after the EVM and Solana validation
    paths can both run locally.
22. CI target matrix (Workstream 9).
23. Cloud platform design refresh (prerequisite: two+ targets at Experimental
   stage; see [decisions.md](decisions.md)).
