#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Optional


REQUIRED_ARTIFACTS = ("yul", "bytecode", "deployManifest")
REQUIRED_VALIDATIONS = ("solcStrictAssembly", "bytecodeGeneration", "deployManifest")


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


def file_entry(root: Path, entry: dict, name: str, prefix: str = "artifacts") -> Path:
    path = resolve_path(root, expect_string(entry.get("path"), f"{prefix}.{name}.path"))
    expect(path.is_file(), f"{prefix}.{name}.path does not exist: {path}")
    data = path.read_bytes()
    expect(entry.get("bytes") == len(data), f"{prefix}.{name}.bytes mismatch")
    expect(
        entry.get("sha256") == hashlib.sha256(data).hexdigest(),
        f"{prefix}.{name}.sha256 mismatch",
    )
    return path


def parse_expected_mapping(value: str, option: str) -> tuple[str, str]:
    if ":" not in value:
        fail(f"{option} expects name:selector")
    name, selector = value.split(":", 1)
    if not name or not selector:
        fail(f"{option} expects name:selector")
    return name, selector


def same_path(left: Path, right: Path) -> bool:
    return left.resolve() == right.resolve()


def expect_hex_text(path: Path, name: str) -> str:
    value = path.read_text().strip()
    expect(value and all(ch in "0123456789abcdefABCDEF" for ch in value), f"{name} must be non-empty hex")
    return value


def validate_deploy_manifest(
    root: Path,
    manifest_path: Path,
    metadata: dict,
    yul_path: Path,
    bytecode_path: Path,
    source_path: Optional[Path],
) -> None:
    manifest = expect_object(json.loads(manifest_path.read_text()), "deploy manifest")
    expect(manifest.get("schemaVersion") == 1, "deploy manifest schemaVersion must be 1")
    expect(manifest.get("kind") == "proof-forge-evm-deploy-manifest", "deploy manifest kind mismatch")
    expect(manifest.get("target") == "evm", "deploy manifest target must be evm")
    expect(manifest.get("targetFamily") == "evm", "deploy manifest targetFamily mismatch")
    expect(manifest.get("artifactKind") == "evm-runtime-bytecode-deploy", "deploy manifest artifactKind mismatch")
    expect(manifest.get("fixture") == metadata.get("fixture"), "deploy manifest fixture mismatch")
    expect_string(manifest.get("contractName"), "deploy manifest contractName")
    expect(manifest.get("sourceKind") == metadata.get("sourceKind"), "deploy manifest sourceKind mismatch")
    expect(manifest.get("sourceModule") == metadata.get("sourceModule"), "deploy manifest sourceModule mismatch")
    expect(manifest.get("irVersion") == metadata.get("irVersion"), "deploy manifest irVersion mismatch")
    expect(manifest.get("capabilities") == metadata.get("capabilities"), "deploy manifest capabilities mismatch")
    expect(manifest.get("abi") == metadata.get("abi"), "deploy manifest ABI mismatch")

    inputs = expect_object(manifest.get("inputs"), "deploy manifest inputs")
    manifest_yul = file_entry(root, expect_object(inputs.get("yul"), "inputs.yul"), "yul", "inputs")
    manifest_bytecode = file_entry(root, expect_object(inputs.get("bytecode"), "inputs.bytecode"), "bytecode", "inputs")
    expect(same_path(manifest_yul, yul_path), "deploy manifest inputs.yul must match metadata artifacts.yul")
    expect(same_path(manifest_bytecode, bytecode_path), "deploy manifest inputs.bytecode must match metadata artifacts.bytecode")
    if source_path is None:
        expect("source" not in inputs, "deploy manifest inputs.source must be absent when metadata has no source artifact")
    else:
        manifest_source = file_entry(root, expect_object(inputs.get("source"), "inputs.source"), "source", "inputs")
        expect(same_path(manifest_source, source_path), "deploy manifest inputs.source must match metadata artifacts.source")

    creation = expect_object(manifest.get("creation"), "deploy manifest creation")
    expect(creation.get("mode") == "runtime-bytecode", "deploy manifest creation.mode mismatch")
    constructor_args = expect_array(creation.get("constructorArgs"), "deploy manifest creation.constructorArgs")
    expect(constructor_args == [], "deploy manifest creation.constructorArgs must be empty for runtime-bytecode mode")
    expect(creation.get("initCode") is None, "deploy manifest creation.initCode must be null for runtime-bytecode mode")
    runtime_entry = expect_object(creation.get("runtimeBytecode"), "deploy manifest creation.runtimeBytecode")
    runtime_path = file_entry(root, runtime_entry, "runtimeBytecode", "creation")
    expect(same_path(runtime_path, bytecode_path), "deploy manifest runtimeBytecode must match metadata artifacts.bytecode")
    expect(runtime_entry == inputs["bytecode"], "deploy manifest runtimeBytecode entry must match inputs.bytecode")
    expect_hex_text(runtime_path, "deploy manifest runtimeBytecode")

    deployment = expect_object(manifest.get("deployment"), "deploy manifest deployment")
    expect(deployment.get("chainId") is None, "deploy manifest deployment.chainId must be null before broadcast")
    expect(deployment.get("address") is None, "deploy manifest deployment.address must be null before broadcast")
    expect(deployment.get("broadcast") == "not-generated", "deploy manifest deployment.broadcast mismatch")
    expect_string(deployment.get("reason"), "deploy manifest deployment.reason")
    expect_string(deployment.get("reference"), "deploy manifest deployment.reference")


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
    artifact_paths = {}
    for artifact_name in REQUIRED_ARTIFACTS:
        artifact_paths[artifact_name] = file_entry(
            root,
            expect_object(artifacts.get(artifact_name), f"artifacts.{artifact_name}"),
            artifact_name,
        )
    source_path = None
    if "source" in artifacts:
        source_path = file_entry(root, expect_object(artifacts.get("source"), "artifacts.source"), "source")

    yul_path = artifact_paths["yul"]
    bytecode_path = artifact_paths["bytecode"]
    deploy_manifest_path = artifact_paths["deployManifest"]
    expect_hex_text(bytecode_path, "artifacts.bytecode")

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

    validate_deploy_manifest(root, deploy_manifest_path, metadata, yul_path, bytecode_path, source_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
