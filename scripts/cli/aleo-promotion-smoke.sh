#!/usr/bin/env bash
# PF-P3-02: six-gate promotion smoke for aleo-leo (Counter fixture fragment).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.foundry/bin:${HOME}/.elan/bin:${HOME}/.cargo/bin:${PATH}"

fail() { echo "aleo-promotion: $*" >&2; exit 1; }
ok() { echo "aleo-promotion: ok — $*"; }

command -v leo >/dev/null || fail "leo CLI not on PATH"

# Gates 1,3,4,5 via existing counter smoke (emit, golden, leo build/test, metadata)
bash scripts/aleo/counter-smoke.sh || fail "gates1/3/4/5: aleo counter-smoke failed"
ok "gates1/3/4/5 aleo counter-smoke"

# Gate 2: product source fail-closed
set +e
err="$(lake env proof-forge build --target aleo-leo --root . \
  -o build/aleo-promotion-reject Examples/Product/Counter.lean 2>&1)"
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "gate2: product Counter must fail-closed"
echo "$err" | grep -Eqi 'source input is not supported|not supported|fixture' \
  || fail "gate2: expected diagnostic, got: $err"
ok "gate2 product source fail-closed"

# Gate 6
python3 - <<'PY' || fail "gate6"
from pathlib import Path
import subprocess
assert 'id := "aleo-leo"' in Path("ProofForge/Target/Registry.lean").read_text()
assert "aleo-leo" in Path("README.md").read_text()
out = subprocess.check_output(["lake","env","proof-forge","--list-targets"], text=True)
assert "aleo-leo" in out
print("ok")
PY
ok "gate6 surface"

echo "aleo-promotion: ok (six gates for Counter fixture fragment)"
