#!/usr/bin/env bash
# PF-P3-03: ContractLoader must not claim hosted isolation via local elaboration.
#
# - With PROOF_FORGE_HOSTED_ISOLATION=1, product Counter build fails closed.
# - Without the flag, trusted local Counter build still succeeds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.foundry/bin:${HOME}/.local/bin:${PATH}"

fail() { echo "hosted-isolation: $*" >&2; exit 1; }

lake build proof-forge >/dev/null

OUT="${PROOF_FORGE_HOSTED_ISOLATION_OUT:-build/hosted-isolation-smoke}"
rm -rf "$OUT"
mkdir -p "$OUT"

# Gate 1: hosted mode refuses local elaboration (not an isolation boundary).
set +e
err="$(
  PROOF_FORGE_HOSTED_ISOLATION=1 \
    lake env proof-forge build --target wasm-near --root . \
      -o "$OUT/hosted-refused" \
      Examples/Product/Counter.lean 2>&1
)"
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "hosted mode must refuse Counter build; got exit 0"
echo "$err" | grep -Fq "hosted isolation is not ready" \
  || fail "missing hosted-isolation diagnostic: $err"
echo "$err" | grep -Fq "PF-P3-03" \
  || fail "missing PF-P3-03 marker: $err"
echo "hosted-isolation: gate1 refuse under PROOF_FORGE_HOSTED_ISOLATION=1 ok"

# Gate 2: trusted local path still works when the flag is unset.
unset PROOF_FORGE_HOSTED_ISOLATION || true
set +e
ok="$(
  lake env proof-forge build --target wasm-near --root . \
    -o "$OUT/local-ok" \
    Examples/Product/Counter.lean 2>&1
)"
st=$?
set -e
[[ "$st" -eq 0 ]] || fail "trusted local Counter build failed: $ok"
[[ -f "$OUT/local-ok/counter.wat" || -f "$OUT/local-ok/counter.wasm" ]] \
  || fail "expected NEAR Counter wat/wasm under $OUT/local-ok (got: $(ls -la "$OUT/local-ok" 2>/dev/null || true))"
echo "hosted-isolation: gate2 trusted local Counter build ok"

# Gate 3: pure Lean pins for truthy/falsy + message stability.
lake env lean --run Tests/HostedIsolation.lean >/dev/null
echo "hosted-isolation: gate3 HostedIsolation pins ok"

echo "hosted-isolation: ok (PF-P3-03 fail-closed gate)"
