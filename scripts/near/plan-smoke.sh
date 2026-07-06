#!/usr/bin/env bash
# V-GATE-NEAR-06: NearModulePlan golden smoke.
#
# Builds the NearModulePlan for each fixture and compares it to the golden copy
# at Examples/WasmNear/<Fixture>/golden/plan.txt.
#
# Fixtures (RFC 0014 Phase 4 — Step A type-only stub):
#   Counter — scalar state (the original MVP)
#
# This is the Tier B gate for the NEAR backend's data-layout plan: it validates
# that the plan artifact is stable and deterministic before EmitWat wiring (Step B).
# The plan is NOT wired into EmitWat.lowerModule; it only proves the plan can be
# built deterministically and rendered as a stable text artifact.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

FIXTURES=(
  "Counter"
)

mkdir -p build/wasm-near

echo "=== V-GATE-NEAR-06: NearModulePlan golden smoke ==="

total=${#FIXTURES[@]}
step=0
fail=0

for fixture in "${FIXTURES[@]}"; do
  step=$((step + 1))
  GOLDEN="$REPO_ROOT/Examples/WasmNear/${fixture}/golden/plan.txt"
  OUTPUT="$REPO_ROOT/build/wasm-near/${fixture}.plan.txt"

  if [ ! -f "$GOLDEN" ]; then
    echo "FAIL: golden plan not found: $GOLDEN" >&2
    fail=$((fail + 1))
    continue
  fi

  echo "[${step}/${total}] generating ${fixture} NearModulePlan..."
  if ! lake env lean --run Tests/NearModulePlan.lean "$fixture" "$OUTPUT"; then
    echo "FAIL: plan generation failed for ${fixture}" >&2
    fail=$((fail + 1))
    continue
  fi

  echo "  diff against golden..."
  if ! diff -u "$GOLDEN" "$OUTPUT"; then
    echo "FAIL: generated plan differs from golden for ${fixture}" >&2
    fail=$((fail + 1))
    continue
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "V-GATE-NEAR-06: FAIL (${fail}/${total} fixtures failed)" >&2
  exit 1
fi

echo "V-GATE-NEAR-06: PASS (${total}/${total} fixtures)"