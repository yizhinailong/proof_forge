#!/usr/bin/env bash
# Deploy and execute the Learn-token ERC-20 artifact in a local EthereumJS VM.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_LEARN_TOKEN_EVM_VM_OUT:-build/evm/learn-token-erc20-vm}"
NODE_PROJECT="$OUT_DIR/node"
JS_TEMPLATE="$REPO_ROOT/Tests/evm/learn_token_erc20_vm_smoke.mjs"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
command -v solc >/dev/null 2>&1 || fail "solc not on PATH"
command -v node >/dev/null 2>&1 || fail "node not on PATH"
command -v npm >/dev/null 2>&1 || fail "npm not on PATH"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$NODE_PROJECT"

EVM_YUL="$OUT_DIR/ProofToken.erc20.yul"
EVM_BIN="$OUT_DIR/ProofToken.erc20.bin"
EVM_ARTIFACT="$OUT_DIR/ProofToken.erc20.artifact.json"

echo "=== Learn token EVM VM step 1: emit ERC-20 artifact ==="
lake env proof-forge --learn-token --target evm \
  --yul-output "$EVM_YUL" \
  --artifact-output "$EVM_ARTIFACT" \
  -o "$EVM_BIN" \
  Examples/Learn/ProofToken.learn \
  || fail "proof-forge --learn-token --target evm failed"

test -s "$EVM_BIN" || fail "empty EVM bytecode: $EVM_BIN"
test -s "$EVM_ARTIFACT" || fail "missing EVM artifact: $EVM_ARTIFACT"

echo "=== Learn token EVM VM step 2: install local EthereumJS runner ==="
cp "$JS_TEMPLATE" "$NODE_PROJECT/learn_token_erc20_vm_smoke.mjs"
(
  cd "$NODE_PROJECT"
  npm init -y >/dev/null
  npm install --silent \
    @ethereumjs/common@10.1.2 \
    @ethereumjs/util@10.1.2 \
    @ethereumjs/vm@10.1.2
) || fail "npm install EthereumJS VM dependencies failed"

echo "=== Learn token EVM VM step 3: deploy and exercise ERC-20 behavior ==="
node "$NODE_PROJECT/learn_token_erc20_vm_smoke.mjs" "$EVM_BIN" "$EVM_ARTIFACT" \
  || fail "EthereumJS ERC-20 behavior smoke failed"

echo "learn-token-erc20-vm-smoke: PASS"
