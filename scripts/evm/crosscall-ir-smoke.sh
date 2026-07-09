#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable EvmCrosscallProbe IR to EVM runtime
# bytecode and validate synchronous typed crosscalls through Foundry.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-crosscall-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Backend/Evm/EvmCrosscallProbe.golden.yul}"
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
"$ROOT/.lake/build/bin/proof-forge" emit --target evm --fixture evm-crosscall --format bytecode \
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
  --expect-entrypoint call_remote_matrix:d49690a6 \
  --expect-entrypoint call_remote_pair_arg:cabe3922 \
  --expect-entrypoint call_remote_array_arg:f96abfe0 \
  --expect-entrypoint call_remote_matrix_arg:38e0bc4c \
  --expect-entrypoint call_remote_pair_array:031396d6 \
  --expect-entrypoint call_remote_pair_array_arg:7a45fdce \
  --expect-entrypoint call_remote_pair_matrix:3652f87d \
  --expect-entrypoint call_remote_pair_matrix_arg:48fc8f80 \
  --expect-entrypoint call_remote_value:365f4a44 \
  --expect-entrypoint call_remote_value_pair_arg:885cf3f5 \
  --expect-entrypoint call_remote_value_pair:01ff40fb \
  --expect-entrypoint call_remote_value_array:2bedc30a \
  --expect-entrypoint call_remote_value_matrix:4b634dd4 \
  --expect-entrypoint call_remote_value_pair_array:63ec1609 \
  --expect-entrypoint call_remote_value_pair_array_arg:27c33745 \
  --expect-entrypoint call_remote_value_pair_matrix:fa3cf7ed \
  --expect-entrypoint call_remote_value_pair_matrix_arg:4f1e8d96 \
  --expect-entrypoint call_remote_value_matrix_arg:1a211ecd \
  --expect-entrypoint call_remote_static:d13203a8 \
  --expect-entrypoint call_remote_static_bool:ae266f0a \
  --expect-entrypoint call_remote_static_u32:ec8c40f9 \
  --expect-entrypoint call_remote_static_hash:4e0edd3c \
  --expect-entrypoint call_remote_static_pair_arg:d1b1bf68 \
  --expect-entrypoint call_remote_static_pair:2236e75b \
  --expect-entrypoint call_remote_static_array:b1d5165b \
  --expect-entrypoint call_remote_static_matrix:202850f3 \
  --expect-entrypoint call_remote_static_pair_array:e0315e4e \
  --expect-entrypoint call_remote_static_pair_array_arg:1b46265d \
  --expect-entrypoint call_remote_static_pair_matrix:9893a8f6 \
  --expect-entrypoint call_remote_static_pair_matrix_arg:db5109a1 \
  --expect-entrypoint call_remote_static_matrix_arg:123a499f \
  --expect-entrypoint call_remote_delegate:427320b1 \
  --expect-entrypoint call_remote_delegate_bool:62e5114d \
  --expect-entrypoint call_remote_delegate_u32:e3abe276 \
  --expect-entrypoint call_remote_delegate_hash:6a2c2006 \
  --expect-entrypoint call_remote_delegate_pair_arg:8283d1d1 \
  --expect-entrypoint call_remote_delegate_pair:41e8bd85 \
  --expect-entrypoint call_remote_delegate_array:52579065 \
  --expect-entrypoint call_remote_delegate_matrix:b8c58c92 \
  --expect-entrypoint call_remote_delegate_pair_array:a26d8a3c \
  --expect-entrypoint call_remote_delegate_pair_array_arg:73049a39 \
  --expect-entrypoint call_remote_delegate_pair_matrix:26db7add \
  --expect-entrypoint call_remote_delegate_pair_matrix_arg:667806e6 \
  --expect-entrypoint call_remote_delegate_matrix_arg:ccc679f8 \
  --expect-entrypoint deploy_create:c9bc2909 \
  --expect-entrypoint deploy_create2:70b22efb \
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
    struct Pair {
        bool flag;
        uint32 small;
    }

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

    function valuesMatrix() external pure returns (uint64[2][2] memory values) {
        values[0][0] = 11;
        values[0][1] = 22;
        values[1][0] = 33;
        values[1][1] = 44;
    }

    function pairArray() external pure returns (Pair[2] memory pairs) {
        pairs[0] = Pair({flag: true, small: 40});
        pairs[1] = Pair({flag: false, small: 2});
    }

    function pairMatrix() external pure returns (Pair[2][2] memory pairs) {
        pairs[0][0] = Pair({flag: true, small: 5});
        pairs[0][1] = Pair({flag: false, small: 7});
        pairs[1][0] = Pair({flag: true, small: 11});
        pairs[1][1] = Pair({flag: false, small: 19});
    }

    function pairFlag(bool flag, uint32 small) external pure returns (bool) {
        return flag && small == 42;
    }

    function sumValues(uint64[2] memory values) external pure returns (uint256) {
        return uint256(values[0]) + uint256(values[1]);
    }

    function sumMatrix(uint64[2][2] memory values) external pure returns (uint256) {
        return uint256(values[0][0]) + uint256(values[0][1]) + uint256(values[1][0]) + uint256(values[1][1]);
    }

    function pairArrayScore(Pair[2] memory pairs) external pure returns (uint256) {
        require(pairs[0].flag, "first flag");
        require(!pairs[1].flag, "second flag");
        return uint256(pairs[0].small) + uint256(pairs[1].small);
    }

    function pairMatrixScore(Pair[2][2] memory pairs) external pure returns (uint256) {
        require(pairs[0][0].flag, "first flag");
        require(!pairs[0][1].flag, "second flag");
        require(pairs[1][0].flag, "third flag");
        require(!pairs[1][1].flag, "fourth flag");
        return uint256(pairs[0][0].small)
            + uint256(pairs[0][1].small)
            + uint256(pairs[1][0].small)
            + uint256(pairs[1][1].small);
    }

    function paid() external payable returns (uint256) {
        return msg.value;
    }

    function paidPairReturn() external payable returns (bool, uint32) {
        return (msg.value == 1234, 42);
    }

    function paidValues2() external payable returns (uint64[2] memory values) {
        values[0] = uint64(msg.value);
        values[1] = 44;
    }

    function paidValuesMatrix() external payable returns (uint64[2][2] memory values) {
        values[0][0] = uint64(msg.value);
        values[0][1] = 22;
        values[1][0] = 33;
        values[1][1] = 44;
    }

    function paidPairArray() external payable returns (Pair[2] memory pairs) {
        pairs[0] = Pair({flag: msg.value == 1234, small: 42});
        pairs[1] = Pair({flag: true, small: 7});
    }

    function paidPairMatrix() external payable returns (Pair[2][2] memory pairs) {
        pairs[0][0] = Pair({flag: msg.value == 1234, small: 13});
        pairs[0][1] = Pair({flag: false, small: 17});
        pairs[1][0] = Pair({flag: true, small: 19});
        pairs[1][1] = Pair({flag: false, small: 23});
    }

    function paidPairInvalidBool() external payable returns (uint256, uint256) {
        return (2, 42);
    }

    function paidPairInvalidU32() external payable returns (uint256, uint256) {
        return (1, uint256(type(uint32).max) + 1);
    }

    function paidPair(bool flag, uint32 small) external payable returns (uint256) {
        require(flag, "flag");
        return msg.value + uint256(small);
    }

    function paidPairArrayScore(Pair[2] memory pairs) external payable returns (uint256) {
        require(pairs[0].flag, "first flag");
        require(!pairs[1].flag, "second flag");
        return msg.value + uint256(pairs[0].small) + uint256(pairs[1].small);
    }

    function paidPairMatrixScore(Pair[2][2] memory pairs) external payable returns (uint256) {
        require(pairs[0][0].flag, "first flag");
        require(!pairs[0][1].flag, "second flag");
        require(pairs[1][0].flag, "third flag");
        require(!pairs[1][1].flag, "fourth flag");
        return msg.value
            + uint256(pairs[0][0].small)
            + uint256(pairs[0][1].small)
            + uint256(pairs[1][0].small)
            + uint256(pairs[1][1].small);
    }

    function paidMatrixScore(uint64[2][2] memory values) external payable returns (uint256) {
        return msg.value + uint256(values[0][0]) + uint256(values[0][1]) + uint256(values[1][0]) + uint256(values[1][1]);
    }

    function readStored() external view returns (uint256) {
        return stored;
    }

    function pairSmall(bool flag, uint32 small) external pure returns (uint32) {
        return flag ? small + 1 : 0;
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

    function callU64Matrix2(address probe, bytes memory payload) internal returns (uint64[2][2] memory values) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        values = abi.decode(result, (uint64[2][2]));
    }

    function callPairArray(address probe, bytes memory payload) internal returns (CrosscallCallee.Pair[2] memory pairs) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        pairs = abi.decode(result, (CrosscallCallee.Pair[2]));
    }

    function callPairMatrix(address probe, bytes memory payload) internal returns (CrosscallCallee.Pair[2][2] memory pairs) {
        (bool ok, bytes memory result) = probe.call(payload);
        assertTrue(ok);
        pairs = abi.decode(result, (CrosscallCallee.Pair[2][2]));
    }

    function callPairValue(address probe, bytes memory payload, uint256 amount) internal returns (bool flag, uint32 small) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        (flag, small) = abi.decode(result, (bool, uint32));
    }

    function callU64Array2Value(address probe, bytes memory payload, uint256 amount) internal returns (uint64[2] memory values) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        values = abi.decode(result, (uint64[2]));
    }

    function callU64Matrix2Value(address probe, bytes memory payload, uint256 amount) internal returns (uint64[2][2] memory values) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        values = abi.decode(result, (uint64[2][2]));
    }

    function callPairArrayValue(address probe, bytes memory payload, uint256 amount) internal returns (CrosscallCallee.Pair[2] memory pairs) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        pairs = abi.decode(result, (CrosscallCallee.Pair[2]));
    }

    function callPairMatrixValue(address probe, bytes memory payload, uint256 amount) internal returns (CrosscallCallee.Pair[2][2] memory pairs) {
        (bool ok, bytes memory result) = probe.call{value: amount}(payload);
        assertTrue(ok);
        pairs = abi.decode(result, (CrosscallCallee.Pair[2][2]));
    }

    function deployedAddress(uint256 raw) internal pure returns (address) {
        return address(uint160(raw));
    }

    function expectedCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }

    function callRuntime42(address deployed) internal returns (uint256) {
        (bool ok, bytes memory result) = deployed.call("");
        assertTrue(ok);
        return abi.decode(result, (uint256));
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

    function testIRCrosscallCreateDeploysRuntime() public {
        address probe = address(uint160(0xE171));
        deployRuntime(hex"$probe_hex", probe);

        address deployed = deployedAddress(
            callU256(
                probe,
                abi.encodeWithSignature("deploy_create(uint256)", uint256(0))
            )
        );

        assertTrue(deployed.code.length > 0);
        assertEq(callRuntime42(deployed), 42);
    }

    function testIRCrosscallCreate2DeploysDeterministicRuntime() public {
        address probe = address(uint160(0xE172));
        deployRuntime(hex"$probe_hex", probe);
        bytes memory initCode = hex"69602a60005260206000f3600052600a6016f3";
        bytes32 salt = keccak256("proof-forge-create2-salt");
        address expected = expectedCreate2Address(probe, salt, keccak256(initCode));

        address deployed = deployedAddress(
            callU256(
                probe,
                abi.encodeWithSignature("deploy_create2(uint256,bytes32)", uint256(0), salt)
            )
        );

        assertEq(uint256(uint160(deployed)), uint256(uint160(expected)));
        assertTrue(deployed.code.length > 0);
        assertEq(callRuntime42(deployed), 42);
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

    function testIRCrosscallAggregateMatrixReturn() public {
        address probe = address(uint160(0xE180));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2][2] memory values = callU64Matrix2(
            probe,
            abi.encodeWithSignature(
                "call_remote_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.valuesMatrix.selector)
            )
        );
        assertEq(uint256(values[0][0]), 11);
        assertEq(uint256(values[0][1]), 22);
        assertEq(uint256(values[1][0]), 33);
        assertEq(uint256(values[1][1]), 44);
    }

    function testIRCrosscallAggregateStructArrayReturn() public {
        address probe = address(uint160(0xE16F));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2] memory pairs = callPairArray(
            probe,
            abi.encodeWithSignature(
                "call_remote_pair_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairArray.selector)
            )
        );
        assertTrue(pairs[0].flag);
        assertEq(uint256(pairs[0].small), 40);
        assertFalse(pairs[1].flag);
        assertEq(uint256(pairs[1].small), 2);
    }

    function testIRCrosscallNestedStructArrayReturn() public {
        address probe = address(uint160(0xE188));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2][2] memory pairs = callPairMatrix(
            probe,
            abi.encodeWithSignature(
                "call_remote_pair_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairMatrix.selector)
            )
        );
        assertTrue(pairs[0][0].flag);
        assertEq(uint256(pairs[0][0].small), 5);
        assertFalse(pairs[0][1].flag);
        assertEq(uint256(pairs[0][1].small), 7);
        assertTrue(pairs[1][0].flag);
        assertEq(uint256(pairs[1][0].small), 11);
        assertFalse(pairs[1][1].flag);
        assertEq(uint256(pairs[1][1].small), 19);
    }

    function testIRCrosscallAggregateStructArgument() public {
        address probe = address(uint160(0xE15E));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertTrue(
            callBool(
                probe,
                abi.encodeWithSignature(
                    "call_remote_pair_arg(uint256,uint256,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairFlag.selector),
                    true,
                    uint32(42)
                )
            )
        );
    }

    function testIRCrosscallAggregateArrayArgument() public {
        address probe = address(uint160(0xE15F));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_array_arg(uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.sumValues.selector),
                    uint64(15),
                    uint64(27)
                )
            ),
            42
        );
    }

    function testIRCrosscallAggregateMatrixArgument() public {
        address probe = address(uint160(0xE181));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_matrix_arg(uint256,uint256,uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.sumMatrix.selector),
                    uint64(1),
                    uint64(2),
                    uint64(3),
                    uint64(36)
                )
            ),
            42
        );
    }

    function testIRCrosscallAggregateStructArrayArgument() public {
        address probe = address(uint160(0xE170));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_pair_array_arg(uint256,uint256,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairArrayScore.selector),
                    true,
                    uint32(20),
                    false,
                    uint32(22)
                )
            ),
            42
        );
    }

    function testIRCrosscallNestedStructArrayArgument() public {
        address probe = address(uint160(0xE189));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_pair_matrix_arg(uint256,uint256,bool,uint32,bool,uint32,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairMatrixScore.selector),
                    true,
                    uint32(5),
                    false,
                    uint32(7),
                    true,
                    uint32(11),
                    false,
                    uint32(19)
                )
            ),
            42
        );
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

    function testIRCrosscallValueAggregateStructArgument() public {
        address probe = address(uint160(0xE160));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        assertEq(
            callU256Value(
                probe,
                abi.encodeWithSignature(
                    "call_remote_value_pair_arg(uint256,uint256,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.paidPair.selector),
                    true,
                    uint32(8)
                ),
                1234
            ),
            1242
        );
        assertEq(address(callee).balance, 1234);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateStructReturn() public {
        address probe = address(uint160(0xE163));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        (bool flag, uint32 small) = callPairValue(
            probe,
            abi.encodeWithSignature(
                "call_remote_value_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidPairReturn.selector)
            ),
            1234
        );
        assertTrue(flag);
        assertEq(uint256(small), 42);
        assertEq(address(callee).balance, 1234);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateArrayReturn() public {
        address probe = address(uint160(0xE164));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        uint64[2] memory values = callU64Array2Value(
            probe,
            abi.encodeWithSignature(
                "call_remote_value_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidValues2.selector)
            ),
            55
        );
        assertEq(uint256(values[0]), 55);
        assertEq(uint256(values[1]), 44);
        assertEq(address(callee).balance, 55);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateMatrixReturn() public {
        address probe = address(uint160(0xE182));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        uint64[2][2] memory values = callU64Matrix2Value(
            probe,
            abi.encodeWithSignature(
                "call_remote_value_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidValuesMatrix.selector)
            ),
            55
        );
        assertEq(uint256(values[0][0]), 55);
        assertEq(uint256(values[0][1]), 22);
        assertEq(uint256(values[1][0]), 33);
        assertEq(uint256(values[1][1]), 44);
        assertEq(address(callee).balance, 55);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateStructArrayReturn() public {
        address probe = address(uint160(0xE171));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        CrosscallCallee.Pair[2] memory pairs = callPairArrayValue(
            probe,
            abi.encodeWithSignature(
                "call_remote_value_pair_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidPairArray.selector)
            ),
            1234
        );
        assertTrue(pairs[0].flag);
        assertEq(uint256(pairs[0].small), 42);
        assertTrue(pairs[1].flag);
        assertEq(uint256(pairs[1].small), 7);
        assertEq(address(callee).balance, 1234);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueNestedStructArrayReturn() public {
        address probe = address(uint160(0xE18A));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        CrosscallCallee.Pair[2][2] memory pairs = callPairMatrixValue(
            probe,
            abi.encodeWithSignature(
                "call_remote_value_pair_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidPairMatrix.selector)
            ),
            1234
        );
        assertTrue(pairs[0][0].flag);
        assertEq(uint256(pairs[0][0].small), 13);
        assertFalse(pairs[0][1].flag);
        assertEq(uint256(pairs[0][1].small), 17);
        assertTrue(pairs[1][0].flag);
        assertEq(uint256(pairs[1][0].small), 19);
        assertFalse(pairs[1][1].flag);
        assertEq(uint256(pairs[1][1].small), 23);
        assertEq(address(callee).balance, 1234);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateStructArrayArgument() public {
        address probe = address(uint160(0xE172));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        assertEq(
            callU256Value(
                probe,
                abi.encodeWithSignature(
                    "call_remote_value_pair_array_arg(uint256,uint256,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.paidPairArrayScore.selector),
                    true,
                    uint32(20),
                    false,
                    uint32(22)
                ),
                1000
            ),
            1042
        );
        assertEq(address(callee).balance, 1000);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueNestedStructArrayArgument() public {
        address probe = address(uint160(0xE18B));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        assertEq(
            callU256Value(
                probe,
                abi.encodeWithSignature(
                    "call_remote_value_pair_matrix_arg(uint256,uint256,bool,uint32,bool,uint32,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.paidPairMatrixScore.selector),
                    true,
                    uint32(5),
                    false,
                    uint32(7),
                    true,
                    uint32(11),
                    false,
                    uint32(19)
                ),
                1000
            ),
            1042
        );
        assertEq(address(callee).balance, 1000);
        assertEq(probe.balance, 0);
    }

    function testIRCrosscallValueAggregateMatrixArgument() public {
        address probe = address(uint160(0xE183));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        assertEq(
            callU256Value(
                probe,
                abi.encodeWithSignature(
                    "call_remote_value_matrix_arg(uint256,uint256,uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.paidMatrixScore.selector),
                    uint64(1),
                    uint64(2),
                    uint64(3),
                    uint64(36)
                ),
                1000
            ),
            1042
        );
        assertEq(address(callee).balance, 1000);
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

    function testIRCrosscallStaticAggregateStructArgument() public {
        address probe = address(uint160(0xE161));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            uint256(
                callU32(
                    probe,
                    abi.encodeWithSignature(
                        "call_remote_static_pair_arg(uint256,uint256,bool,uint32)",
                        uint256(uint160(address(callee))),
                        selector(CrosscallCallee.pairSmall.selector),
                        true,
                        uint32(41)
                    )
                )
            ),
            42
        );
    }

    function testIRCrosscallStaticAggregateStructReturn() public {
        address probe = address(uint160(0xE165));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool flag, uint32 small) = callPair(
            probe,
            abi.encodeWithSignature(
                "call_remote_static_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pair.selector)
            )
        );
        assertTrue(flag);
        assertEq(uint256(small), 42);
    }

    function testIRCrosscallStaticAggregateArrayReturn() public {
        address probe = address(uint160(0xE166));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2] memory values = callU64Array2(
            probe,
            abi.encodeWithSignature(
                "call_remote_static_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.values2.selector)
            )
        );
        assertEq(uint256(values[0]), 33);
        assertEq(uint256(values[1]), 44);
    }

    function testIRCrosscallStaticAggregateMatrixReturn() public {
        address probe = address(uint160(0xE184));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2][2] memory values = callU64Matrix2(
            probe,
            abi.encodeWithSignature(
                "call_remote_static_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.valuesMatrix.selector)
            )
        );
        assertEq(uint256(values[0][0]), 11);
        assertEq(uint256(values[0][1]), 22);
        assertEq(uint256(values[1][0]), 33);
        assertEq(uint256(values[1][1]), 44);
    }

    function testIRCrosscallStaticAggregateStructArrayReturn() public {
        address probe = address(uint160(0xE173));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2] memory pairs = callPairArray(
            probe,
            abi.encodeWithSignature(
                "call_remote_static_pair_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairArray.selector)
            )
        );
        assertTrue(pairs[0].flag);
        assertEq(uint256(pairs[0].small), 40);
        assertFalse(pairs[1].flag);
        assertEq(uint256(pairs[1].small), 2);
    }

    function testIRCrosscallStaticNestedStructArrayReturn() public {
        address probe = address(uint160(0xE18C));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2][2] memory pairs = callPairMatrix(
            probe,
            abi.encodeWithSignature(
                "call_remote_static_pair_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairMatrix.selector)
            )
        );
        assertTrue(pairs[0][0].flag);
        assertEq(uint256(pairs[0][0].small), 5);
        assertFalse(pairs[0][1].flag);
        assertEq(uint256(pairs[0][1].small), 7);
        assertTrue(pairs[1][0].flag);
        assertEq(uint256(pairs[1][0].small), 11);
        assertFalse(pairs[1][1].flag);
        assertEq(uint256(pairs[1][1].small), 19);
    }

    function testIRCrosscallStaticAggregateStructArrayArgument() public {
        address probe = address(uint160(0xE174));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static_pair_array_arg(uint256,uint256,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairArrayScore.selector),
                    true,
                    uint32(20),
                    false,
                    uint32(22)
                )
            ),
            42
        );
    }

    function testIRCrosscallStaticNestedStructArrayArgument() public {
        address probe = address(uint160(0xE18D));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static_pair_matrix_arg(uint256,uint256,bool,uint32,bool,uint32,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairMatrixScore.selector),
                    true,
                    uint32(5),
                    false,
                    uint32(7),
                    true,
                    uint32(11),
                    false,
                    uint32(19)
                )
            ),
            42
        );
    }

    function testIRCrosscallStaticAggregateMatrixArgument() public {
        address probe = address(uint160(0xE185));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_static_matrix_arg(uint256,uint256,uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.sumMatrix.selector),
                    uint64(1),
                    uint64(2),
                    uint64(3),
                    uint64(36)
                )
            ),
            42
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

    function testIRCrosscallValueAggregateRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE167));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        (bool ok,) = probe.call{value: 1234}(
            abi.encodeWithSignature(
                "call_remote_value_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidPairInvalidBool.selector)
            )
        );
        assertFalse(ok);
        assertEq(address(callee).balance, 0);
    }

    function testIRCrosscallValueAggregateRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE168));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);
        vm.deal(address(this), 1 ether);

        (bool ok,) = probe.call{value: 1234}(
            abi.encodeWithSignature(
                "call_remote_value_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.paidPairInvalidU32.selector)
            )
        );
        assertFalse(ok);
        assertEq(address(callee).balance, 0);
    }

    function testIRCrosscallStaticAggregateRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE169));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_static_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairInvalidBool.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallStaticAggregateRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE16A));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_static_pair(uint256,uint256)",
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

    function testIRCrosscallDelegateAggregateStructArgument() public {
        address probe = address(uint160(0xE162));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            uint256(
                callU32(
                    probe,
                    abi.encodeWithSignature(
                        "call_remote_delegate_pair_arg(uint256,uint256,bool,uint32)",
                        uint256(uint160(address(callee))),
                        selector(CrosscallCallee.pairSmall.selector),
                        true,
                        uint32(41)
                    )
                )
            ),
            42
        );
    }

    function testIRCrosscallDelegateAggregateStructReturn() public {
        address probe = address(uint160(0xE16B));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool flag, uint32 small) = callPair(
            probe,
            abi.encodeWithSignature(
                "call_remote_delegate_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pair.selector)
            )
        );
        assertTrue(flag);
        assertEq(uint256(small), 42);
    }

    function testIRCrosscallDelegateAggregateArrayReturn() public {
        address probe = address(uint160(0xE16C));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2] memory values = callU64Array2(
            probe,
            abi.encodeWithSignature(
                "call_remote_delegate_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.values2.selector)
            )
        );
        assertEq(uint256(values[0]), 33);
        assertEq(uint256(values[1]), 44);
    }

    function testIRCrosscallDelegateAggregateMatrixReturn() public {
        address probe = address(uint160(0xE186));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        uint64[2][2] memory values = callU64Matrix2(
            probe,
            abi.encodeWithSignature(
                "call_remote_delegate_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.valuesMatrix.selector)
            )
        );
        assertEq(uint256(values[0][0]), 11);
        assertEq(uint256(values[0][1]), 22);
        assertEq(uint256(values[1][0]), 33);
        assertEq(uint256(values[1][1]), 44);
    }

    function testIRCrosscallDelegateAggregateStructArrayReturn() public {
        address probe = address(uint160(0xE175));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2] memory pairs = callPairArray(
            probe,
            abi.encodeWithSignature(
                "call_remote_delegate_pair_array(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairArray.selector)
            )
        );
        assertTrue(pairs[0].flag);
        assertEq(uint256(pairs[0].small), 40);
        assertFalse(pairs[1].flag);
        assertEq(uint256(pairs[1].small), 2);
    }

    function testIRCrosscallDelegateNestedStructArrayReturn() public {
        address probe = address(uint160(0xE18E));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        CrosscallCallee.Pair[2][2] memory pairs = callPairMatrix(
            probe,
            abi.encodeWithSignature(
                "call_remote_delegate_pair_matrix(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairMatrix.selector)
            )
        );
        assertTrue(pairs[0][0].flag);
        assertEq(uint256(pairs[0][0].small), 5);
        assertFalse(pairs[0][1].flag);
        assertEq(uint256(pairs[0][1].small), 7);
        assertTrue(pairs[1][0].flag);
        assertEq(uint256(pairs[1][0].small), 11);
        assertFalse(pairs[1][1].flag);
        assertEq(uint256(pairs[1][1].small), 19);
    }

    function testIRCrosscallDelegateAggregateStructArrayArgument() public {
        address probe = address(uint160(0xE176));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate_pair_array_arg(uint256,uint256,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairArrayScore.selector),
                    true,
                    uint32(20),
                    false,
                    uint32(22)
                )
            ),
            42
        );
    }

    function testIRCrosscallDelegateNestedStructArrayArgument() public {
        address probe = address(uint160(0xE18F));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate_pair_matrix_arg(uint256,uint256,bool,uint32,bool,uint32,bool,uint32,bool,uint32)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.pairMatrixScore.selector),
                    true,
                    uint32(5),
                    false,
                    uint32(7),
                    true,
                    uint32(11),
                    false,
                    uint32(19)
                )
            ),
            42
        );
    }

    function testIRCrosscallDelegateAggregateMatrixArgument() public {
        address probe = address(uint160(0xE187));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        assertEq(
            callU256(
                probe,
                abi.encodeWithSignature(
                    "call_remote_delegate_matrix_arg(uint256,uint256,uint256,uint256,uint256,uint256)",
                    uint256(uint160(address(callee))),
                    selector(CrosscallCallee.sumMatrix.selector),
                    uint64(1),
                    uint64(2),
                    uint64(3),
                    uint64(36)
                )
            ),
            42
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

    function testIRCrosscallDelegateAggregateRejectsInvalidBoolReturn() public {
        address probe = address(uint160(0xE16D));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_delegate_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairInvalidBool.selector)
            )
        );
        assertFalse(ok);
    }

    function testIRCrosscallDelegateAggregateRejectsInvalidU32Return() public {
        address probe = address(uint160(0xE16E));
        CrosscallCallee callee = new CrosscallCallee();
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(
            abi.encodeWithSignature(
                "call_remote_delegate_pair(uint256,uint256)",
                uint256(uint160(address(callee))),
                selector(CrosscallCallee.pairInvalidU32.selector)
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
