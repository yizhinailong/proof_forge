#!/usr/bin/env bash
# PF-P3-02: six-gate promotion smoke for move-sui (Counter MVP fragment).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.foundry/bin:${HOME}/.elan/bin:${HOME}/.cargo/bin:/opt/homebrew/bin:${PATH}"

fail() { echo "sui-promotion: $*" >&2; exit 1; }
ok() { echo "sui-promotion: ok — $*"; }

command -v sui >/dev/null || fail "sui CLI not on PATH"

# Gate 1–5 via existing counter smoke (emit, build, unit test lifecycle)
just sui-counter-smoke || fail "gates1-5: just sui-counter-smoke failed"
ok "gates1-5 sui-counter-smoke (package + lifecycle)"

# Gate 2 product fail-closed
set +e
err="$(lake env proof-forge build --target move-sui --root . \
  -o build/sui-promotion-reject Examples/Product/Counter.lean 2>&1)"
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "gate2: product Counter must fail-closed"
echo "$err" | grep -Eqi 'source input is not supported|not supported' \
  || fail "gate2: expected unsupported diagnostic"
ok "gate2 product source fail-closed"

# Gate 6 surface
python3 - <<'PY' || fail "gate6"
from pathlib import Path
import subprocess
assert 'id := "move-sui"' in Path("ProofForge/Target/Registry.lean").read_text()
assert "move-sui" in Path("README.md").read_text()
out = subprocess.check_output(["lake","env","proof-forge","--list-targets"], text=True)
assert "move-sui" in out
print("ok")
PY
ok "gate6 surface"

echo "sui-promotion: ok (six gates for Counter MVP fragment)"
