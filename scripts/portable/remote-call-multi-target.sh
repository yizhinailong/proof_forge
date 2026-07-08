#!/usr/bin/env bash
# Portable RemoteCall multi-target smoke.
#
# One Shared source → EVM CALL plan/emit, Solana CPI asm, NEAR promise_create WAT.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export PATH="$HOME/.foundry/bin:$PATH"

SOURCE="${PORTABLE_REMOTE_CALL_SOURCE:-Examples/Shared/RemoteCall.lean}"
OUT="${PORTABLE_REMOTE_CALL_OUT:-build/portable-remote-call}"

if [[ -n "${PROOF_FORGE_BIN:-}" ]]; then
  proof_forge=("$PROOF_FORGE_BIN")
else
  proof_forge=(lake env proof-forge)
fi
cast_args=()
if [[ -n "${CAST:-}" ]]; then
  cast_args=(--cast "$CAST")
fi

fail() {
  echo "portable-remote-call: FAIL: $1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_contains() {
  grep -Fq -- "$2" "$1" || fail "$3 missing '$2' in $1"
}

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
mkdir -p "$OUT/evm" "$OUT/solana" "$OUT/near"

(cd "$ROOT" && lake build proof-forge Examples.Shared.RemoteCall >/dev/null)

echo "portable-remote-call: EVM"
if command -v solc >/dev/null 2>&1; then
  "${proof_forge[@]}" build --target evm --root . \
    -o "$OUT/evm/RemoteCall.bin" \
    --yul-output "$OUT/evm/RemoteCall.yul" \
    --artifact-output "$OUT/evm/RemoteCall.proof-forge-artifact.json" \
    "${cast_args[@]+"${cast_args[@]}"}" \
    "$SOURCE"
  require_file "$OUT/evm/RemoteCall.bin"
  require_file "$OUT/evm/RemoteCall.yul"
  require_file "$OUT/evm/RemoteCall.proof-forge-artifact.json"
  # Yul CALL opcode / helper naming varies; accept either form.
  if ! grep -Eqi 'call|staticcall|delegatecall' "$OUT/evm/RemoteCall.yul"; then
    fail "EVM Yul should contain a CALL-family emission"
  fi
else
  echo "portable-remote-call: solc missing; EVM emit skipped (Lean gate still covers plan)"
fi

echo "portable-remote-call: Solana sBPF"
"${proof_forge[@]}" build --target solana-sbpf-asm --root . \
  -o "$OUT/solana/RemoteCall.s" \
  --artifact-output "$OUT/solana/RemoteCall.solana-artifact.json" \
  "$SOURCE"
require_file "$OUT/solana/RemoteCall.s"
require_file "$OUT/solana/manifest.toml"
require_contains "$OUT/solana/RemoteCall.s" "sol_invoke_signed_c" "Solana CPI invoke"
require_contains "$OUT/solana/RemoteCall.s" "sol_get_return_data" "Solana return-data"
require_contains "$OUT/solana/RemoteCall.s" "AccountMeta" "Solana account metas"
require_contains "$OUT/solana/RemoteCall.s" "forward" "Solana forwards full account vector"
require_contains "$OUT/solana/manifest.toml" "callee_program" "manifest callee_program account"
GOLDEN_SOL="$ROOT/Examples/Shared/goldens/RemoteCall.solana.s"
if [[ -f "$GOLDEN_SOL" ]]; then
  diff -u "$GOLDEN_SOL" "$OUT/solana/RemoteCall.s" \
    || fail "Solana asm drifted from Examples/Shared/goldens/RemoteCall.solana.s"
fi

echo "portable-remote-call: NEAR/Wasm"
"${proof_forge[@]}" build --target wasm-near --root . \
  -o "$OUT/near" \
  --artifact-output "$OUT/near/RemoteCall.near-artifact.json" \
  "$SOURCE"
# EmitWat names the wat file from module name (lowercased).
WAT=""
if [[ -f "$OUT/near/remotecall.wat" ]]; then
  WAT="$OUT/near/remotecall.wat"
elif [[ -f "$OUT/near/RemoteCall.wat" ]]; then
  WAT="$OUT/near/RemoteCall.wat"
else
  WAT="$(find "$OUT/near" -name '*.wat' | head -n1 || true)"
fi
[[ -n "$WAT" && -f "$WAT" ]] || fail "NEAR WAT not written under $OUT/near"
require_contains "$WAT" "promise_create" "NEAR promise_create materialization"
GOLDEN_NEAR="$ROOT/Examples/Shared/goldens/RemoteCall.near.wat"
if [[ -f "$GOLDEN_NEAR" ]]; then
  diff -u "$GOLDEN_NEAR" "$WAT" \
    || fail "NEAR WAT drifted from Examples/Shared/goldens/RemoteCall.near.wat"
fi
require_file "$OUT/near/RemoteCall.near-artifact.json"

echo "portable-remote-call-multi-target: ok"
