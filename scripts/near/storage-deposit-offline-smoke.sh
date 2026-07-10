#!/usr/bin/env bash
# N1.5: Product StorageDeposit offline lifecycle with withdraw.
#
# init → bounds=1 → bal=0 → deposit(7) → bal=7 → withdraw(3) → bal=4
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

OUT_DIR="${PROOF_FORGE_STORAGE_DEPOSIT_OUT:-build/near-storage-deposit-offline}"
WAT="$OUT_DIR/storagedeposit.wat"
HOST=(cargo run --quiet --manifest-path runtime/offline-host/Cargo.toml -- run)

fail() {
  echo "storage-deposit-offline: FAIL: $1" >&2
  exit 1
}

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "=== N1.5: build Product StorageDeposit → wasm-near ==="
lake env proof-forge build --target wasm-near --root . -o "$OUT_DIR" \
  Examples/Product/StorageDeposit.lean \
  || fail "proof-forge build StorageDeposit failed"
# WAT name is lowercased module name
WAT="$(find "$OUT_DIR" -name '*.wat' | head -n1)"
test -s "$WAT" || fail "missing WAT under $OUT_DIR"

eval "$(python3 - <<'PY'
import hashlib, struct
# Fixed 32-byte account hash used by near-compare storage-deposit scenario.
account = bytes.fromhex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
# Call sequence inputs:
# init: empty
# storage_balance_bounds: empty
# storage_balance_of: account
# storage_deposit: account (+ attached_deposit on host)
# storage_balance_of: account
# storage_withdraw: account + amount 3
# storage_balance_of: account
inputs = [
    b"",
    b"",
    account,
    account,
    account,
    account + struct.pack("<Q", 3),
    account,
]
print(f'INPUTS_HEX="{",".join(i.hex() for i in inputs)}"')
PY
)"

echo "=== N1.5: offline-host deposit + withdraw lifecycle ==="
out="$("${HOST[@]}" "$WAT" \
  init \
  storage_balance_bounds \
  storage_balance_of \
  storage_deposit \
  storage_balance_of \
  storage_withdraw \
  storage_balance_of \
  --predecessor-account-id alice.testnet \
  --signer-account-id alice.testnet \
  --current-account-id proof-forge.testnet \
  --attached-deposit 7 \
  --inputs-hex "$INPUTS_HEX")"
echo "$out"

grep -Fq "return_u64=1" <<<"$out" || fail "expected bounds=1"
grep -Fq "return_u64=0" <<<"$out" || fail "expected initial balance 0"
grep -Fq "return_u64=7" <<<"$out" || fail "expected balance 7 after deposit"
grep -Fq "return_u64=4" <<<"$out" || fail "expected balance 4 after withdraw 3"
grep -Fq "export \"storage_withdraw\"" "$WAT" || grep -Fq "storage_withdraw" "$WAT" \
  || fail "WAT must export storage_withdraw"

echo "storage-deposit-offline: ok (deposit 7 → withdraw 3 → bal 4)"
