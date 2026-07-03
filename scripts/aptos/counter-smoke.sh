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

echo "[aptos-smoke] compiling Move package"
aptos move compile --package-dir "$OUTPUT_DIR" --named-addresses "proof_forge=${ADDRESS}"

echo "[aptos-smoke] running Move unit tests"
aptos move test --package-dir "$OUTPUT_DIR" --named-addresses "proof_forge=${ADDRESS}"

echo "[aptos-smoke] Aptos Counter smoke completed successfully"
