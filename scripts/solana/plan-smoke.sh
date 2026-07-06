#!/usr/bin/env bash
# V-GATE-SOLANA-06: SolanaModulePlan golden smoke.
#
# Builds the Solana semantic plan for the Counter fixture and compares it to
# the golden copy at Examples/Solana/Counter/golden/plan.txt.
#
# This is the first Tier B gate for the Solana backend: it validates that the
# semantic plan artifact is stable and deterministic before assembly lowering.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

GOLDEN="$REPO_ROOT/Examples/Solana/Counter/golden/plan.txt"
OUTPUT="$REPO_ROOT/build/solana/Counter.plan.txt"

[ -f "$GOLDEN" ] || { echo "FAIL: golden plan not found: $GOLDEN" >&2; exit 1; }

mkdir -p "$(dirname "$OUTPUT")"

echo "=== V-GATE-SOLANA-06: SolanaModulePlan golden smoke ==="
echo "[1/2] generating Counter SolanaModulePlan..."
lake env lean --run Tests/SolanaModulePlan.lean "$OUTPUT"

echo "[2/2] diff against golden..."
if diff -u "$GOLDEN" "$OUTPUT"; then
  echo "V-GATE-SOLANA-06: PASS"
else
  echo "FAIL: generated plan differs from golden" >&2
  exit 1
fi
