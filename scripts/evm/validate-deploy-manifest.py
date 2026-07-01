#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    raise SystemExit(f"evm-deploy-validate: {message}")


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def expect_object(value: Any, name: str) -> dict:
    expect(isinstance(value, dict), f"{name} must be an object")
    return value


def expect_array(value: Any, name: str) -> list:
    expect(isinstance(value, list), f"{name} must be an array")
    return value


def expect_string(value: Any, name: str) -> str:
    expect(isinstance(value, str) and value, f"{name} must be a non-empty string")
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


def expect_hex_text(path: Path, name: str) -> str:
    value = path.read_text().strip()
    expect(value and all(ch in "0123456789abcdefABCDEF" for ch in value), f"{name} must be non-empty hex")
    return value


def validate_abi(abi: dict) -> None:
    entrypoints = expect_array(abi.get("entrypoints"), "abi.entrypoints")
    for idx, entry in enumerate(entrypoints):
        entry = expect_object(entry, f"abi.entrypoints[{idx}]")
        expect_string(entry.get("name"), f"abi.entrypoints[{idx}].name")
        expect_string(entry.get("selector"), f"abi.entrypoints[{idx}].selector")
        expect_array(entry.get("params"), f"abi.entrypoints[{idx}].params")
        expect_string(entry.get("returns"), f"abi.entrypoints[{idx}].returns")

    methods = expect_array(abi.get("methods"), "abi.methods")
    for idx, method in enumerate(methods):
        method = expect_object(method, f"abi.methods[{idx}]")
        expect_string(method.get("selector"), f"abi.methods[{idx}].selector")
        expect_string(method.get("fnName"), f"abi.methods[{idx}].fnName")
        expect(isinstance(method.get("argCount"), int), f"abi.methods[{idx}].argCount must be an integer")
        expect(isinstance(method.get("returnsValue"), bool), f"abi.methods[{idx}].returnsValue must be a boolean")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--expect-fixture")
    parser.add_argument("--expect-source-kind")
    parser.add_argument("manifest")
    args = parser.parse_args()

    root = Path(args.root)
    manifest = expect_object(json.loads(Path(args.manifest).read_text()), "manifest")

    expect(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    expect(manifest.get("kind") == "proof-forge-evm-deploy-manifest", "kind mismatch")
    expect(manifest.get("target") == "evm", "target must be evm")
    expect(manifest.get("targetFamily") == "evm", "targetFamily mismatch")
    expect(manifest.get("artifactKind") == "evm-runtime-bytecode-deploy", "artifactKind mismatch")
    if args.expect_fixture:
        expect(manifest.get("fixture") == args.expect_fixture, "fixture mismatch")
    else:
        expect_string(manifest.get("fixture"), "fixture")
    if args.expect_source_kind:
        expect(manifest.get("sourceKind") == args.expect_source_kind, "sourceKind mismatch")
    else:
        expect_string(manifest.get("sourceKind"), "sourceKind")
    expect_string(manifest.get("contractName"), "contractName")
    expect_string(manifest.get("sourceModule"), "sourceModule")
    expect(manifest.get("irVersion") is None or isinstance(manifest.get("irVersion"), str), "irVersion must be null or string")

    capabilities = expect_array(manifest.get("capabilities"), "capabilities")
    for idx, capability in enumerate(capabilities):
        expect_string(capability, f"capabilities[{idx}]")
    validate_abi(expect_object(manifest.get("abi"), "abi"))

    inputs = expect_object(manifest.get("inputs"), "inputs")
    file_entry(root, expect_object(inputs.get("yul"), "inputs.yul"), "inputs.yul")
    bytecode_path = file_entry(root, expect_object(inputs.get("bytecode"), "inputs.bytecode"), "inputs.bytecode")
    if "source" in inputs:
        file_entry(root, expect_object(inputs.get("source"), "inputs.source"), "inputs.source")
    expect_hex_text(bytecode_path, "inputs.bytecode")

    creation = expect_object(manifest.get("creation"), "creation")
    expect(creation.get("mode") == "runtime-bytecode", "creation.mode mismatch")
    expect(expect_array(creation.get("constructorArgs"), "creation.constructorArgs") == [], "creation.constructorArgs must be empty")
    expect(creation.get("initCode") is None, "creation.initCode must be null")
    runtime_entry = expect_object(creation.get("runtimeBytecode"), "creation.runtimeBytecode")
    runtime_path = file_entry(root, runtime_entry, "creation.runtimeBytecode")
    expect(runtime_entry == inputs["bytecode"], "creation.runtimeBytecode must match inputs.bytecode")
    expect(runtime_path.resolve() == bytecode_path.resolve(), "creation.runtimeBytecode path must match inputs.bytecode")

    deployment = expect_object(manifest.get("deployment"), "deployment")
    expect(deployment.get("chainId") is None, "deployment.chainId must be null before broadcast")
    expect(deployment.get("address") is None, "deployment.address must be null before broadcast")
    expect(deployment.get("broadcast") == "not-generated", "deployment.broadcast mismatch")
    expect_string(deployment.get("reason"), "deployment.reason")
    expect_string(deployment.get("reference"), "deployment.reference")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
