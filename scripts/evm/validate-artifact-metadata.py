#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


REQUIRED_ARTIFACTS = ("yul", "bytecode")
REQUIRED_VALIDATIONS = ("solcStrictAssembly", "bytecodeGeneration")


def fail(message: str) -> None:
    raise SystemExit(f"evm-metadata-validate: {message}")


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
    path = resolve_path(root, expect_string(entry.get("path"), f"artifacts.{name}.path"))
    expect(path.is_file(), f"artifacts.{name}.path does not exist: {path}")
    data = path.read_bytes()
    expect(entry.get("bytes") == len(data), f"artifacts.{name}.bytes mismatch")
    expect(
        entry.get("sha256") == hashlib.sha256(data).hexdigest(),
        f"artifacts.{name}.sha256 mismatch",
    )
    return path


def parse_expected_mapping(value: str, option: str) -> tuple[str, str]:
    if ":" not in value:
        fail(f"{option} expects name:selector")
    name, selector = value.split(":", 1)
    if not name or not selector:
        fail(f"{option} expects name:selector")
    return name, selector


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--expect-fixture", required=True)
    parser.add_argument("--expect-source-kind")
    parser.add_argument("--expect-capability", action="append", default=[])
    parser.add_argument("--expect-entrypoint", action="append", default=[])
    parser.add_argument("metadata")
    args = parser.parse_args()

    root = Path(args.root)
    metadata_path = Path(args.metadata)
    metadata = expect_object(json.loads(metadata_path.read_text()), "metadata")

    expect(metadata.get("schemaVersion") == 1, "schemaVersion must be 1")
    expect(metadata.get("target") == "evm", "target must be evm")
    expect(metadata.get("targetFamily") == "evm", "targetFamily mismatch")
    expect(metadata.get("artifactKind") == "evm-bytecode", "artifactKind mismatch")
    expect(metadata.get("fixture") == args.expect_fixture, "fixture mismatch")
    expect_string(metadata.get("sourceModule"), "sourceModule")
    if args.expect_source_kind:
        expect(metadata.get("sourceKind") == args.expect_source_kind, "sourceKind mismatch")
        if args.expect_source_kind == "portable-ir":
            expect_string(metadata.get("irVersion"), "irVersion")
    else:
        expect_string(metadata.get("sourceKind"), "sourceKind")
    expect(metadata.get("irVersion") is None or isinstance(metadata.get("irVersion"), str), "irVersion must be null or string")

    capabilities = expect_array(metadata.get("capabilities"), "capabilities")
    for idx, capability in enumerate(capabilities):
        expect_string(capability, f"capabilities[{idx}]")
    for capability in args.expect_capability:
        expect(capability in capabilities, f"missing capability: {capability}")

    toolchain = expect_object(metadata.get("toolchain"), "toolchain")
    solc = expect_object(toolchain.get("solc"), "toolchain.solc")
    expect_string(solc.get("path"), "toolchain.solc.path")
    expect(solc.get("version") is None or isinstance(solc.get("version"), str), "toolchain.solc.version must be null or string")

    artifacts = expect_object(metadata.get("artifacts"), "artifacts")
    for artifact_name in REQUIRED_ARTIFACTS:
        file_entry(root, expect_object(artifacts.get(artifact_name), f"artifacts.{artifact_name}"), artifact_name)
    if "source" in artifacts:
        file_entry(root, expect_object(artifacts.get("source"), "artifacts.source"), "source")

    bytecode_path = resolve_path(root, artifacts["bytecode"]["path"])
    bytecode = bytecode_path.read_text().strip()
    expect(bytecode and all(ch in "0123456789abcdefABCDEF" for ch in bytecode), "artifacts.bytecode must be non-empty hex")

    abi = expect_object(metadata.get("abi"), "abi")
    entrypoints = expect_array(abi.get("entrypoints"), "abi.entrypoints")
    actual_entrypoints = {}
    for idx, entry in enumerate(entrypoints):
        entry = expect_object(entry, f"abi.entrypoints[{idx}]")
        actual_entrypoints[expect_string(entry.get("name"), f"abi.entrypoints[{idx}].name")] = expect_string(
            entry.get("selector"), f"abi.entrypoints[{idx}].selector"
        )
    for expected in args.expect_entrypoint:
        name, selector = parse_expected_mapping(expected, "--expect-entrypoint")
        expect(actual_entrypoints.get(name) == selector, f"entrypoint selector mismatch for {name}")

    methods = expect_array(abi.get("methods"), "abi.methods")
    for idx, method in enumerate(methods):
        method = expect_object(method, f"abi.methods[{idx}]")
        expect_string(method.get("selector"), f"abi.methods[{idx}].selector")
        expect_string(method.get("fnName"), f"abi.methods[{idx}].fnName")
        expect(isinstance(method.get("argCount"), int), f"abi.methods[{idx}].argCount must be an integer")
        expect(isinstance(method.get("returnsValue"), bool), f"abi.methods[{idx}].returnsValue must be a boolean")

    validation = expect_object(metadata.get("validation"), "validation")
    for key in REQUIRED_VALIDATIONS:
        expect(validation.get(key) == "passed", f"validation.{key} must be passed")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
