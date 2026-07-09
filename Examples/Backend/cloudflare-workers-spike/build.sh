#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

mkdir -p build

echo "Compiling counter.zig to wasm32-freestanding ..."
zig build-exe \
  -target wasm32-freestanding \
  -O ReleaseSmall \
  -fno-entry \
  -rdynamic \
  -femit-bin=build/counter.wasm \
  src/counter.zig

echo "Build complete: build/counter.wasm"
