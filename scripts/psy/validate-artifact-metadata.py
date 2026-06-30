#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


REQUIRED_ARTIFACTS = ("source", "circuitJson", "abiJson", "executeLog")
REQUIRED_VALIDATIONS = ("dargoTest", "dargoCompile", "dargoExecute", "dargoGenerateAbi")


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"psy-metadata-validate: {message}")


def expect_object(value: Any, name: str) -> dict:
    expect(isinstance(value, dict), f"{name} must be an object")
    return value


def expect_string(value: Any, name: str) -> str:
    expect(isinstance(value, str) and value, f"{name} must be a non-empty string")
    return value


def file_entry(root: Path, entry: dict, name: str) -> Path:
    path = root / expect_string(entry.get("path"), f"artifacts.{name}.path")
    expect(path.is_file(), f"artifacts.{name}.path does not exist: {path}")
    data = path.read_bytes()
    expect(entry.get("bytes") == len(data), f"artifacts.{name}.bytes mismatch")
    expect(
        entry.get("sha256") == hashlib.sha256(data).hexdigest(),
        f"artifacts.{name}.sha256 mismatch",
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("metadata")
    args = parser.parse_args()

    root = Path(args.root)
    metadata_path = Path(args.metadata)
    metadata = expect_object(json.loads(metadata_path.read_text()), "metadata")

    expect(metadata.get("schemaVersion") == 1, "schemaVersion must be 1")
    expect(metadata.get("target") == "psy-dpn", "target must be psy-dpn")
    expect(metadata.get("targetFamily") == "zk-circuit-sourcegen", "targetFamily mismatch")
    expect(metadata.get("artifactKind") == "psy-circuit-json", "artifactKind mismatch")
    expect_string(metadata.get("fixture"), "fixture")

    capabilities = metadata.get("capabilities")
    expect(isinstance(capabilities, list) and capabilities, "capabilities must be a non-empty array")
    for idx, capability in enumerate(capabilities):
        expect_string(capability, f"capabilities[{idx}]")

    toolchain = expect_object(metadata.get("toolchain"), "toolchain")
    dargo = expect_object(toolchain.get("dargo"), "toolchain.dargo")
    expect_string(dargo.get("path"), "toolchain.dargo.path")
    expect(dargo.get("version") is None or isinstance(dargo.get("version"), str), "toolchain.dargo.version must be null or string")

    artifacts = expect_object(metadata.get("artifacts"), "artifacts")
    for artifact_name in REQUIRED_ARTIFACTS:
        file_entry(root, expect_object(artifacts.get(artifact_name), f"artifacts.{artifact_name}"), artifact_name)

    validation = expect_object(metadata.get("validation"), "validation")
    for key in REQUIRED_VALIDATIONS:
        expect(validation.get(key) == "passed", f"validation.{key} must be passed")
    execute_result = expect_string(validation.get("executeResult"), "validation.executeResult")

    execute_log = (root / artifacts["executeLog"]["path"]).read_text()
    for expected in [part.strip() for part in execute_result.split(";") if part.strip()]:
        expect(expected in execute_log, f"execute log does not contain expected result: {expected}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
