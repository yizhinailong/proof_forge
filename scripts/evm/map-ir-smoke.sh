#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable EvmMapProbe IR to EVM runtime bytecode
# and validate Solidity-style mapping slots through Foundry.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-map-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Evm/EvmMapProbe.golden.yul}"
METADATA_FILE="${IR_EVM_METADATA:-$OUT_DIR/EvmMapProbe.proof-forge-artifact.json}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "map-ir-smoke: forge not found. Install Foundry, then re-run this script." >&2
  echo "map-ir-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "map-ir-smoke: solc not found on PATH." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" --emit-evm-map-ir-bytecode \
  --yul-output "$OUT_DIR/EvmMapProbe.yul" \
  --artifact-output "$METADATA_FILE" \
  -o "$OUT_DIR/EvmMapProbe.bin"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$OUT_DIR/EvmMapProbe.yul"
fi

python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
  --root "$ROOT" \
  --expect-fixture EvmMapProbe \
  --expect-source-kind portable-ir \
  --expect-capability storage.scalar \
  --expect-capability storage.map \
  --expect-capability assertions.check \
  --expect-entrypoint map_lifecycle:3bb39394 \
  --expect-entrypoint get_seed_balance:541be503 \
  --expect-entrypoint read_balance:68eb1eef \
  --expect-entrypoint upsert_balance:e1de6ac8 \
  --expect-entrypoint set_balance:b41d1f5c \
  --expect-entrypoint path_lifecycle:84c21205 \
  --expect-entrypoint path_assign_lifecycle:bce9e77b \
  "$METADATA_FILE"

probe_hex="$(tr -d '\n' < "$OUT_DIR/EvmMapProbe.bin")"

rm -rf "$FORGE_DIR"
mkdir -p "$FORGE_DIR/test"

cat > "$FORGE_DIR/foundry.toml" <<'TOML'
[profile.default]
src = "src"
test = "test"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
optimizer = true
optimizer_runs = 200
via_ir = true
TOML

cat > "$FORGE_DIR/test/ProofForgeIRMapSmoke.t.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function load(address target, bytes32 slot) external view returns (bytes32);
}

contract ProofForgeIRMapSmokeTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool value) internal pure {
        require(value, "assertTrue failed");
    }

    function assertFalse(bool value) internal pure {
        require(!value, "assertFalse failed");
    }

    function assertEq(uint256 actual, uint256 expected) internal pure {
        require(actual == expected, "assertEq failed");
    }

    function deployRuntime(bytes memory code, address target) internal {
        vm.etch(target, code);
    }

    function mapSlot(uint256 key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, uint256(1)));
    }

    function readStorage(address target, bytes32 slot) internal view returns (uint256) {
        return uint256(vm.load(target, slot));
    }

    function callU256(address probe, bytes memory payload) internal returns (uint256) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return abi.decode(result, (uint256));
    }

    function testIRMapLifecycleUsesSolidityMappingSlot() public {
        address probe = address(uint160(0xE110));
        deployRuntime(hex"$probe_hex", probe);

        assertEq(callU256(probe, abi.encodeWithSignature("map_lifecycle()")), 55);
        assertEq(callU256(probe, abi.encodeWithSignature("get_seed_balance()")), 55);

        assertEq(readStorage(probe, bytes32(uint256(0))), 111);
        assertEq(readStorage(probe, bytes32(uint256(1))), 0);
        assertEq(readStorage(probe, bytes32(uint256(2))), 222);
        assertEq(readStorage(probe, mapSlot(1001)), 55);
    }

    function testIRMapParameterizedReadWrite() public {
        address probe = address(uint160(0xE111));
        deployRuntime(hex"$probe_hex", probe);

        assertEq(callU256(probe, abi.encodeWithSignature("read_balance(uint256)", 9001)), 0);
        assertEq(callU256(probe, abi.encodeWithSignature("upsert_balance(uint256,uint256)", 9001, 123)), 0);
        assertEq(callU256(probe, abi.encodeWithSignature("read_balance(uint256)", 9001)), 123);
        assertEq(callU256(probe, abi.encodeWithSignature("upsert_balance(uint256,uint256)", 9001, 456)), 123);
        assertEq(callU256(probe, abi.encodeWithSignature("read_balance(uint256)", 9001)), 456);

        (bool ok, bytes memory result) =
            probe.call(abi.encodeWithSignature("set_balance(uint256,uint256)", 9001, 789));
        assertTrue(ok);
        assertEq(result.length, 0);
        assertEq(callU256(probe, abi.encodeWithSignature("read_balance(uint256)", 9001)), 789);
        assertEq(readStorage(probe, mapSlot(9001)), 789);
    }

    function testIRMapStoragePath() public {
        address probe = address(uint160(0xE112));
        deployRuntime(hex"$probe_hex", probe);

        assertEq(callU256(probe, abi.encodeWithSignature("path_lifecycle()")), 77);
        assertEq(readStorage(probe, mapSlot(2002)), 77);
    }

    function testIRMapStoragePathCompoundAssignment() public {
        address probe = address(uint160(0xE114));
        deployRuntime(hex"$probe_hex", probe);

        assertEq(callU256(probe, abi.encodeWithSignature("path_assign_lifecycle()")), 58);
        assertEq(readStorage(probe, mapSlot(3003)), 58);
    }

    function testIRMapRejectsUnknownSelector() public {
        address probe = address(uint160(0xE113));
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(hex"ffffffff");
        assertFalse(ok);
    }
}
SOL

forge test --root "$FORGE_DIR" -vv

echo "map-ir-smoke: ProofForge metadata $METADATA_FILE"
