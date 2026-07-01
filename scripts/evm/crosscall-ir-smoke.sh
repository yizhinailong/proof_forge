#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable EvmCrosscallProbe IR to EVM runtime
# bytecode and validate synchronous scalar-word calls through Foundry.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-crosscall-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Evm/EvmCrosscallProbe.golden.yul}"
METADATA_FILE="${IR_EVM_METADATA:-$OUT_DIR/EvmCrosscallProbe.proof-forge-artifact.json}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "crosscall-ir-smoke: forge not found. Install Foundry, then re-run this script." >&2
  echo "crosscall-ir-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "crosscall-ir-smoke: solc not found on PATH." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" --emit-evm-crosscall-ir-bytecode \
  --yul-output "$OUT_DIR/EvmCrosscallProbe.yul" \
  --artifact-output "$METADATA_FILE" \
  -o "$OUT_DIR/EvmCrosscallProbe.bin"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$OUT_DIR/EvmCrosscallProbe.yul"
fi

python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
  --root "$ROOT" \
  --expect-fixture EvmCrosscallProbe \
  --expect-source-kind portable-ir \
  --expect-capability crosscall.invoke \
  --expect-entrypoint call_remote:0de1d044 \
  --expect-entrypoint call_remote1:7ec7d7f8 \
  --expect-entrypoint call_remote2:ff5ce87f \
  --expect-entrypoint call_remote_bool:6a7b13b8 \
  --expect-entrypoint call_remote_u32:0f35944c \
  --expect-entrypoint call_remote_hash:6a5317aa \
  --expect-entrypoint call_remote_pair:47c6c9b7 \
  --expect-entrypoint call_remote_array:717d6851 \
  --expect-entrypoint call_remote_value:365f4a44 \
  --expect-entrypoint call_remote_static:d13203a8 \
  --expect-entrypoint call_remote_static_bool:ae266f0a \
  --expect-entrypoint call_remote_static_u32:ec8c40f9 \
  --expect-entrypoint call_remote_static_hash:4e0edd3c \
  --expect-entrypoint call_remote_delegate:427320b1 \
  --expect-entrypoint call_remote_delegate_bool:62e5114d \
  --expect-entrypoint call_remote_delegate_u32:e3abe276 \
  --expect-entrypoint call_remote_delegate_hash:6a2c2006 \
  "$METADATA_FILE"

probe_hex="$(tr -d '\n' < "$OUT_DIR/EvmCrosscallProbe.bin")"

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

cat > "$FORGE_DIR/test/ProofForgeIRCrosscallSmoke.t.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function deal(address target, uint256 newBalance) external;
}

contract CrosscallCallee {
    uint256 public stored = 88;

    function answer() external pure returns (uint256) {
        return 42;
    }

    function plusOne(uint256 x) external pure returns (uint256) {
        return x + 1;
    }

    function sum(uint256 x, uint256 y) external pure returns (uint256) {
        return x + y;
    }

    function notFlag(bool flag) external pure returns (bool) {
        return !flag;
    }

    function plusSmall(uint32 x) external pure returns (uint32) {
        return x + 7;
    }

    function echoHash(bytes32 value) external pure returns (bytes32) {
        return value;
    }

    function pair() external pure returns (bool, uint32) {
        return (true, 42);
    }

    function pairInvalidBool() external pure returns (uint256, uint256) {
        return (2, 42);
    }

    function pairInvalidU32() external pure returns (uint256, uint256) {
        return (1, uint256(type(uint32).max) + 1);
    }

    function values2() external pure returns (uint64[2] memory values) {
        values[0] = 33;
        values[1] = 44;
    }

    function paid() external payable returns (uint256) {
        return msg.value;
    }

    function readStored() external view returns (uint256) {
        return stored;
    }

    function writeStored() external returns (uint256) {
        stored = 777;
        return stored;
    }

    function invalidBool(bool) external pure returns (uint256) {
        return 2;
    }

    function invalidU32(uint32) external pure returns (uint256) {
        return uint256(type(uint32).max) + 1;
    }

    function noReturn() external pure {}

    function fail() external pure {
        revert("callee failed");
    }
}

contract ProofForgeIRCrosscallSmokeTest {
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

    function assertEq(bytes32 actual, bytes32 expected) internal pure {
        require(actual == expected, "assertEq(bytes32) failed");
    }

    function deployRuntime(bytes memory code, address target) internal {
        vm.etch(target, code);
    }

    function selector(bytes4 value) internal pure returns (uint256) {
        return uint256(uint32(value));
    }

    function callU256(address probe, bytes memory payload) internal returns (uint256) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return abi.decode(result, (uint256));
    }

    function callU256Value(address probe, bytes memory payload, uint256 amount) internal returns (uint256) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        return abi.decode(result, (uint256));
    }

    function callBool(address probe, bytes memory payload) internal returns (bool) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return abi.decode(result, (bool));
    }

    function callU32(address probe, bytes memory payload) internal returns (uint32) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return abi.decode(result, (uint32));
    }

    function callHash(address probe, bytes memory payload) internal returns (bytes32) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        return abi.decode(result, (bytes32));
    }

    function callPair(address probe, bytes memory payload) internal returns (bool flag, uint32 small) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        (flag, small) = abi.decode(result, (bool, uint32));
    }

    function callU64Array2(address probe, bytes memory payload) internal returns (uint64[2] memory values) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        values = abi.decode(result, (uint64[2]));
    }

    function testIRCrosscallNoArgs() public {
        address probe = address(uint160(0xE140));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.answer.selector)
                )
            ),
            42
        );
    }

    function testIRCrosscallOneArg() public {
        address probe = address(uint160(0xE141));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote1(uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.plusOne.selector),
                    99
                )
            ),
            100
        );
    }

    function testIRCrosscallTwoArgs() public {
        address probe = address(uint160(0xE142));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote2(uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.sum.selector),
                    21,
                    34
                )
            ),
            55
        );
    }

    function testIRCrosscallBoolReturn() public {
        address probe = address(uint160(0xE146));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertTrue(
            callBool(
                probe,
                abi.encodeWithSignature(
                    "call_remote_bool(uint256,uint256,bool)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.notFlag.selector),
                    false
                )
            )
        );
    }

    function testIRCrosscallU32Return() public {
        address probe = address(uint160(0xE147));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            uint256(
                callU32(
                    probe,
                    abi.encodeWithSignature(
                        "call_remote_u32(uint256,uint256,uint32)",
                        uint256(uint160(address(callee))),
                        selector(CrosscallCallee.plusSmall.selector),
                        uint32(35)
                    )
                )
            ),
            42
        );
    }

    function testIRCrosscallHashReturn() public {
        address probe = address(uint160(0xE148));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        bytes32 value = keccak256("proof-forge-crosscall-hash");

        assertEq(
            callHash(
                probe,
                abi.encodeWithSignature(
                    "call_remote_hash(uint256,uint256,bytes32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.echoHash.selector),
                    value
                )
            ),
            value
        );
    }

    function testIRCrosscallAggregateStructReturn() public {
        address probe = address(uint160(0xE15A));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool flag, uint32 small) = callPair(
            probe,
            abi.encodeWithSignature(
                "call_remote_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pair.selector)
            )
        );
        assertTrue(flag);
        assertEq(uint256(small), 42);
    }

    function testIRCrosscallAggregateArrayReturn() public {
        address probe = address(uint160(0xE15B));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2] memory values = callU64Array2(
            probe,
            abi.encodeWithSignature(
                "call_remote_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.values2.selector)
            )
        );
        assertEq(uint256(values[0]), 33);
        assertEq(uint256(values[1]), 44);
    }

    function testIRCrosscallForwardsNativeValue() public {
        address probe = address(uint160(0xE14B));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        assertEq(
            callU256Value(
                probe,
                abi.encodeWithSignature(
                    "call_remote_value(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.paid.selector)
                ),
                1234
            ),
            1234
        );
        assertEq(address(callee).balance, 1234);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallStaticReturn() public {
        address probe = address(uint160(0xE14C));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.readStored.selector)
                )
            ),
            88
        );
    }

    function testIRCrosscallStaticBoolReturn() public {
        address probe = address(uint160(0xE14E));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertTrue(
            callBool(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static_bool(uint256,uint256,bool)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.notFlag.selector),
                    false
                )
            )
        );
    }

    function testIRCrosscallStaticU32Return() public {
        address probe = address(uint160(0xE14F));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            uint256(
                callU32(
                    probe,
                    abi.encodeWithSignature(
                        "call_remote_static_u32(uint256,uint256,uint32)",
                        uint256(uint160(address(callee))),
                        selector(CrosscallCallee.plusSmall.selector),
                        uint32(35)
                    )
                )
            ),
            42
        );
    }

    function testIRCrosscallStaticHashReturn() public {
        address probe = address(uint160(0xE150));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        bytes32 value = keccak256("proof-forge-static-crosscall-hash");

        assertEq(
            callHash(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static_hash(uint256,uint256,bytes32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.echoHash.selector),
                    value
                )
            ),
            value
        );
    }

    function testIRCrosscallStaticRejectsStateWrite() public {
        address probe = address(uint160(0xE14D));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_static(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.writeStored.selector)
            )
        );
        assertFalse(ok);
        assertEq(callee.stored(), 88);
    }

    function testIRCrosscallRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE149));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_bool(uint256,uint256,bool)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidBool.selector),
                true
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE14A));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_u32(uint256,uint256,uint32)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidU32.selector),
                uint32(1)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallAggregateRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE15C));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairInvalidBool.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallAggregateRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE15D));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairInvalidU32.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallStaticRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE151));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_static_bool(uint256,uint256,bool)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidBool.selector),
                true
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallStaticRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE152));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_static_u32(uint256,uint256,uint32)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidU32.selector),
                uint32(1)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallDelegateReadsCallerStorage() public {
        address probe = address(uint160(0xE153));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.readStored.selector)
                )
            ),
            0
        );
        assertEq(callee.stored(), 88);
    }

    function testIRCrosscallDelegateWritesCallerStorage() public {
        address probe = address(uint160(0xE154));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.writeStored.selector)
                )
            ),
            777
        );
        assertEq(callee.stored(), 88);
        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate(uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.readStored.selector)
                )
            ),
            777
        );
    }

    function testIRCrosscallDelegateBoolReturn() public {
        address probe = address(uint160(0xE155));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertTrue(
            callBool(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate_bool(uint256,uint256,bool)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.notFlag.selector),
                    false
                )
            )
        );
    }

    function testIRCrosscallDelegateU32Return() public {
        address probe = address(uint160(0xE156));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            uint256(
                callU32(
                    probe,
                    abi.encodeWithSignature(
                        "call_remote_delegate_u32(uint256,uint256,uint32)",
                        uint256(uint160(address(callee))),
                        selector(CrosscallCallee.plusSmall.selector),
                        uint32(35)
                    )
                )
            ),
            42
        );
    }

    function testIRCrosscallDelegateHashReturn() public {
        address probe = address(uint160(0xE157));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        bytes32 value = keccak256("proof-forge-delegate-crosscall-hash");

        assertEq(
            callHash(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate_hash(uint256,uint256,bytes32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.echoHash.selector),
                    value
                )
            ),
            value
        );
    }

    function testIRCrosscallDelegateRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE158));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_delegate_bool(uint256,uint256,bool)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidBool.selector),
                true
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallDelegateRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE159));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_delegate_u32(uint256,uint256,uint32)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.invalidU32.selector),
                uint32(1)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallRevertsOnFailedCallee() public {
        address probe = address(uint160(0xE143));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.fail.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallRevertsOnShortReturn() public {
        address probe = address(uint160(0xE144));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.noReturn.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallRejectsUnknownSelector() public {
        address probe = address(uint160(0xE145));
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(hex"ffffffff");
        assertFalse(ok);
    }
}
SOL

forge test --root "$FORGE_DIR" -vv

echo "crosscall-ir-smoke: ProofForge metadata $METADATA_FILE"
