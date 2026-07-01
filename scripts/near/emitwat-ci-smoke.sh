#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo --version >/dev/null

lake env lean --run Tests/EmitWatSmoke.lean
lake env lean --run Tests/EmitWatFeatures.lean
lake env lean --run Tests/EmitWatArith.lean
lake env lean --run Tests/EmitWatAlloc.lean
lake env lean --run Tests/EmitWatOwnership.lean

HOST=(cargo run --quiet --manifest-path runtime/offline-host/Cargo.toml -- run)

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "near-emitwat-ci: expected ${label} to contain: ${needle}" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

out="$("${HOST[@]}" build/wasm-near/emitwat-counter.wat initialize get increment get)"
echo "$out"
assert_contains "$out" "call 1:get: return_hex=0000000000000000 return_u64=0" "counter initial get"
assert_contains "$out" "call 1:get: return_hex=0100000000000000 return_u64=1" "counter increment get"

out="$("${HOST[@]}" build/wasm-near/emitwat-features.wat init bump bump getN getFlag)"
echo "$out"
assert_contains "$out" "call 1:getN: return_hex=0a000000 return_u32=10" "features getN"
assert_contains "$out" "call 1:getFlag: return_hex=00 return_bool=false" "features getFlag"

out="$("${HOST[@]}" build/wasm-near/emitwat-arith.wat u32_arithmetic --input-hex 0200000003000000)"
echo "$out"
assert_contains "$out" "call 1:u32_arithmetic: return_hex=0100000000000000 return_u64=1" "arith"

for fixture in emitwat-alloc-reset emitwat-alloc-minimal emitwat-alloc-near; do
  out="$("${HOST[@]}" "build/wasm-near/${fixture}.wat" sum_literal --repeat 2)"
  echo "$out"
  assert_contains "$out" "call 1:sum_literal: return_hex=3c00000000000000 return_u64=60" "${fixture} call 1"
  assert_contains "$out" "call 2:sum_literal: return_hex=3c00000000000000 return_u64=60" "${fixture} call 2"
done

out="$("${HOST[@]}" build/wasm-near/emitwat-release-minimal.wat release_then_sum --repeat 2)"
echo "$out"
assert_contains "$out" "call 1:release_then_sum: return_hex=3c00000000000000 return_u64=60" "release call 1"
assert_contains "$out" "call 2:release_then_sum: return_hex=3c00000000000000 return_u64=60" "release call 2"

echo "near-emitwat-ci: ok"
