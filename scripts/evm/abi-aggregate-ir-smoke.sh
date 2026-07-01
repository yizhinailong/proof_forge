#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable EvmAbiAggregateProbe IR to EVM runtime
# bytecode and validate flat static aggregate ABI encoding through Foundry.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-abi-aggregate-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Evm/EvmAbiAggregateProbe.golden.yul}"
METADATA_FILE="${IR_EVM_METADATA:-$OUT_DIR/EvmAbiAggregateProbe.proof-forge-artifact.json}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "abi-aggregate-ir-smoke: forge not found. Install Foundry, then re-run this script." >&2
  echo "abi-aggregate-ir-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "abi-aggregate-ir-smoke: solc not found on PATH." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" --emit-evm-abi-aggregate-ir-bytecode \
  --yul-output "$OUT_DIR/EvmAbiAggregateProbe.yul" \
  --artifact-output "$METADATA_FILE" \
  -o "$OUT_DIR/EvmAbiAggregateProbe.bin"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$OUT_DIR/EvmAbiAggregateProbe.yul"
fi

python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
  --root "$ROOT" \
  --expect-fixture EvmAbiAggregateProbe \
  --expect-source-kind portable-ir \
  --expect-capability data.fixed_array \
  --expect-capability data.struct \
  --expect-entrypoint sum_pair:25508e13 \
  --expect-entrypoint sum_array:eb353b80 \
  --expect-entrypoint make_pair:ef51ff62 \
  --expect-entrypoint make_array:ffac5c16 \
  --expect-entrypoint sum_small:384e9976 \
  --expect-entrypoint and_flags:1df89823 \
  "$METADATA_FILE"

probe_hex="$(tr -d '\n' < "$OUT_DIR/EvmAbiAggregateProbe.bin")"

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

cat > "$FORGE_DIR/test/ProofForgeIRAbiAggregateSmoke.t.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
}

contract ProofForgeIRAbiAggregateSmokeTest {
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

    function assertEq(bool actual, bool expected) internal pure {
        require(actual == expected, "assertEq(bool) failed");
    }

    function deployRuntime(bytes memory code, address target) internal {
        vm.etch(target, code);
    }

    function callBytes(address probe, bytes memory payload) internal returns (bytes memory) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return result;
    }

    function callU256(address probe, bytes memory payload) internal returns (uint256) {
        return abi.decode(callBytes(probe, payload), (uint256));
    }

    function testIRAbiAggregateParameters() public {
        address probe = address(uint160(0xA280));
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(probe, abi.encodeWithSignature("sum_pair((uint256,uint256))", uint256(7), uint256(8))),
            15
        );

        uint256[3] memory xs = [uint256(2), uint256(3), uint256(5)];
        assertEq(callU256(probe, abi.encodeWithSignature("sum_array(uint256[3])", xs)), 10);

        uint32[2] memory smalls = [uint32(17), uint32(19)];
        assertEq(callU256(probe, abi.encodeWithSignature("sum_small(uint32[2])", smalls)), 36);

        assertFalse(abi.decode(
            callBytes(probe, abi.encodeWithSignature("and_flags((bool,bool))", true, false)),
            (bool)
        ));
    }

    function testIRAbiAggregateReturns() public {
        address probe = address(uint160(0xA281));
        deployRuntime(hex"$probe_hex", probe);

        bytes memory pairResult =
            callBytes(probe, abi.encodeWithSignature("make_pair(uint256,uint256)", uint256(21), uint256(34)));
        (uint256 left, uint256 right) = abi.decode(pairResult, (uint256, uint256));
        assertEq(left, 21);
        assertEq(right, 34);

        uint256[3] memory ys = abi.decode(
            callBytes(
                probe,
                abi.encodeWithSignature("make_array(uint256,uint256,uint256)", uint256(5), uint256(8), uint256(13))
            ),
            (uint256[3])
        );
        assertEq(ys[0], 5);
        assertEq(ys[1], 8);
        assertEq(ys[2], 13);
    }

    function testIRAbiAggregateRejectsMalformedCalldata() public {
        address probe = address(uint160(0xA282));
        deployRuntime(hex"$probe_hex", probe);

        bytes4 sumArraySelector = bytes4(keccak256("sum_array(uint256[3])"));
        (bool shortArrayOk,) = probe.call(abi.encodePacked(sumArraySelector, uint256(1)));
        assertFalse(shortArrayOk);

        bytes4 sumSmallSelector = bytes4(keccak256("sum_small(uint32[2])"));
        (bool overflowU32Ok,) = probe.call(abi.encodePacked(
            sumSmallSelector,
            uint256(type(uint32).max) + 1,
            uint256(1)
        ));
        assertFalse(overflowU32Ok);

        bytes4 flagsSelector = bytes4(keccak256("and_flags((bool,bool))"));
        (bool invalidBoolOk,) = probe.call(abi.encodePacked(flagsSelector, uint256(2), uint256(1)));
        assertFalse(invalidBoolOk);

        (bool unknownOk,) = probe.call(hex"ffffffff");
        assertFalse(unknownOk);
    }
}
SOL

forge test --root "$FORGE_DIR" -vv

echo "abi-aggregate-ir-smoke: ProofForge metadata $METADATA_FILE"
