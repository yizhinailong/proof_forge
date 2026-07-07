#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${PF_POWDR_COUNTER_OUT:-$ROOT/build/evm-powdr}"
PROOF_FORGE_BIN="${PROOF_FORGE_BIN:-$ROOT/.lake/build/bin/proof-forge}"

EXPECTED_HEX="5f3560e01c80638129fc1c14603c578063d09de08a14603257636d4ce63c146025575f80fd5b602b6087565b5f5260205ff35b6038605d565b5f80f35b60426046565b5f80f35b5f60c01b60018060401b0360c01b195f5416175f55565b60716001808060401b035f5460c01c166097565b60c01b60018060401b0360c01b195f5416175f55565b60018060401b035f5460c01c1690565b815f1903811160a4570190565b5f80fda164736f6c6343000822000a"
EXPECTED_SHA256="4dba513cc8be1afa39ebf83ce9d042c7db0491bb046ceccd3f126dc9754ed8eb"

mkdir -p "$OUT_DIR"

if [[ ! -x "$PROOF_FORGE_BIN" ]]; then
  echo "proof-forge binary not found: $PROOF_FORGE_BIN" >&2
  echo "run: lake build proof-forge" >&2
  exit 1
fi

"$PROOF_FORGE_BIN" emit --target evm --fixture counter --format bytecode \
  --yul-output "$OUT_DIR/Counter.yul" \
  --artifact-output "$OUT_DIR/Counter.proof-forge-artifact.json" \
  -o "$OUT_DIR/Counter.bin" >/dev/null

actual_hex="$(tr -d '\n[:space:]' < "$OUT_DIR/Counter.bin")"
actual_sha256="$(python3 - "$OUT_DIR/Counter.bin" <<'PY'
from pathlib import Path
import hashlib
import sys

hex_text = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
print(hashlib.sha256(bytes.fromhex(hex_text)).hexdigest())
PY
)"

if [[ "$actual_hex" != "$EXPECTED_HEX" ]]; then
  echo "Counter runtime bytecode drifted from EvmRefinement.counterCompiledRuntimeCode" >&2
  echo "expected sha256(bytes): $EXPECTED_SHA256" >&2
  echo "actual   sha256(bytes): $actual_sha256" >&2
  echo "artifact: $OUT_DIR/Counter.bin" >&2
  exit 1
fi

if [[ "$actual_sha256" != "$EXPECTED_SHA256" ]]; then
  echo "Counter runtime sha256 mismatch" >&2
  echo "expected: $EXPECTED_SHA256" >&2
  echo "actual:   $actual_sha256" >&2
  exit 1
fi

echo "evm-powdr-counter-runtime: Counter runtime matches embedded powdr witness ($actual_sha256)"
