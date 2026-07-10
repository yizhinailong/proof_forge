#!/usr/bin/env bash
# PF-P3-03: clean rebuild either reproduces artifact hashes or fails closed.
#
# Builds product Counter for EVM twice into isolated dirs and compares the
# runtime bytecode + Yul SHA-256 digests. Explains nondeterminism if any.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.foundry/bin:${HOME}/.local/bin:${PATH}"

fail() { echo "rebuild-hash: $*" >&2; exit 1; }

lake build proof-forge >/dev/null

OUT="${PROOF_FORGE_REBUILD_HASH_OUT:-build/rebuild-hash-smoke}"
rm -rf "$OUT"
mkdir -p "$OUT/a" "$OUT/b"

build_once() {
  local dest="$1"
  lake env proof-forge build --target evm --root . \
    --yul-output "$dest/Counter.yul" \
    --artifact-output "$dest/Counter.proof-forge-artifact.json" \
    -o "$dest/Counter.bin" \
    Examples/Product/Counter.lean >/dev/null
  [[ -f "$dest/Counter.bin" ]] || fail "missing $dest/Counter.bin"
  [[ -f "$dest/Counter.yul" ]] || fail "missing $dest/Counter.yul"
}

build_once "$OUT/a"
build_once "$OUT/b"

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

bin_a="$(sha_file "$OUT/a/Counter.bin")"
bin_b="$(sha_file "$OUT/b/Counter.bin")"
yul_a="$(sha_file "$OUT/a/Counter.yul")"
yul_b="$(sha_file "$OUT/b/Counter.yul")"

echo "rebuild-hash: bin_a=$bin_a"
echo "rebuild-hash: bin_b=$bin_b"
echo "rebuild-hash: yul_a=$yul_a"
echo "rebuild-hash: yul_b=$yul_b"

[[ "$bin_a" == "$bin_b" ]] || fail "Counter.bin hashes differ across clean rebuilds (nondeterminism)"
[[ "$yul_a" == "$yul_b" ]] || fail "Counter.yul hashes differ across clean rebuilds (nondeterminism)"

# Provenance: lean pin recorded (PF-P3-03).
pin="$(tr -d '[:space:]' < lean-toolchain)"
python3 - "$OUT/a/Counter.proof-forge-artifact.json" "$pin" <<'PY'
import json, sys
art, pin = sys.argv[1], sys.argv[2]
data = json.load(open(art))
bundle = data.get("artifactBundle") or {}
tools = bundle.get("toolchain") if isinstance(bundle, dict) else None
if not tools:
    tools = data.get("toolchain") or []
found = False
if isinstance(tools, list):
    for t in tools:
        if isinstance(t, dict) and t.get("tool") == "lean" and pin in str(t.get("version") or ""):
            found = True
if not found:
    raise SystemExit(f"lean pin {pin!r} missing from artifact toolchain: {tools!r}")
print(f"rebuild-hash: lean pin ok ({pin})")
PY

echo "rebuild-hash: ok (EVM Counter.bin + Counter.yul reproduce; lean pin recorded)"
