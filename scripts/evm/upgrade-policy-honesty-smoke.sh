#!/usr/bin/env bash
# E1.4: EVM upgrade-policy honesty on the product build path.
#
# - UUPSProxy (authority + proxy_pattern uups) must build.
# - authority without proxy_pattern must fail closed with an actionable diagnostic.
# - governance must fail closed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.foundry/bin:${HOME}/.local/bin:${PATH}"

OUT_DIR="${PROOF_FORGE_UPGRADE_HONESTY_OUT:-build/evm-upgrade-policy-honesty}"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

fail() {
  echo "upgrade-policy-honesty: FAIL: $1" >&2
  exit 1
}

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
lake build proof-forge >/dev/null

echo "=== E1.4: positive UUPSProxy (authority + uups) ==="
lake env proof-forge build --target evm --root . \
  --yul-output "$OUT_DIR/UUPSProxy.yul" \
  -o "$OUT_DIR/UUPSProxy.bin" \
  Examples/Backend/Evm/Contracts/stdlib/UUPSProxy.lean \
  || fail "UUPSProxy build failed"

test -s "$OUT_DIR/UUPSProxy.bin" || fail "missing UUPSProxy.bin"
# Contract-spec must record honest upgrade metadata
SPEC="$(find "$OUT_DIR" -name '*contract-spec.json' | head -n1)"
test -s "$SPEC" || fail "missing contract-spec"
python3 - "$SPEC" <<'PY' || fail "UUPSProxy contract-spec upgrade fields"
import json, sys
from pathlib import Path
spec = json.loads(Path(sys.argv[1]).read_text())
up = spec.get("upgradePolicy") or {}
px = spec.get("proxyPattern") or {}
if up.get("kind") != "authority":
    raise SystemExit(f"upgradePolicy.kind expected authority, got {up!r}")
if up.get("keyRef") != "admin":
    raise SystemExit(f"upgradePolicy.keyRef expected admin, got {up!r}")
if px.get("kind") != "uups":
    raise SystemExit(f"proxyPattern.kind expected uups, got {px!r}")
print("uups contract-spec: ok")
PY

echo "=== E1.4: negative authority without proxy_pattern ==="
set +e
neg_out=$(lake env proof-forge build --target evm --root . \
  -o "$OUT_DIR/BadUpgradeAuth.bin" \
  Tests/Backend/Evm/BadUpgradeAuth.lean 2>&1)
neg_ec=$?
set -e
if [[ "$neg_ec" -eq 0 ]]; then
  fail "BadUpgradeAuth unexpectedly built (must fail closed)"
fi
echo "$neg_out" | grep -Fq "without a documented proxy pattern" \
  || fail "diagnostic missing 'without a documented proxy pattern'; got: $neg_out"

echo "=== E1.4: unit matrix (Tests/UpgradePolicy.lean) ==="
lake env lean --run Tests/UpgradePolicy.lean \
  || fail "Tests/UpgradePolicy.lean failed"

echo "upgrade-policy-honesty: ok"
