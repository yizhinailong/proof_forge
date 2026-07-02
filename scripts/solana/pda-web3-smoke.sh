#!/usr/bin/env bash
# Solana PDA typed-seed Web3.js derivation smoke.
#
# This optional gate emits the SDK Vault artifact, reads its PDA typed seed
# descriptors, and verifies that the descriptor semantics match the standard
# @solana/web3.js PDA APIs:
#
#   PublicKey.findProgramAddressSync(base seeds, program_id)
#   PublicKey.createProgramAddressSync(base seeds + bump, program_id)
#
# Exit codes:
#   0 — all gates passed
#   1 — a gate failed
#   2 — a prerequisite is missing (skipped)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_SOLANA_PDA_WEB3_OUT:-build/solana-pda-web3}"
ASM_OUTPUT="$OUT_DIR/SolanaVault.s"
ARTIFACT_OUTPUT="$OUT_DIR/proof-forge-artifact.json"
NODE_PROJECT="$OUT_DIR/web3"
JS_TEMPLATE="$REPO_ROOT/Tests/solana/pda_web3_smoke.mjs"
NPM_BIN="${NPM:-npm}"

fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "SKIP: $1" >&2; exit 2; }

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
command -v node >/dev/null 2>&1 || skip "node not on PATH"
command -v "$NPM_BIN" >/dev/null 2>&1 || skip "npm not on PATH (set NPM=/path/to/npm)"
[ -f "$JS_TEMPLATE" ] || fail "Web3.js PDA smoke template not found: $JS_TEMPLATE"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$NODE_PROJECT"

echo "=== Solana PDA Web3.js step 1: emit SDK fixture ==="
lake env proof-forge --emit-solana-sdk-sbpf \
  -o "$ASM_OUTPUT" \
  --artifact-output "$ARTIFACT_OUTPUT" \
  || fail "proof-forge --emit-solana-sdk-sbpf failed"

[ -f "$ARTIFACT_OUTPUT" ] || fail "artifact metadata not written: $ARTIFACT_OUTPUT"

echo "=== Solana PDA Web3.js step 2: install Web3.js harness deps ==="
cp "$JS_TEMPLATE" "$NODE_PROJECT/pda_web3_smoke.mjs"
if [ ! -f "$NODE_PROJECT/package.json" ]; then
  ( cd "$NODE_PROJECT" && "$NPM_BIN" init -y >/dev/null ) \
    || fail "npm init failed"
fi
( cd "$NODE_PROJECT" && "$NPM_BIN" install --silent @solana/web3.js@^1.98.0 ) \
  || fail "npm install @solana/web3.js failed"

echo "=== Solana PDA Web3.js step 3: validate typed seed descriptors ==="
PROOF_FORGE_SOLANA_ARTIFACT="$ARTIFACT_OUTPUT" \
  node "$NODE_PROJECT/pda_web3_smoke.mjs" \
  || fail "PDA Web3.js descriptor validation failed"

echo "=== Solana PDA Web3.js smoke: PASS ==="
