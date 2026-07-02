#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACTS_DIR="${CONTRACTS_DIR:-$ROOT/Examples/Evm/Contracts}"
OUT_DIR="${EVM_OUT_DIR:-$ROOT/build/evm}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v cast >/dev/null 2>&1; then
  echo "build-examples: cast not found. Install Foundry, then re-run this script." >&2
  echo "build-examples: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "build-examples: solc not found. Install solc, then re-run this script." >&2
  exit 127
fi

if [[ -n "${PROOF_FORGE_BIN:-}" ]]; then
  proof_forge=("$PROOF_FORGE_BIN")
else
  proof_forge=(lake env proof-forge)
fi

mkdir -p "$OUT_DIR"

# Keep the CLI executable and SDK module fresh when this script is run directly,
# not only through the full CI sequence.
(cd "$ROOT" && lake build proof-forge ProofForge.Evm >/dev/null)

failures=0
while IFS= read -r -d '' lean_file; do
  name="$(basename "$lean_file" .lean)"
  methods_file="${lean_file%.lean}.evm-methods"
  if [[ ! -f "$methods_file" ]]; then
    continue
  fi
  out="$OUT_DIR/$name.bin"
  yul_out="$OUT_DIR/$name.yul"
  golden="${lean_file%.lean}.golden.yul"
  metadata="$OUT_DIR/$name.proof-forge-artifact.json"
  if (
    cd "$ROOT"
    "${proof_forge[@]}" --evm-bytecode --root . --module contract --yul-output "$yul_out" --artifact-output "$metadata" -o "$out" "$lean_file"
    if [[ ! -f "$golden" ]]; then
      echo "build-examples: missing golden Yul: $golden" >&2
      exit 1
    fi
    diff -u "$golden" "$yul_out"
    python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
      --root "$ROOT" \
      --expect-fixture "$name.lean" \
      --expect-source-kind lean-sdk \
      --require-method-signatures \
      "$metadata"
  ); then
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
