#!/usr/bin/env bash
# Product-facing NEAR TokenSpec health path (Wave β).
#
# One command story (docs/product-sdk.md):
#   1) TokenSpec plan for --target wasm-near (NEP-141 operations metadata)
#   2) Full FT body: Stdlib.NearFungibleToken → EmitWat WAT
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
export PATH="$HOME/.elan/bin:$HOME/.local/bin:$PATH"

OUT_DIR="${PROOF_FORGE_TOKEN_NEAR_OUT:-build/portable/token-near}"
LEAN_TOKEN="Examples/Product/FungibleToken.lean"
PLAN_JSON="$OUT_DIR/FungibleToken.near-nep141-plan.json"
WAT_OUT="$OUT_DIR/NearFungibleToken.wat"
DRIVER="$OUT_DIR/emit_body.lean"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "file not written: $1"
}

require_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  grep -Fq -- "$needle" "$file" || fail "$label missing '$needle' in $file"
}

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "=== product-token-near step 1: TokenSpec → wasm-near NEP-141 plan ==="
lake env proof-forge build --target wasm-near --token --root . \
  -o "$PLAN_JSON" \
  "$LEAN_TOKEN" \
  || fail "proof-forge build --target wasm-near --token failed for Product FungibleToken"

require_file "$PLAN_JSON"
python3 - "$PLAN_JSON" <<'PY'
import json
import sys

plan = json.load(open(sys.argv[1]))
assert plan["format"] == "proof-forge-token-plan-v0"
assert plan["sourceKind"] == "lean-token-source"
assert plan["target"] == "wasm-near"
assert plan["standard"] == "nep-141"
assert plan["artifactKind"] == "near-nep141-plan"
ops = plan.get("operations") or []
assert "ft_transfer" in ops, f"missing ft_transfer in {ops}"
assert "ft_balance_of" in ops, f"missing ft_balance_of in {ops}"
assert "ft_total_supply" in ops, f"missing ft_total_supply in {ops}"
print("near nep-141 token plan: ok")
PY

echo "=== product-token-near step 2: NEP-141 body (Stdlib) → EmitWat ==="
lake build ProofForge.Contract.Stdlib.NearFungibleToken ProofForge.Backend.WasmHost.EmitWat \
  || fail "lake build NearFungibleToken/EmitWat failed"

# Emit body via Lean (stdlib exposes .module, not a CLI contract_source file).
cat >"$DRIVER" <<'EOF'
import ProofForge.Backend.WasmHost.EmitWat
import ProofForge.Contract.Stdlib.NearFungibleToken

def main : IO Unit := do
  match ProofForge.Backend.WasmHost.EmitWat.renderModule
      ProofForge.Contract.Stdlib.NearFungibleToken.module with
  | .error e => throw (IO.userError e.message)
  | .ok wat =>
      let path := System.FilePath.mk "build/portable/token-near/NearFungibleToken.wat"
      IO.FS.writeFile path wat
      IO.println s!"wrote {path}"
EOF

# Driver uses fixed relative path under OUT_DIR
lake env lean --run "$DRIVER" \
  || fail "EmitWat render NearFungibleToken.module failed"

require_file "$WAT_OUT"
require_contains "$WAT_OUT" "ft_transfer" "NEP-141 body must mention ft_transfer"
require_contains "$WAT_OUT" "storage_write" "NEP-141 body should use host storage_write"
require_contains "$WAT_OUT" "promise_create" "NEP-141 body should support promise_create for transfer_call"

echo "product-token-near: ok (plan · NEP-141 body WAT)"
