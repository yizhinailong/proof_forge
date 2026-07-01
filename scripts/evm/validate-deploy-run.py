#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
HASH_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")


def fail(message: str) -> None:
    raise SystemExit(f"evm-deploy-run-validate: {message}")


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def expect_object(value: Any, name: str) -> dict:
    expect(isinstance(value, dict), f"{name} must be an object")
    return value


def expect_string(value: Any, name: str) -> str:
    expect(isinstance(value, str) and value, f"{name} must be a non-empty string")
    return value


def expect_array(value: Any, name: str) -> list:
    expect(isinstance(value, list), f"{name} must be an array")
    return value


def resolve_path(root: Path, path_text: str) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path
    return root / path


def file_entry(root: Path, entry: dict, name: str) -> Path:
    path = resolve_path(root, expect_string(entry.get("path"), f"{name}.path"))
    expect(path.is_file(), f"{name}.path does not exist: {path}")
    data = path.read_bytes()
    expect(entry.get("bytes") == len(data), f"{name}.bytes mismatch")
    expect(entry.get("sha256") == hashlib.sha256(data).hexdigest(), f"{name}.sha256 mismatch")
    return path


def expect_hex_file(path: Path, name: str) -> str:
    value = path.read_text().strip()
    expect(value, f"{name} must not be empty")
    expect(all(ch in "0123456789abcdefABCDEF" for ch in value), f"{name} must contain hex")
    expect(len(value) % 2 == 0, f"{name} must have an even number of hex digits")
    return value.lower()


def expect_address(value: Any, name: str) -> str:
    text = expect_string(value, name)
    expect(ADDRESS_RE.match(text) is not None, f"{name} must be an EVM address")
    return text.lower()


def expect_hash(value: Any, name: str) -> str:
    text = expect_string(value, name)
    expect(HASH_RE.match(text) is not None, f"{name} must be a 32-byte hash")
    return text.lower()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--expect-fixture", default="Counter.lean")
    parser.add_argument("--expect-chain-id", type=int, default=31337)
    parser.add_argument("--expect-contract-name", default="Counter")
    parser.add_argument("deploy_run")
    args = parser.parse_args()

    root = Path(args.root)
    deploy_run_path = Path(args.deploy_run)
    run = expect_object(json.loads(deploy_run_path.read_text()), "deploy run")

    expect(run.get("schemaVersion") == 1, "schemaVersion must be 1")
    expect(run.get("kind") == "proof-forge-evm-deploy-run", "kind mismatch")
    expect(run.get("target") == "evm", "target must be evm")
    expect(run.get("targetFamily") == "evm", "targetFamily mismatch")
    expect(run.get("fixture") == args.expect_fixture, "fixture mismatch")
    expect(run.get("contractName") == args.expect_contract_name, "contractName mismatch")

    deploy_manifest_path = file_entry(
        root,
        expect_object(run.get("deployManifest"), "deployManifest"),
        "deployManifest",
    )
    manifest = expect_object(json.loads(deploy_manifest_path.read_text()), "deploy manifest")
    expect(manifest.get("kind") == "proof-forge-evm-deploy-manifest", "deploy manifest kind mismatch")
    expect(manifest.get("fixture") == args.expect_fixture, "deploy manifest fixture mismatch")
    expect(manifest.get("contractName") == args.expect_contract_name, "deploy manifest contractName mismatch")

    runtime_path = file_entry(
        root,
        expect_object(run.get("runtimeBytecode"), "runtimeBytecode"),
        "runtimeBytecode",
    )
    init_code_path = file_entry(
        root,
        expect_object(run.get("initCode"), "initCode"),
        "initCode",
    )
    send_receipt_path = file_entry(
        root,
        expect_object(run.get("castSendReceipt"), "castSendReceipt"),
        "castSendReceipt",
    )
    set_receipt_path = file_entry(
        root,
        expect_object(run.get("setReceipt"), "setReceipt"),
        "setReceipt",
    )

    manifest_inputs = expect_object(manifest.get("inputs"), "deploy manifest inputs")
    manifest_runtime = file_entry(root, expect_object(manifest_inputs.get("bytecode"), "inputs.bytecode"), "inputs.bytecode")
    manifest_init = file_entry(root, expect_object(manifest_inputs.get("initCode"), "inputs.initCode"), "inputs.initCode")
    expect(manifest_runtime.resolve() == runtime_path.resolve(), "runtimeBytecode must match deploy manifest")
    expect(manifest_init.resolve() == init_code_path.resolve(), "initCode must match deploy manifest")

    runtime_hex = expect_hex_file(runtime_path, "runtimeBytecode").lower()
    init_hex = expect_hex_file(init_code_path, "initCode").lower()
    expect(init_hex.endswith(runtime_hex), "initCode must contain runtime bytecode suffix")

    network = expect_object(run.get("network"), "network")
    expect(network.get("kind") == "anvil", "network.kind must be anvil")
    expect(network.get("chainId") == args.expect_chain_id, "network.chainId mismatch")
    expect_string(network.get("rpcUrl"), "network.rpcUrl")

    deployer = expect_object(run.get("deployer"), "deployer")
    deployer_address = expect_address(deployer.get("address"), "deployer.address")

    transaction = expect_object(run.get("transaction"), "transaction")
    expect(transaction.get("status") == "0x1", "transaction.status must be 0x1")
    tx_hash = expect_hash(transaction.get("hash"), "transaction.hash")
    expect_hash(transaction.get("blockHash"), "transaction.blockHash")
    expect_address(transaction.get("from"), "transaction.from")
    expect(transaction.get("to") is None, "transaction.to must be null for contract creation")
    contract_address = expect_address(transaction.get("contractAddress"), "transaction.contractAddress")
    expect(transaction.get("from").lower() == deployer_address, "transaction.from must match deployer.address")
    expect(isinstance(transaction.get("blockNumber"), int) and transaction["blockNumber"] >= 1, "transaction.blockNumber must be positive")
    expect(isinstance(transaction.get("gasUsed"), int) and transaction["gasUsed"] > 0, "transaction.gasUsed must be positive")

    receipt = expect_object(json.loads(send_receipt_path.read_text()), "cast send receipt")
    expect(receipt.get("transactionHash", "").lower() == tx_hash, "cast send transactionHash mismatch")
    expect(receipt.get("contractAddress", "").lower() == contract_address, "cast send contractAddress mismatch")
    expect(receipt.get("status") == "0x1", "cast send status must be 0x1")

    set_receipt = expect_object(json.loads(set_receipt_path.read_text()), "set receipt")
    expect(set_receipt.get("status") == "0x1", "set receipt status must be 0x1")

    deployed_code = expect_object(run.get("deployedCode"), "deployedCode")
    expect(expect_address(deployed_code.get("address"), "deployedCode.address") == contract_address, "deployedCode.address mismatch")
    expect(deployed_code.get("runtimeBytecodeMatches") is True, "deployedCode.runtimeBytecodeMatches must be true")
    expect(deployed_code.get("sha256") == hashlib.sha256(bytes.fromhex(runtime_hex)).hexdigest(), "deployedCode.sha256 mismatch")
    expect(deployed_code.get("bytes") == len(runtime_hex) // 2, "deployedCode.bytes mismatch")

    calls = expect_object(run.get("calls"), "calls")
    expect(calls.get("initialGet") == "0", "calls.initialGet mismatch")
    expect(calls.get("setValue") == "99", "calls.setValue mismatch")
    expect(calls.get("afterSetGet") == "99", "calls.afterSetGet mismatch")
    expect(calls.get("afterIncrementGet") == "100", "calls.afterIncrementGet mismatch")
    expect(calls.get("afterDecrementGet") == "99", "calls.afterDecrementGet mismatch")

    validation = expect_object(run.get("validation"), "validation")
    for key in (
        "anvilStarted",
        "chainId",
        "castCreate",
        "receipt",
        "runtimeCodeMatch",
        "counterLifecycle",
        "artifactMetadata",
    ):
        expect(validation.get(key) == "passed", f"validation.{key} must be passed")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
