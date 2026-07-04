#!/usr/bin/env bash
set -euo pipefail

# Deploy the generated Counter initcode to a local Anvil chain through
# Foundry's real JSON-RPC path and record a ProofForge deploy-run artifact.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${EVM_OUT_DIR:-$ROOT/build/evm}"
RUN_DIR="${EVM_ANVIL_RUN_DIR:-$ROOT/build/anvil-deploy-smoke}"
CHAIN_ID="${EVM_ANVIL_CHAIN_ID:-31337}"
if [[ -n "${EVM_ANVIL_CHAIN_PROFILE+x}" ]]; then
  CHAIN_PROFILE="$EVM_ANVIL_CHAIN_PROFILE"
elif [[ "$CHAIN_ID" == "31337" ]]; then
  CHAIN_PROFILE="anvil-local"
else
  CHAIN_PROFILE=""
fi
MNEMONIC="${EVM_ANVIL_MNEMONIC:-test test test test test test test test test test test junk}"
DEPLOYER_PRIVATE_KEY="${EVM_ANVIL_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
DEPLOYER_ADDRESS="${EVM_ANVIL_DEPLOYER:-0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266}"
CONSTRUCTOR_ARGS_HEX="${EVM_ANVIL_CONSTRUCTOR_ARGS_HEX-}"
if [[ -n "${EVM_ANVIL_CONSTRUCTOR_ARG+x}" ]]; then
  CONSTRUCTOR_ARG="$EVM_ANVIL_CONSTRUCTOR_ARG"
elif [[ -n "$CONSTRUCTOR_ARGS_HEX" ]]; then
  CONSTRUCTOR_ARG=""
else
  CONSTRUCTOR_ARG=""
fi
CONSTRUCTOR_PARAM="${EVM_ANVIL_CONSTRUCTOR_PARAM-}"
if [[ -n "${EVM_ANVIL_CONSTRUCTOR_ARG+x}" && -n "$CONSTRUCTOR_ARG" && -n "$CONSTRUCTOR_ARGS_HEX" ]]; then
  echo "anvil-deploy-smoke: set either EVM_ANVIL_CONSTRUCTOR_ARG or EVM_ANVIL_CONSTRUCTOR_ARGS_HEX, not both" >&2
  exit 2
fi
if [[ -n "$CONSTRUCTOR_ARG" ]]; then
  CONSTRUCTOR_ARGS_SOURCE="--evm-constructor-arg"
elif [[ -n "$CONSTRUCTOR_ARGS_HEX" ]]; then
  CONSTRUCTOR_ARGS_SOURCE="--evm-constructor-args-hex"
else
  CONSTRUCTOR_ARGS_SOURCE=""
fi

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v anvil >/dev/null 2>&1; then
  echo "anvil-deploy-smoke: anvil not found. Install Foundry, then re-run this script." >&2
  echo "anvil-deploy-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "anvil-deploy-smoke: cast not found. Install Foundry, then re-run this script." >&2
  echo "anvil-deploy-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "anvil-deploy-smoke: python3 not found on PATH." >&2
  exit 127
fi

"$ROOT/scripts/evm/build-examples.sh"

mkdir -p "$RUN_DIR"
ANVIL_LOG="$RUN_DIR/anvil.log"
DEPLOY_RECEIPT="$RUN_DIR/Counter.cast-send.json"
DEPLOY_TX="$RUN_DIR/Counter.creation-transaction.json"
INITIALIZE_RECEIPT="$RUN_DIR/Counter.initialize-receipt.json"
DEPLOY_RUN="$RUN_DIR/Counter.proof-forge-deploy-run.json"
RUNTIME_FILE="$OUT_DIR/Counter.bin"
INIT_FILE="$OUT_DIR/Counter.init.bin"
DEPLOY_MANIFEST="$OUT_DIR/Counter.proof-forge-deploy.json"

if [[ -n "${PROOF_FORGE_BIN:-}" ]]; then
  proof_forge=("$PROOF_FORGE_BIN")
else
  proof_forge=(lake env proof-forge)
fi

rebuild_counter_with_profile() {
  local proof_forge_args=(
    build
    --target evm
    --root .
    --yul-output "$OUT_DIR/Counter.yul"
    --artifact-output "$OUT_DIR/Counter.proof-forge-artifact.json"
    -o "$RUNTIME_FILE"
    Examples/Evm/Contracts/Counter.lean
  )
  if [[ -n "$CHAIN_PROFILE" ]]; then
    proof_forge_args+=(--evm-chain-profile "$CHAIN_PROFILE")
  fi
  (
    cd "$ROOT"
    "${proof_forge[@]}" "${proof_forge_args[@]}"
    diff -u Examples/Evm/Contracts/Counter.golden.yul "$OUT_DIR/Counter.yul"
    metadata_validator=(
      python3 "$ROOT/scripts/evm/validate-artifact-metadata.py"
      --root "$ROOT"
      --expect-fixture Counter
      --expect-source-kind contract-sdk
    )
    if [[ -n "$CHAIN_PROFILE" ]]; then
      metadata_validator+=(--expect-chain-profile "$CHAIN_PROFILE" --expect-chain-id "$CHAIN_ID")
    fi
    metadata_validator+=("$OUT_DIR/Counter.proof-forge-artifact.json")
    "${metadata_validator[@]}"
  )
}

rebuild_counter_with_profile

if [[ -n "$CONSTRUCTOR_ARG" || -n "$CONSTRUCTOR_ARGS_HEX" ]]; then
  proof_forge_args=(
    build
    --target evm
    --root .
    --yul-output "$OUT_DIR/Counter.yul"
    --artifact-output "$OUT_DIR/Counter.proof-forge-artifact.json"
  )
  if [[ -n "$CHAIN_PROFILE" ]]; then
    proof_forge_args+=(--evm-chain-profile "$CHAIN_PROFILE")
  fi
  if [[ -n "$CONSTRUCTOR_PARAM" ]]; then
    proof_forge_args+=(--evm-constructor-param "$CONSTRUCTOR_PARAM")
  fi
  if [[ -n "$CONSTRUCTOR_ARG" ]]; then
    proof_forge_args+=(--evm-constructor-arg "$CONSTRUCTOR_ARG")
  fi
  if [[ -n "$CONSTRUCTOR_ARGS_HEX" ]]; then
    proof_forge_args+=(--evm-constructor-args-hex "$CONSTRUCTOR_ARGS_HEX")
  fi
  proof_forge_args+=(-o "$RUNTIME_FILE" Examples/Evm/Contracts/Counter.lean)

  (
    cd "$ROOT"
    "${proof_forge[@]}" "${proof_forge_args[@]}"
    diff -u Examples/Evm/Contracts/Counter.golden.yul "$OUT_DIR/Counter.yul"
    metadata_validator=(
      python3 "$ROOT/scripts/evm/validate-artifact-metadata.py"
      --root "$ROOT"
      --expect-fixture Counter
      --expect-source-kind contract-sdk
    )
    if [[ -n "$CHAIN_PROFILE" ]]; then
      metadata_validator+=(--expect-chain-profile "$CHAIN_PROFILE" --expect-chain-id "$CHAIN_ID")
    fi
    if [[ ( -n "$CONSTRUCTOR_ARG" || -n "$CONSTRUCTOR_ARGS_HEX" ) && -n "$CONSTRUCTOR_PARAM" ]]; then
      metadata_validator+=(--expect-constructor-param "$CONSTRUCTOR_PARAM")
    fi
    if [[ -n "$CONSTRUCTOR_ARGS_SOURCE" ]]; then
      metadata_validator+=("--expect-constructor-args-source=$CONSTRUCTOR_ARGS_SOURCE")
    fi
    metadata_validator+=(
      "$OUT_DIR/Counter.proof-forge-artifact.json"
    )
    "${metadata_validator[@]}"
  )
fi

if [[ -n "${EVM_ANVIL_PORT:-}" ]]; then
  PORT="$EVM_ANVIL_PORT"
else
  PORT="$(python3 - <<'PY'
import socket

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
)"
fi

RPC_URL="${EVM_ANVIL_RPC_URL:-http://127.0.0.1:$PORT}"

anvil \
  --host 127.0.0.1 \
  --port "$PORT" \
  --chain-id "$CHAIN_ID" \
  --accounts 1 \
  --mnemonic "$MNEMONIC" \
  --quiet \
  >"$ANVIL_LOG" 2>&1 &
ANVIL_PID=$!

cleanup() {
  kill "$ANVIL_PID" >/dev/null 2>&1 || true
  wait "$ANVIL_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 80); do
  if cast chain-id --rpc-url "$RPC_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

ACTUAL_CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL")"
if [[ "$ACTUAL_CHAIN_ID" != "$CHAIN_ID" ]]; then
  echo "anvil-deploy-smoke: expected chain id $CHAIN_ID, got $ACTUAL_CHAIN_ID" >&2
  exit 1
fi

INIT_HEX="$(tr -d '\n' < "$INIT_FILE")"
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --create "0x$INIT_HEX" \
  --json \
  >"$DEPLOY_RECEIPT"

DEPLOY_TX_HASH="$(python3 - "$DEPLOY_RECEIPT" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
print(receipt["transactionHash"])
PY
)"
cast rpc \
  --rpc-url "$RPC_URL" \
  eth_getTransactionByHash "$DEPLOY_TX_HASH" \
  >"$DEPLOY_TX"

CONTRACT_ADDRESS="$(python3 - "$DEPLOY_RECEIPT" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
print(receipt["contractAddress"])
PY
)"

INITIAL_GET="$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" 'get()(uint256)')"
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  "$CONTRACT_ADDRESS" \
  'initialize()' \
  --json \
  >"$INITIALIZE_RECEIPT"
AFTER_INITIALIZE_GET="$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" 'get()(uint256)')"
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  "$CONTRACT_ADDRESS" \
  'increment()' \
  --json \
  >/dev/null
AFTER_INCREMENT_GET="$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" 'get()(uint256)')"
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  "$CONTRACT_ADDRESS" \
  'increment()' \
  --json \
  >/dev/null
AFTER_SECOND_INCREMENT_GET="$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" 'get()(uint256)')"

DEPLOYED_CODE="$(cast code --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS")"
RUNTIME_HEX="$(tr -d '\n' < "$RUNTIME_FILE")"
if [[ "${DEPLOYED_CODE#0x}" != "$RUNTIME_HEX" ]]; then
  echo "anvil-deploy-smoke: deployed code does not match $RUNTIME_FILE" >&2
  exit 1
fi

python3 - \
  "$ROOT" \
  "$RPC_URL" \
  "$CHAIN_ID" \
  "$DEPLOYER_ADDRESS" \
  "$CONTRACT_ADDRESS" \
  "$DEPLOY_RECEIPT" \
  "$DEPLOY_TX" \
  "$INITIALIZE_RECEIPT" \
  "$DEPLOY_MANIFEST" \
  "$RUNTIME_FILE" \
  "$INIT_FILE" \
  "$DEPLOY_RUN" \
  "$INITIAL_GET" \
  "$AFTER_INITIALIZE_GET" \
  "$AFTER_INCREMENT_GET" \
  "$AFTER_SECOND_INCREMENT_GET" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

(
    root,
    rpc_url,
    chain_id,
    deployer,
    contract_address,
    deploy_receipt_path,
    deploy_tx_path,
    initialize_receipt_path,
    deploy_manifest_path,
    runtime_path,
    init_path,
    deploy_run_path,
    initial_get,
    after_initialize_get,
    after_increment_get,
    after_second_increment_get,
) = sys.argv[1:]

root_path = Path(root)
deploy_receipt = json.loads(Path(deploy_receipt_path).read_text())
deploy_manifest = json.loads(Path(deploy_manifest_path).read_text())
runtime_hex = Path(runtime_path).read_text().strip()


def file_entry(path_text: str) -> dict:
    path = Path(path_text)
    data = path.read_bytes()
    try:
        display = str(path.resolve().relative_to(root_path.resolve()))
    except ValueError:
        display = str(path)
    return {
        "path": display,
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
    }


def hex_int(value: str) -> int:
    return int(value, 16)


run = {
    "schemaVersion": 1,
    "kind": "proof-forge-evm-deploy-run",
    "target": "evm",
    "targetFamily": "evm",
    "fixture": "Counter",
    "contractName": "Counter",
    "deployManifest": file_entry(deploy_manifest_path),
    "runtimeBytecode": file_entry(runtime_path),
    "initCode": file_entry(init_path),
    "chainProfile": deploy_manifest["chainProfile"],
    "constructorAbi": deploy_manifest["abi"]["constructor"],
    "constructorArgs": deploy_manifest["creation"]["constructorArgs"],
    "castSendReceipt": file_entry(deploy_receipt_path),
    "creationTransaction": file_entry(deploy_tx_path),
    "initializeReceipt": file_entry(initialize_receipt_path),
    "network": {
        "kind": "anvil",
        "chainId": int(chain_id),
        "rpcUrl": rpc_url,
    },
    "deployer": {
        "address": deployer.lower(),
    },
    "transaction": {
        "hash": deploy_receipt["transactionHash"],
        "status": deploy_receipt["status"],
        "type": deploy_receipt.get("type"),
        "from": deploy_receipt["from"],
        "to": deploy_receipt["to"],
        "contractAddress": contract_address,
        "blockHash": deploy_receipt["blockHash"],
        "blockNumber": hex_int(deploy_receipt["blockNumber"]),
        "gasUsed": hex_int(deploy_receipt["gasUsed"]),
        "cumulativeGasUsed": hex_int(deploy_receipt["cumulativeGasUsed"]),
        "effectiveGasPrice": hex_int(deploy_receipt["effectiveGasPrice"]),
    },
    "deployedCode": {
        "address": contract_address,
        "sha256": hashlib.sha256(bytes.fromhex(runtime_hex)).hexdigest(),
        "bytes": len(runtime_hex) // 2,
        "runtimeBytecodeMatches": True,
    },
    "calls": {
        "initialGet": initial_get,
        "afterInitializeGet": after_initialize_get,
        "afterIncrementGet": after_increment_get,
        "afterSecondIncrementGet": after_second_increment_get,
    },
    "validation": {
        "anvilStarted": "passed",
        "chainId": "passed",
        "castCreate": "passed",
        "creationTransaction": "passed",
        "receipt": "passed",
        "runtimeCodeMatch": "passed",
        "counterLifecycle": "passed",
        "artifactMetadata": "passed",
    },
}

Path(deploy_run_path).write_text(json.dumps(run, indent=2, sort_keys=True) + "\n")
PY

deploy_run_validator=(
  python3 "$ROOT/scripts/evm/validate-deploy-run.py"
  --root "$ROOT" \
  --expect-fixture Counter \
  --expect-chain-id "$CHAIN_ID"
)
if [[ -n "$CHAIN_PROFILE" ]]; then
  deploy_run_validator+=(--expect-chain-profile "$CHAIN_PROFILE")
fi
if [[ ( -n "$CONSTRUCTOR_ARG" || -n "$CONSTRUCTOR_ARGS_HEX" ) && -n "$CONSTRUCTOR_PARAM" ]]; then
  deploy_run_validator+=(--expect-constructor-param "$CONSTRUCTOR_PARAM")
fi
if [[ -n "$CONSTRUCTOR_ARGS_SOURCE" ]]; then
  deploy_run_validator+=("--expect-constructor-args-source=$CONSTRUCTOR_ARGS_SOURCE")
fi
deploy_run_validator+=(
  "$DEPLOY_RUN"
)
"${deploy_run_validator[@]}"

echo "anvil-deploy-smoke: deployed Counter to $CONTRACT_ADDRESS on Anvil chain $CHAIN_ID"
echo "anvil-deploy-smoke: ProofForge deploy-run artifact $DEPLOY_RUN"
