#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACTS_DIR="${CONTRACTS_DIR:-$ROOT/Examples/Evm/Contracts}"
OUT_DIR="${EVM_OUT_DIR:-$ROOT/build/evm}"

mkdir -p "$OUT_DIR"

failures=0
while IFS= read -r -d '' lean_file; do
  name="$(basename "$lean_file" .lean)"
  methods_file="${lean_file%.lean}.evm-methods"
  if [[ ! -f "$methods_file" ]]; then
    continue
  fi
  out="$OUT_DIR/$name.bin"
  if "$ROOT/tools/evmc" "$lean_file" "$out"; then
    :
  else
    echo "build-examples: $name failed" >&2
    failures=$((failures + 1))
  fi
done < <(find "$CONTRACTS_DIR" -name '*.lean' -print0 | sort -z)

if [[ "$failures" -ne 0 ]]; then
  echo "build-examples: $failures contract(s) failed" >&2
  exit 1
fi

echo "build-examples: wrote bytecode to $OUT_DIR"
