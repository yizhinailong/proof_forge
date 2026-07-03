#!/usr/bin/env bash
set -euo pipefail

# Compile the hand-written portable ContextProbe IR to EVM runtime bytecode
# and validate context reads through Foundry.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${IR_EVM_OUT_DIR:-$ROOT/build/ir}"
FORGE_DIR="${IR_EVM_FORGE_DIR:-$ROOT/build/foundry-ir-context-smoke}"
GOLDEN_FILE="${IR_EVM_GOLDEN:-$ROOT/Examples/Evm/ContextProbe.golden.yul}"
METADATA_FILE="${IR_EVM_METADATA:-$OUT_DIR/ContextProbe.proof-forge-artifact.json}"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "context-ir-smoke: forge not found. Install Foundry, then re-run this script." >&2
  echo "context-ir-smoke: https://getfoundry.sh/" >&2
  exit 127
fi

if ! command -v solc >/dev/null 2>&1; then
  echo "context-ir-smoke: solc not found on PATH." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" emit --target evm --fixture context --format bytecode \
  --yul-output "$OUT_DIR/ContextProbe.yul" \
  --artifact-output "$METADATA_FILE" \
  -o "$OUT_DIR/ContextProbe.bin"

if [[ -f "$GOLDEN_FILE" ]]; then
  diff -u "$GOLDEN_FILE" "$OUT_DIR/ContextProbe.yul"
fi

python3 "$ROOT/scripts/evm/validate-artifact-metadata.py" \
  --root "$ROOT" \
  --expect-fixture ContextProbe \
  --expect-source-kind portable-ir \
  --expect-capability caller.sender \
  --expect-capability account.explicit \
  --expect-capability env.block \
  --expect-capability value.native \
  --expect-entrypoint sum_context:14a70e97 \
  --expect-entrypoint native_value:f0eba40f \
  "$METADATA_FILE"

probe_hex="$(tr -d '\n' < "$OUT_DIR/ContextProbe.bin")"

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

cat > "$FORGE_DIR/test/ProofForgeIRContextSmoke.t.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function prank(address msgSender) external;
    function roll(uint256 newHeight) external;
}

contract ProofForgeIRContextSmokeTest {
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

    function testIRContextReadsCallerAddressAndBlockNumber() public {
        address probe = address(uint160(0xC077E));
        address sender = address(uint160(0xCA11E2));
        deployRuntime(hex"$probe_hex", probe);

        vm.roll(77);
        vm.prank(sender);
        (bool ok, bytes memory result) =
            probe.call(abi.encodeWithSignature("sum_context(uint256,uint256)", 2, 3));

        assertTrue(ok);
        uint256 expected = 2 + 3 + uint256(uint160(sender)) + uint256(uint160(probe)) + 77;
        assertEq(abi.decode(result, (uint256)), expected);
    }

    function testIRNativeValueReadsCallValue() public {
        address probe = address(uint160(0xC0780));
        deployRuntime(hex"$probe_hex", probe);

        (bool ok, bytes memory result) =
            probe.call{value: 1234}(abi.encodeWithSignature("native_value()"));

        assertTrue(ok);
        assertEq(abi.decode(result, (uint256)), 1234);
    }

    function testIRContextRejectsUnknownSelector() public {
        address probe = address(uint160(0xC077F));
        deployRuntime(hex"$probe_hex", probe);

        (bool ok,) = probe.call(hex"ffffffff");
        assertFalse(ok);
    }
}
SOL

forge test --root "$FORGE_DIR" -vv

echo "context-ir-smoke: ProofForge metadata $METADATA_FILE"
