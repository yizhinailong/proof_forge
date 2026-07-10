#!/usr/bin/env bash
# PF-P3-03: worker resource-limit surface (local simulation).
#
# Hosted isolation still refuses under PROOF_FORGE_HOSTED_ISOLATION (gate1 of
# hosted-isolation). This smoke documents the next boundary: a *local* worker
# wrapper that enforces wall-clock time so runaway elaboration cannot hang CI.
#
# Full multi-process sandbox with CPU/mem cgroups remains follow-on work; this
# gate proves the wall-clock control path exists and fails closed on timeout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.foundry/bin:${HOME}/.local/bin:${PATH}"

fail() { echo "worker-limits: $*" >&2; exit 1; }

# Prefer GNU timeout / gtimeout; fall back to python if missing.
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    python3 - "$secs" "$@" <<'PY'
import subprocess, sys
secs = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    r = subprocess.run(cmd, timeout=secs)
    sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
PY
  fi
}

lake build proof-forge >/dev/null

OUT="${PROOF_FORGE_WORKER_LIMITS_OUT:-build/worker-limits-smoke}"
rm -rf "$OUT"
mkdir -p "$OUT"

# Gate 1: hosted isolation still refuse (cross-check with hosted-isolation smoke).
set +e
err="$(
  PROOF_FORGE_HOSTED_ISOLATION=1 \
    lake env proof-forge build --target wasm-near --root . \
      -o "$OUT/hosted-refused" \
      Examples/Product/Counter.lean 2>&1
)"
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "hosted isolation must refuse"
echo "$err" | grep -Fq "hosted isolation is not ready" \
  || fail "missing hosted isolation diagnostic"
echo "worker-limits: gate1 hosted isolation refuse ok"

# Gate 2: trusted local build completes under a generous wall-clock limit.
set +e
out="$(
  run_with_timeout 120 lake env proof-forge build --target wasm-near --root . \
    -o "$OUT/local-ok" \
    Examples/Product/Counter.lean 2>&1
)"
st=$?
set -e
[[ "$st" -eq 0 ]] || fail "trusted local build under timeout wrapper failed (exit $st): $out"
[[ -f "$OUT/local-ok/counter.wat" || -f "$OUT/local-ok/counter.wasm" ]] \
  || fail "missing NEAR Counter artifact under $OUT/local-ok"
echo "worker-limits: gate2 local build under 120s wall-clock ok"

# Gate 3: zero-second timeout fails closed (proves the limit is enforced).
set +e
run_with_timeout 0.01 sleep 2 >/dev/null 2>&1
st=$?
set -e
# 124 is timeout(1) convention; python fallback also uses 124.
[[ "$st" -eq 124 || "$st" -ne 0 ]] || fail "expected timeout wrapper to kill sleep (exit $st)"
echo "worker-limits: gate3 timeout enforcement ok (exit $st)"

echo "worker-limits: ok (PF-P3-03 wall-clock worker control; cgroup CPU/mem remain follow-on)"
