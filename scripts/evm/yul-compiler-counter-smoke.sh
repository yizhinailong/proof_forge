#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${PF_YUL_COMPILER_COUNTER_OUT:-$ROOT/build/evm-yul-compiler}"
PROOF_FORGE_BIN="${PROOF_FORGE_BIN:-$ROOT/.lake/build/bin/proof-forge}"

# Full runtime+metadata bytecode expected by EvmRefinement.counterCompiledRuntimeCode
# (the powdr Counter refinement witness). The metadata suffix depends on the
# solc version/source path, so the gate compares stripped runtime code only.
EXPECTED_FULL_HEX="5f3560e01c80638129fc1c14603c578063d09de08a14603257636d4ce63c146025575f80fd5b602b6087565b5f5260205ff35b6038605d565b5f80f35b60426046565b5f80f35b5f60c01b60018060401b0360c01b195f5416175f55565b60716001808060401b035f5460c01c166097565b60c01b60018060401b0360c01b195f5416175f55565b60018060401b035f5460c01c1690565b815f1903811160a4570190565b5f80fda164736f6c6343000822000a"
EXPECTED_SHA256="4dba513cc8be1afa39ebf83ce9d042c7db0491bb046ceccd3f126dc9754ed8eb"

mkdir -p "$OUT_DIR"

if [[ ! -x "$PROOF_FORGE_BIN" ]]; then
  echo "proof-forge binary not found: $PROOF_FORGE_BIN" >&2
  echo "run: lake build proof-forge" >&2
  exit 1
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "solc not found on PATH" >&2
  echo "install solc 0.8.30 to run the Yul→bytecode verification gate" >&2
  exit 1
fi

"$PROOF_FORGE_BIN" emit --target evm --fixture counter --format bytecode \
  --yul-output "$OUT_DIR/Counter.yul" \
  --artifact-output "$OUT_DIR/Counter.proof-forge-artifact.json" \
  -o "$OUT_DIR/Counter.bin" >/dev/null

solc --strict-assembly "$OUT_DIR/Counter.yul" --bin >"$OUT_DIR/Counter.solc.log" 2>&1

compiled_hex="$(sed -n '/Binary representation:/,$p' "$OUT_DIR/Counter.solc.log" | tail -n +2 | tr -d '\n[:space:]')"

if [[ -z "$compiled_hex" ]]; then
  echo "solc did not emit binary representation (see $OUT_DIR/Counter.solc.log)" >&2
  exit 1
fi

# Strip the CBOR metadata suffix from the CLI bytecode so we compare runtime code
# only. solc --strict-assembly returns runtime code without metadata, while the
# CLI --format bytecode output appends the CBOR metadata + 2-byte length.
strip_metadata() {
  python3 - "$1" <<'PY'
import sys
hex_text = sys.argv[1].strip()
if len(hex_text) < 4:
    print(hex_text)
else:
    meta_len = int(hex_text[-4:], 16)
    total_suffix = (meta_len + 2) * 2
    if len(hex_text) < total_suffix:
        print(hex_text)
    else:
        print(hex_text[:-total_suffix])
PY
}

cli_runtime_hex="$(strip_metadata "$(tr -d '\n[:space:]' < "$OUT_DIR/Counter.bin")")"
expected_runtime_hex="$(strip_metadata "$EXPECTED_FULL_HEX")"

if [[ "$compiled_hex" != "$expected_runtime_hex" ]]; then
  echo "Yul→bytecode compilation drifted from EvmRefinement.counterCompiledRuntimeCode runtime" >&2
  echo "expected runtime: $expected_runtime_hex" >&2
  echo "actual  compiled: $compiled_hex" >&2
  echo "solc log: $OUT_DIR/Counter.solc.log" >&2
  exit 1
fi

if [[ "$cli_runtime_hex" != "$compiled_hex" ]]; then
  echo "CLI bytecode runtime does not match solc --strict-assembly output" >&2
  echo "CLI runtime: $cli_runtime_hex" >&2
  echo "solc output: $compiled_hex" >&2
  exit 1
fi

compiled_sha256="$(python3 - "$EXPECTED_FULL_HEX" <<'PY'
import hashlib
import sys
print(hashlib.sha256(bytes.fromhex(sys.argv[1].strip())).hexdigest())
PY
)"

echo "evm-yul-compiler-counter-smoke: Counter Yul→bytecode via solc reproduces powdr witness runtime (full sha256: $compiled_sha256)"
