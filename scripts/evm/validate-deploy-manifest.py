#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Optional


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


def expect_optional_string(value: Any, name: str) -> None:
    expect(value is None or (isinstance(value, str) and value), f"{name} must be null or a non-empty string")


def normalize_hex(value: str, name: str) -> str:
    text = value[2:] if value.startswith(("0x", "0X")) else value
    expect(all(ch in "0123456789abcdefABCDEF" for ch in text), f"{name} must contain only hex digits")
    expect(len(text) % 2 == 0, f"{name} must have an even number of hex digits")
    return text.lower()


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
    expect(len(value) % 2 == 0, f"{name} must have an even number of hex digits")
    return value


def read_push_value(init_hex: str, offset: int, name: str) -> tuple[int, int]:
    expect(offset + 2 <= len(init_hex), f"{name} is missing PUSH opcode")
    opcode = int(init_hex[offset : offset + 2], 16)
    expect(0x60 <= opcode <= 0x7F, f"{name} must use PUSH1..PUSH32")
    width = opcode - 0x5F
    data_start = offset + 2
    data_end = data_start + width * 2
    expect(data_end <= len(init_hex), f"{name} PUSH data is truncated")
    return int(init_hex[data_start:data_end], 16), data_end


def validate_constructor_args(constructor_args: list, expected_hex: Optional[str]) -> str:
    if expected_hex is not None:
        expected_hex = normalize_hex(expected_hex, "--expect-constructor-args-hex")

    if constructor_args == []:
        actual_hex = ""
    else:
        expect(len(constructor_args) == 1, "creation.constructorArgs supports one ABI-encoded argument blob")
        arg = expect_object(constructor_args[0], "creation.constructorArgs[0]")
        expect(arg.get("encoding") == "abi-encoded", "creation.constructorArgs[0].encoding mismatch")
        actual_hex = normalize_hex(expect_string(arg.get("hex"), "creation.constructorArgs[0].hex"), "creation.constructorArgs[0].hex")
        arg_bytes = bytes.fromhex(actual_hex)
        expect(arg.get("bytes") == len(arg_bytes), "creation.constructorArgs[0].bytes mismatch")
        expect(arg.get("sha256") == hashlib.sha256(arg_bytes).hexdigest(), "creation.constructorArgs[0].sha256 mismatch")
        expect(arg.get("source") == "--evm-constructor-args-hex", "creation.constructorArgs[0].source mismatch")

    if expected_hex is not None:
        expect(actual_hex == expected_hex, "creation.constructorArgs hex mismatch")
    return actual_hex


def validate_deployment_init_code(init_path: Path, runtime_path: Path, constructor_args_hex: str, prefix: str) -> None:
    init_hex = expect_hex_text(init_path, f"{prefix}.initCode")
    runtime_hex = expect_hex_text(runtime_path, f"{prefix}.runtimeBytecode")
    runtime_size = len(runtime_hex) // 2

    size, offset = read_push_value(init_hex, 0, f"{prefix}.initCode.runtimeSize")
    code_offset, offset = read_push_value(init_hex, offset, f"{prefix}.initCode.codeOffset")
    expect(init_hex[offset : offset + 6].lower() == "600039", f"{prefix}.initCode must copy runtime to memory")
    offset += 6
    return_size, offset = read_push_value(init_hex, offset, f"{prefix}.initCode.returnSize")
    expect(init_hex[offset : offset + 6].lower() == "6000f3", f"{prefix}.initCode must return copied runtime")
    offset += 6

    expect(size == runtime_size, f"{prefix}.initCode runtime size mismatch")
    expect(return_size == runtime_size, f"{prefix}.initCode return size mismatch")
    expect(code_offset == offset // 2, f"{prefix}.initCode code offset mismatch")
    runtime_end = offset + len(runtime_hex)
    expect(init_hex[offset:runtime_end].lower() == runtime_hex.lower(), f"{prefix}.initCode runtime segment mismatch")
    expect(init_hex[runtime_end:].lower() == constructor_args_hex, f"{prefix}.initCode constructor args suffix mismatch")


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


def validate_chain_profile(manifest: dict, expected_profile: Optional[str], expected_chain_id: Optional[int]) -> None:
    profile_value = manifest.get("chainProfile")
    deployment = expect_object(manifest.get("deployment"), "deployment")

    if profile_value is None:
        expect(expected_profile is None, "chainProfile is missing")
        expect(expected_chain_id is None, "chainProfile.chainId is missing")
        expect(deployment.get("profileId") is None, "deployment.profileId must be null without chain profile")
        expect(deployment.get("chainId") is None, "deployment.chainId must be null without chain profile")
        expect(deployment.get("networkName") is None, "deployment.networkName must be null without chain profile")
        expect(expect_array(deployment.get("rpcUrls"), "deployment.rpcUrls") == [], "deployment.rpcUrls must be empty without chain profile")
        expect(deployment.get("blockExplorerUrl") is None, "deployment.blockExplorerUrl must be null without chain profile")
        expect(deployment.get("verifier") is None, "deployment.verifier must be null without chain profile")
        expect(deployment.get("verifierUrl") is None, "deployment.verifierUrl must be null without chain profile")
    else:
        profile = expect_object(profile_value, "chainProfile")
        profile_id = expect_string(profile.get("id"), "chainProfile.id")
        if expected_profile is not None:
            expect(profile_id == expected_profile, "chainProfile.id mismatch")
        expect(profile.get("targetId") == "evm", "chainProfile.targetId must be evm")
        expect_string(profile.get("networkName"), "chainProfile.networkName")
        chain_id = profile.get("chainId")
        expect(isinstance(chain_id, int), "chainProfile.chainId must be an integer")
        if expected_chain_id is not None:
            expect(chain_id == expected_chain_id, "chainProfile.chainId mismatch")
        expect_string(profile.get("nativeCurrencySymbol"), "chainProfile.nativeCurrencySymbol")
        expect_optional_string(profile.get("rollupFamily"), "chainProfile.rollupFamily")
        expect_optional_string(profile.get("dataAvailability"), "chainProfile.dataAvailability")
        for field_name in ("rpcUrls", "websocketUrls", "sequencerUrls", "notes"):
            values = expect_array(profile.get(field_name), f"chainProfile.{field_name}")
            for idx, value in enumerate(values):
                expect_string(value, f"chainProfile.{field_name}[{idx}]")
        expect_optional_string(profile.get("blockExplorerUrl"), "chainProfile.blockExplorerUrl")
        expect_optional_string(profile.get("verifier"), "chainProfile.verifier")
        expect_optional_string(profile.get("verifierUrl"), "chainProfile.verifierUrl")

        expect(deployment.get("profileId") == profile_id, "deployment.profileId mismatch")
        expect(deployment.get("chainId") == chain_id, "deployment.chainId mismatch")
        expect(deployment.get("networkName") == profile.get("networkName"), "deployment.networkName mismatch")
        expect(deployment.get("rpcUrls") == profile.get("rpcUrls"), "deployment.rpcUrls mismatch")
        expect(deployment.get("blockExplorerUrl") == profile.get("blockExplorerUrl"), "deployment.blockExplorerUrl mismatch")
        expect(deployment.get("verifier") == profile.get("verifier"), "deployment.verifier mismatch")
        expect(deployment.get("verifierUrl") == profile.get("verifierUrl"), "deployment.verifierUrl mismatch")

    expect(deployment.get("address") is None, "deployment.address must be null before broadcast")
    expect(deployment.get("broadcast") == "not-generated", "deployment.broadcast mismatch")
    expect(deployment.get("broadcastArtifact") is None, "deployment.broadcastArtifact must be null before broadcast")
    expect_string(deployment.get("reason"), "deployment.reason")
    expect_string(deployment.get("reference"), "deployment.reference")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--expect-fixture")
    parser.add_argument("--expect-source-kind")
    parser.add_argument("--expect-chain-profile")
    parser.add_argument("--expect-chain-id", type=int)
    parser.add_argument("--expect-constructor-args-hex")
    parser.add_argument("manifest")
    args = parser.parse_args()

    root = Path(args.root)
    manifest = expect_object(json.loads(Path(args.manifest).read_text()), "manifest")

    expect(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    expect(manifest.get("kind") == "proof-forge-evm-deploy-manifest", "kind mismatch")
    expect(manifest.get("target") == "evm", "target must be evm")
    expect(manifest.get("targetFamily") == "evm", "targetFamily mismatch")
    expect(manifest.get("artifactKind") == "evm-initcode-deploy", "artifactKind mismatch")
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
    validate_chain_profile(manifest, args.expect_chain_profile, args.expect_chain_id)

    capabilities = expect_array(manifest.get("capabilities"), "capabilities")
    for idx, capability in enumerate(capabilities):
        expect_string(capability, f"capabilities[{idx}]")
    validate_abi(expect_object(manifest.get("abi"), "abi"))

    inputs = expect_object(manifest.get("inputs"), "inputs")
    file_entry(root, expect_object(inputs.get("yul"), "inputs.yul"), "inputs.yul")
    bytecode_path = file_entry(root, expect_object(inputs.get("bytecode"), "inputs.bytecode"), "inputs.bytecode")
    init_code_path = file_entry(root, expect_object(inputs.get("initCode"), "inputs.initCode"), "inputs.initCode")
    if "source" in inputs:
        file_entry(root, expect_object(inputs.get("source"), "inputs.source"), "inputs.source")
    expect_hex_text(bytecode_path, "inputs.bytecode")

    creation = expect_object(manifest.get("creation"), "creation")
    expect(creation.get("mode") == "init-code", "creation.mode mismatch")
    constructor_args_hex = validate_constructor_args(
        expect_array(creation.get("constructorArgs"), "creation.constructorArgs"),
        args.expect_constructor_args_hex,
    )
    init_code_entry = expect_object(creation.get("initCode"), "creation.initCode")
    creation_init_code_path = file_entry(root, init_code_entry, "creation.initCode")
    expect(init_code_entry == inputs["initCode"], "creation.initCode must match inputs.initCode")
    expect(creation_init_code_path.resolve() == init_code_path.resolve(), "creation.initCode path must match inputs.initCode")
    runtime_entry = expect_object(creation.get("runtimeBytecode"), "creation.runtimeBytecode")
    runtime_path = file_entry(root, runtime_entry, "creation.runtimeBytecode")
    expect(runtime_entry == inputs["bytecode"], "creation.runtimeBytecode must match inputs.bytecode")
    expect(runtime_path.resolve() == bytecode_path.resolve(), "creation.runtimeBytecode path must match inputs.bytecode")
    validate_deployment_init_code(creation_init_code_path, runtime_path, constructor_args_hex, "creation")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
