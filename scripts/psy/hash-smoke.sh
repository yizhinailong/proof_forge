#!/usr/bin/env bash
set -euo pipefail

# Generate Psy source from the hand-written HashProbe IR and validate
# crypto.hash lowering through Psy's official Dargo toolchain.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${PSY_OUT_DIR:-$ROOT/build/psy}"
PROJECT_DIR="$OUT_DIR/dargo-hash"
PSY_FILE="$OUT_DIR/HashProbe.psy"
GOLDEN_FILE="${PSY_GOLDEN:-$ROOT/Examples/Psy/HashProbe.golden.psy}"
DARGO_BIN="${DARGO:-dargo}"
PSY_HOME="${PSY_HOME:-$HOME/.psy}"
EXEC_LOG="$PROJECT_DIR/target/hash-execute.log"
ABI_FILE="$PROJECT_DIR/target/HashProbe.json"
METADATA_FILE="$PROJECT_DIR/target/proof-forge-artifact.json"
HASH_RESULT="result_vm: [16490263548047147048, 1812405431586978162, 16859324901997577793, 7123796541406703579]"
PAIR_HASH_RESULT="result_vm: [15064728126975588673, 10314245681893968020, 11300930272442645327, 2830815762300183090]"

if [[ -z "${DARGO_STD_PATH:-}" && -f "$PSY_HOME/env" ]]; then
  # psyup writes DARGO_STD_PATH here; sourcing avoids a slow stdlib fallback.
  # shellcheck source=/dev/null
  source "$PSY_HOME/env"
fi

if [[ "$DARGO_BIN" == "dargo" && ! -x "$(command -v dargo 2>/dev/null || true)" && -x "$PSY_HOME/bin/dargo" ]]; then
  DARGO_BIN="$PSY_HOME/bin/dargo"
fi

mkdir -p "$OUT_DIR"

lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" --emit-hash-ir-psy -o "$PSY_FILE"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$PSY_FILE"
fi

if ! command -v "$DARGO_BIN" >/dev/null 2>&1; then
  echo "psy-hash-smoke: dargo not found. Install the Psy toolchain with psyup, then re-run this script." >&2
  echo "psy-hash-smoke: generated $PSY_FILE for inspection." >&2
  echo "psy-hash-smoke: install: curl -fsSL https://raw.githubusercontent.com/QEDProtocol/psyup/main/install.sh | bash" >&2
  echo "psy-hash-smoke: macOS arm64 note: psyup latest may not have a matching tarball; v0.1.0 is known to include one." >&2
  echo "psy-hash-smoke: docs: https://docs.psy-protocol.xyz/language/dargo.html" >&2
  exit 127
fi

"$DARGO_BIN" test --file "$PSY_FILE"

rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/src"
cp "$PSY_FILE" "$PROJECT_DIR/src/main.psy"

cat > "$PROJECT_DIR/Dargo.toml" <<'TOML'
[package]
name = "proof_forge_hash"
version = "0.1.0"
type = "bin"
description = "ProofForge generated HashProbe IR Psy smoke"

[dependencies]
TOML

(
  cd "$PROJECT_DIR"
  "$DARGO_BIN" compile --contract-name HashProbe --method-names poseidon_hash poseidon_pair_hash
  : > "$EXEC_LOG"
  "$DARGO_BIN" execute --contract-name HashProbe --method-names poseidon_hash | tee -a "$EXEC_LOG"
  "$DARGO_BIN" execute --contract-name HashProbe --method-names poseidon_pair_hash | tee -a "$EXEC_LOG"
  "$DARGO_BIN" generate-abi --contract-name HashProbe --output-dir target --pretty
)

ARTIFACT="$PROJECT_DIR/target/proof_forge_hash.json"
if [[ ! -s "$ARTIFACT" ]]; then
  echo "psy-hash-smoke: expected non-empty Dargo artifact at $ARTIFACT" >&2
  exit 1
fi

if ! grep -Fq "$HASH_RESULT" "$EXEC_LOG"; then
  echo "psy-hash-smoke: expected poseidon_hash execute to return $HASH_RESULT" >&2
  echo "psy-hash-smoke: execution log: $EXEC_LOG" >&2
  exit 1
fi

if ! grep -Fq "$PAIR_HASH_RESULT" "$EXEC_LOG"; then
  echo "psy-hash-smoke: expected poseidon_pair_hash execute to return $PAIR_HASH_RESULT" >&2
  echo "psy-hash-smoke: execution log: $EXEC_LOG" >&2
  exit 1
fi

if [[ ! -s "$ABI_FILE" ]]; then
  echo "psy-hash-smoke: expected non-empty Dargo ABI at $ABI_FILE" >&2
  exit 1
fi

python3 "$ROOT/scripts/psy/write-artifact-metadata.py" \
  --root "$ROOT" \
  --fixture HashProbe \
  --source "$PSY_FILE" \
  --circuit-json "$ARTIFACT" \
  --abi-json "$ABI_FILE" \
  --execute-log "$EXEC_LOG" \
  --out "$METADATA_FILE" \
  --dargo "$DARGO_BIN" \
  --execute-result "$HASH_RESULT; $PAIR_HASH_RESULT"

echo "psy-hash-smoke: wrote $PSY_FILE"
echo "psy-hash-smoke: Dargo artifact $ARTIFACT"
echo "psy-hash-smoke: Dargo execute log $EXEC_LOG"
echo "psy-hash-smoke: Dargo ABI $ABI_FILE"
echo "psy-hash-smoke: ProofForge metadata $METADATA_FILE"
