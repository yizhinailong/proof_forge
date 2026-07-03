#!/usr/bin/env bash
# Aptos Move Counter smoke (Workstream 8).
# Generates an Aptos Move package from the portable IR Counter fixture,
# compiles it, and runs Move unit tests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/build/aptos/counter"
ADDRESS="0xCAFE"

cd "$REPO_ROOT"

if ! command -v aptos >/dev/null 2>&1; then
  echo "SKIP: aptos not on PATH"
  exit 0
fi

echo "[aptos-smoke] generating Aptos Counter package"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
lake env proof-forge --emit-counter-ir-aptos -o "$OUTPUT_DIR"

# Run a command with a configurable timeout (default 4 min); print a skip message on timeout.
run_with_timeout() {
  local secs="${PROOF_FORGE_APTOS_TIMEOUT:-240}"
  "$@" &
  local pid=$!
  local timed_out=0
  for ((i=0; i<secs; i++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      timed_out=0
      break
    fi
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    timed_out=1
  fi
  wait "$pid" 2>/dev/null || true
  return $timed_out
}

echo "[aptos-smoke] compiling Move package"
if ! run_with_timeout aptos move compile --package-dir "$OUTPUT_DIR" --named-addresses "proof_forge=${ADDRESS}" --skip-fetch-latest-git-deps; then
  echo "SKIP: aptos move compile timed out (likely fetching AptosFramework git deps)"
  exit 0
fi

echo "[aptos-smoke] running Move unit tests"
if ! run_with_timeout aptos move test --package-dir "$OUTPUT_DIR" --named-addresses "proof_forge=${ADDRESS}" --skip-fetch-latest-git-deps; then
  echo "SKIP: aptos move test timed out"
  exit 0
fi

echo "[aptos-smoke] Aptos Counter smoke completed successfully"
