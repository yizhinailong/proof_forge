#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable EventProbe IR to EVM runtime bytecode
# and validate log emission through Foundry recorded logs.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-event-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Evm/EventProbe.golden.yul}"
METADATA_FILE="${IR_EVM_METADATA:-$OUT_DIR/EventProbe.proof-forge-artifact.json}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "event-ir-smoke: forge not found. Install Foundry, then re-run this script." >&2
  echo "event-ir-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "event-ir-smoke: solc not found on PATH." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" --emit-evm-event-ir-bytecode \
  --yul-output "$OUT_DIR/EventProbe.yul" \
  --artifact-output "$METADATA_FILE" \
  -o "$OUT_DIR/EventProbe.bin"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$OUT_DIR/EventProbe.yul"
fi

python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
  --root "$ROOT" \
  --expect-fixture EventProbe \
  --expect-source-kind portable-ir \
  --expect-capability events.emit \
  --expect-entrypoint emit_value_event:2ae8cae3 \
  "$METADATA_FILE"

probe_hex="$(tr -d '\n' < "$OUT_DIR/EventProbe.bin")"

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

cat > "$FORGE_DIR/test/ProofForgeIREventSmoke.t.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract ProofForgeIREventSmokeTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool value) internal pure {
        require(value, "assertTrue failed");
    }

    function assertFalse(bool value) internal pure {
        require(!value, "assertFalse failed");
    }

    function assertEq(uint256 actual, uint256 expected) internal pure {
        require(actual == expected, "assertEq(uint256) failed");
    }

    function assertEq(address actual, address expected) internal pure {
        require(actual == expected, "assertEq(address) failed");
    }

    function assertEq(bytes32 actual, bytes32 expected) internal pure {
        require(actual == expected, "assertEq(bytes32) failed");
    }

    function deployRuntime(bytes memory code, address target) internal {
        vm.etch(target, code);
    }

    function testIREventEmitsNamedTopicAndData() public {
        address probe = address(uint160(0xE130));
        deployRuntime(hex"$probe_hex", probe);

        vm.recordLogs();
        (bool ok, bytes memory result) =
            probe.call(abi.encodeWithSignature("emit_value_event(uint256)", 42));
        assertTrue(ok);
        assertEq(result.length, 0);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, probe);
        assertEq(logs[0].topics.length, 1);
        assertEq(logs[0].topics[0], keccak256(bytes("ValueEvent")));
        assertEq(abi.decode(logs[0].data, (uint256)), 42);
    }

    function testIREventRejectsUnknownSelector() public {
        address probe = address(uint160(0xE131));
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(hex"ffffffff");
        assertFalse(ok);
    }
}
SOL

forge test --root "$FORGE_DIR" -vv

echo "event-ir-smoke: ProofForge metadata $METADATA_FILE"
