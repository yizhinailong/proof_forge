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
  if [[ "${PROOF_FORGE_FORCE_PYTHON_TIMEOUT:-0}" != "1" ]] && command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif [[ "${PROOF_FORGE_FORCE_PYTHON_TIMEOUT:-0}" != "1" ]] && command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    python3 - "$secs" "$@" <<'PY'
import os, signal, subprocess, sys
secs = float(sys.argv[1])
cmd = sys.argv[2:]
proc = subprocess.Popen(cmd, start_new_session=True)
try:
    sys.exit(proc.wait(timeout=secs))
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
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
# 124 is timeout(1) convention; Python fallback deliberately matches it.
[[ "$st" -eq 124 ]] || fail "expected timeout wrapper exit 124, got unrelated exit $st"
echo "worker-limits: gate3 timeout enforcement ok (exit $st)"

# Gate 4: the Python fallback must terminate the entire process group, not only
# its direct child. Otherwise compiler/tool descendants can outlive the worker.
descendant_pid_file="$OUT/descendant.pid"
set +e
PROOF_FORGE_FORCE_PYTHON_TIMEOUT=1 run_with_timeout 0.3 \
  python3 -c 'import subprocess,sys,time; child=subprocess.Popen(["sleep","30"]); open(sys.argv[1],"w").write(str(child.pid)); time.sleep(30)' \
  "$descendant_pid_file" >/dev/null 2>&1
st=$?
set -e
[[ "$st" -eq 124 ]] || fail "Python timeout fallback returned $st instead of 124"
[[ -s "$descendant_pid_file" ]] || fail "Python timeout fallback descendant did not publish its PID"
descendant_pid="$(cat "$descendant_pid_file")"
for _ in $(seq 1 50); do
  if ! kill -0 "$descendant_pid" 2>/dev/null; then
    break
  fi
  sleep 0.05
done
if kill -0 "$descendant_pid" 2>/dev/null; then
  kill -9 "$descendant_pid" 2>/dev/null || true
  fail "Python timeout fallback left descendant PID $descendant_pid alive"
fi
echo "worker-limits: gate4 Python fallback process-group cleanup ok"

echo "worker-limits: ok (PF-P3-03 wall-clock worker control; cgroup CPU/mem remain follow-on)"
