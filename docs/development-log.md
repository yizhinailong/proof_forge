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

- This covers native scalar `bool` storage only. Bool storage arrays remain
  rejected until a dedicated Psy storage-array idiom is validated.

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
- Fixed-array equality through `==` is intentionally rejected for now; compare
  fixed-array elements explicitly until direct array equality is covered by a
  Dargo-backed fixture.

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
  package, runs `dargo test --file`, `dargo compile`, two `dargo execute`
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
