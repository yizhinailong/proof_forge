#!/usr/bin/env bash
# PF-P3-02: six-gate promotion smoke for move-aptos (Counter fixture fragment).
# Product contract_source remains fail-closed until Move package IR lower widens.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.foundry/bin:${HOME}/.elan/bin:${HOME}/.cargo/bin:/opt/homebrew/bin:${PATH}"

OUT="${PROOF_FORGE_APTOS_PROMOTION_OUT:-build/aptos-promotion}"
rm -rf "$OUT"
mkdir -p "$OUT"

fail() { echo "aptos-promotion: $*" >&2; exit 1; }
ok() { echo "aptos-promotion: ok — $*"; }

if ! command -v aptos >/dev/null 2>&1; then
  fail "gate4: aptos CLI not on PATH"
fi

lake build proof-forge >/dev/null

# --- Gate 1: declared fixture input loaded ---
lake env proof-forge emit --target move-aptos --fixture counter --format aptos -o "$OUT/counter" \
  || fail "gate1: fixture counter emit failed"
[[ -f "$OUT/counter/sources/counter.move" ]] || [[ -f "$OUT/counter/sources/Counter.move" ]] \
  || fail "gate1: missing Move source in package"
# Ensure package names counter
if ! find "$OUT/counter" -name '*.move' | head -1 | xargs grep -qi counter; then
  fail "gate1: Move sources lack counter identity"
fi
ok "gate1 fixture counter package"

# --- Gate 2: product source fail-closed ---
set +e
err="$(lake env proof-forge build --target move-aptos --root . \
  -o "$OUT/reject" Examples/Product/Counter.lean 2>&1)"
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "gate2: product Counter source must fail-closed"
echo "$err" | grep -Eqi 'source input is not supported|not supported' \
  || fail "gate2: expected stable unsupported diagnostic, got: $err"
ok "gate2 product source fail-closed"

# --- Gate 3: package layout (Move.toml + sources + tests) ---
[[ -f "$OUT/counter/Move.toml" ]] || fail "gate3: missing Move.toml"
find "$OUT/counter" -name '*test*' -o -name '*Test*' | grep -q . \
  || fail "gate3: missing tests"
ok "gate3 package layout"

# --- Gate 4: aptos toolchain compile ---
ADDRESS="0xCAFE"
aptos move compile --package-dir "$OUT/counter" \
  --named-addresses "proof_forge=${ADDRESS}" --skip-fetch-latest-git-deps \
  || fail "gate4: aptos move compile failed"
ok "gate4 aptos move compile"

# --- Gate 5: runtime semantic (Move unit tests) ---
aptos move test --package-dir "$OUT/counter" \
  --named-addresses "proof_forge=${ADDRESS}" --skip-fetch-latest-git-deps \
  || fail "gate5: aptos move test failed"
ok "gate5 Move unit tests (lifecycle)"

# --- Gate 6: registry / CLI / README ---
python3 - <<'PY' || fail "gate6 surface"
from pathlib import Path
import subprocess
reg = Path("ProofForge/Target/Registry.lean").read_text()
assert 'id := "move-aptos"' in reg
readme = Path("README.md").read_text()
assert "move-aptos" in readme
out = subprocess.check_output(["lake", "env", "proof-forge", "--list-targets"], text=True)
assert "move-aptos" in out
print("registry+CLI+README agree")
PY
ok "gate6 surface agreement"

echo "aptos-promotion: ok (six gates for Counter fixture fragment)"
