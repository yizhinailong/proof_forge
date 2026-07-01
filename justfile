set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available ProofForge development commands.
default:
    @just --list

# Build the Lean package and proof-forge executable.
build:
    lake build

# Check the target registry smoke.
target-registry:
    lake env lean --run Tests/TargetRegistry.lean

# Check translated documentation freshness.
docs-check:
    scripts/i18n/check-sync.sh

# Run the fast local baseline used before broader target smokes.
check: build target-registry docs-check evm-diagnostics evm-coverage psy-diagnostics psy-coverage

# Check generated Psy golden sources that CI tracks without requiring dargo.
psy-golden-sources:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p build/psy
    fixtures=(
      "counter:Counter"
      "event:EventProbe"
      "crosscall:CrosscallProbe"
      "expression-predicate:ExpressionPredicateProbe"
      "generic-entrypoint:GenericEntrypointProbe"
      "arithmetic:ArithmeticProbe"
      "bitwise:BitwiseProbe"
      "conditional:ConditionalProbe"
      "u32-arithmetic:U32ArithmeticProbe"
      "u32-hash-packing:U32HashPackingProbe"
      "u32-storage-scalar:U32StorageScalarProbe"
      "bool-storage-scalar:BoolStorageScalarProbe"
      "bool-storage-array:BoolStorageArrayProbe"
      "u32-storage-array:U32StorageArrayProbe"
      "context:ContextProbe"
      "hash:HashProbe"
      "hash-storage:HashStorageProbe"
      "map:MapProbe"
      "assert:AssertProbe"
      "loop:LoopProbe"
      "array:ArrayProbe"
      "struct:StructProbe"
      "struct-array:StructArrayProbe"
      "abi-aggregate:AbiAggregateProbe"
      "nested-aggregate:NestedAggregateProbe"
      "storage-nested-aggregate:StorageNestedAggregateProbe"
    )
    for spec in "${fixtures[@]}"; do
      IFS=: read -r flag fixture <<< "$spec"
      lake env proof-forge "--emit-${flag}-ir-psy" -o "build/psy/${fixture}.psy"
      diff -u "Examples/Psy/${fixture}.golden.psy" "build/psy/${fixture}.psy"
    done

# Run Psy unsupported-shape diagnostic smoke.
psy-diagnostics:
    scripts/psy/diagnostic-smoke.sh

# Check the Psy portable IR coverage manifest.
psy-coverage:
    scripts/psy/check-ir-coverage-manifest.py

# List available Psy smoke fixture names for `just psy-smoke <name>`.
psy-smokes-list:
    @for script in scripts/psy/*-smoke.sh; do basename "$script" | sed 's/-smoke\.sh$//'; done | sort

# Run one Psy smoke fixture, for example `just psy-smoke counter`.
psy-smoke fixture:
    @script="scripts/psy/{{fixture}}-smoke.sh"; \
      if [[ ! -f "$script" ]]; then \
        echo "unknown Psy smoke fixture '{{fixture}}'" >&2; \
        echo "run: just psy-smokes-list" >&2; \
        exit 2; \
      fi; \
      "$script"

# Run all Dargo-backed Psy smokes. Requires dargo on PATH.
psy-all:
    #!/usr/bin/env bash
    set -euo pipefail
    fixtures=(
      counter
      expression-predicate
      arithmetic
      u32-arithmetic
      bitwise
      u32-hash-packing
      u32-storage-scalar
      bool-storage-scalar
      bool-storage-array
      u32-storage-array
      conditional
      context
      event
      crosscall
      generic-entrypoint
      hash
      hash-storage
      map
      assert
      loop
      array
      struct
      struct-array
      abi-aggregate
      nested-aggregate
      storage-nested-aggregate
    )
    for fixture in "${fixtures[@]}"; do
      just psy-smoke "$fixture"
    done

# Run EVM unsupported-shape diagnostic smoke.
evm-diagnostics:
    scripts/evm/diagnostic-smoke.sh

# Check the EVM portable IR coverage manifest.
evm-coverage:
    scripts/evm/check-ir-coverage-manifest.py

# List available EVM IR smoke fixture names for `just evm-smoke <name>`.
evm-smokes-list:
    @for script in scripts/evm/*-ir-smoke.sh scripts/evm/ir-counter-smoke.sh; do basename "$script" | sed 's/-ir-smoke\.sh$//;s/-smoke\.sh$//'; done | sort

# Run one EVM IR smoke fixture, for example `just evm-smoke abi-scalar`.
evm-smoke fixture:
    @script="scripts/evm/{{fixture}}-ir-smoke.sh"; \
      if [[ "{{fixture}}" == "ir-counter" ]]; then script="scripts/evm/ir-counter-smoke.sh"; fi; \
      if [[ ! -f "$script" ]]; then \
        echo "unknown EVM smoke fixture '{{fixture}}'" >&2; \
        echo "run: just evm-smokes-list" >&2; \
        exit 2; \
      fi; \
      "$script"

# Build all SDK EVM examples and validate their metadata.
evm-build-examples:
    scripts/evm/build-examples.sh

# Run the Foundry EVM runtime smoke suite.
evm-foundry:
    scripts/evm/foundry-smoke.sh

# Deploy generated Counter initcode to a local Anvil chain and validate a deploy-run artifact.
evm-anvil-deploy:
    scripts/evm/anvil-deploy-smoke.sh

# Run all CI-tracked EVM IR smokes.
evm-ir-smokes:
    #!/usr/bin/env bash
    set -euo pipefail
    fixtures=(
      abi-scalar
      assert
      assignment
      assign-op
      conditional
      loop
      context
      event
      crosscall
      expression
      hash
      map
      typed-map
      storage-array
      storage-struct
      typed-storage
      array-value
      struct-array-value
      struct-value
      abi-aggregate
    )
    for fixture in "${fixtures[@]}"; do
      just evm-smoke "$fixture"
    done

# Run all EVM gates that CI tracks locally.
evm-all: evm-diagnostics evm-coverage evm-ir-smokes evm-build-examples evm-foundry evm-anvil-deploy

# Run the current GitHub CI build-test sequence locally.
ci: build target-registry docs-check psy-golden-sources psy-diagnostics psy-coverage evm-all

# Check for whitespace errors before committing.
diff-check:
    git diff --check
