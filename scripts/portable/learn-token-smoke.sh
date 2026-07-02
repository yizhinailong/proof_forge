#!/usr/bin/env bash
# Learn token SDK smoke.
#
# This gate exercises the Learn token intent form across target routing:
#   - EVM: Learn token -> ERC-20 Yul -> solc bytecode -> artifact metadata.
#   - Solana: Learn token -> Token-2022 plan JSON when an extension is used.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_LEARN_TOKEN_OUT:-build/portable/learn-token}"
EVM_DIR="$OUT_DIR/evm"
SOLANA_DIR="$OUT_DIR/solana"

PROOF_TOKEN="Examples/Learn/ProofToken.learn"
FEE_TOKEN="Examples/Learn/FeeToken.learn"

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
command -v python3 >/dev/null 2>&1 || fail "python3 not on PATH"

rm -rf "$OUT_DIR"
mkdir -p "$EVM_DIR" "$SOLANA_DIR"

if command -v solc >/dev/null 2>&1; then
  echo "=== Learn token step 1: emit EVM ERC-20 Yul/bytecode ==="
  EVM_YUL="$EVM_DIR/ProofToken.erc20.yul"
  EVM_BIN="$EVM_DIR/ProofToken.erc20.bin"
  EVM_ARTIFACT="$EVM_DIR/ProofToken.erc20.artifact.json"

  lake env proof-forge --learn-token --target evm \
    --yul-output "$EVM_YUL" \
    --artifact-output "$EVM_ARTIFACT" \
    -o "$EVM_BIN" \
    "$PROOF_TOKEN" \
    || fail "proof-forge --learn-token --target evm failed"

  require_file "$EVM_YUL"
  require_file "$EVM_BIN"
  require_file "$EVM_ARTIFACT"
  require_contains "$EVM_YUL" 'object "ProofToken"' "ERC-20 Yul object"
  require_contains "$EVM_YUL" "case 0x70a08231" "ERC-20 balanceOf selector"
  require_contains "$EVM_YUL" "case 0xa9059cbb" "ERC-20 transfer selector"
  require_contains "$EVM_YUL" "case 0x095ea7b3" "ERC-20 approve selector"
  require_contains "$EVM_YUL" "case 0x23b872dd" "ERC-20 transferFrom selector"
  require_contains "$EVM_YUL" "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" \
    "ERC-20 Transfer topic"
  require_contains "$EVM_YUL" "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925" \
    "ERC-20 Approval topic"

  python3 - "$EVM_ARTIFACT" <<'PY'
import json
import sys

artifact = json.load(open(sys.argv[1]))
assert artifact["format"] == "proof-forge-token-artifact-v0"
assert artifact["sourceKind"] == "learn-token-source"
assert artifact["target"] == "evm"
assert artifact["standard"] == "erc20"
assert artifact["artifactKind"] == "evm-erc20-contract"
selectors = {entry["signature"]: entry["selector"] for entry in artifact["abi"]["entrypoints"]}
assert selectors["totalSupply()"] == "18160ddd"
assert selectors["balanceOf(address)"] == "70a08231"
assert selectors["transfer(address,uint256)"] == "a9059cbb"
assert selectors["approve(address,uint256)"] == "095ea7b3"
assert selectors["allowance(address,address)"] == "dd62ed3e"
assert selectors["transferFrom(address,address,uint256)"] == "23b872dd"
assert selectors["decimals()"] == "313ce567"
assert selectors["mint(address,uint256)"] == "40c10f19"
assert selectors["burn(uint256)"] == "42966c68"
events = {event["signature"]: event["topic0"] for event in artifact["abi"]["events"]}
assert events["Transfer(address,address,uint256)"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
assert events["Approval(address,address,uint256)"] == "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
assert artifact["validation"]["solcStrictAssembly"] == "passed"
print("evm token artifact: ok")
PY
else
  echo "SKIP: solc not on PATH; EVM ERC-20 token bytecode check skipped"
fi

echo "=== Learn token step 2: emit Solana Token-2022 plan ==="
SOLANA_PLAN="$SOLANA_DIR/FeeToken.solana-token-plan.json"
lake env proof-forge --learn-token --target solana-sbpf-asm \
  -o "$SOLANA_PLAN" \
  "$FEE_TOKEN" \
  || fail "proof-forge --learn-token --target solana-sbpf-asm failed"

require_file "$SOLANA_PLAN"
python3 - "$SOLANA_PLAN" <<'PY'
import json
import sys

plan = json.load(open(sys.argv[1]))
assert plan["format"] == "proof-forge-token-plan-v0"
assert plan["sourceKind"] == "learn-token-source"
assert plan["target"] == "solana-sbpf-asm"
assert plan["targetFamily"] == "solana"
assert plan["standard"] == "spl-token-2022"
assert plan["artifactKind"] == "solana-token-2022-plan"
assert "token-2022.extension.transfer_fee" in plan["operations"]
assert plan["validation"]["planGeneration"] == "passed"
print("solana token plan: ok")
PY

echo "learn-token-smoke: PASS"
