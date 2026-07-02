#!/usr/bin/env bash
# ProofForge vs Pinocchio SPL Token transfer_checked live equivalence on Surfpool.
#
# Builds the generated ProofForge SPL Token transfer_checked CPI ELF and the
# checked-in Pinocchio reference ELF, deploys both programs to the same
# Surfpool instance, invokes the same Web3.js token transfer scenario against
# each program, and compares the token balance deltas plus state writes.
#
# Exit codes:
#   0 - live equivalence passed
#   1 - a gate failed
#   2 - a prerequisite is missing (skipped)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_PINOCCHIO_SPL_TOKEN_TRANSFER_LIVE_OUT:-build/solana-pinocchio-spl-token-transfer-live}"
REFERENCE_DIR="$REPO_ROOT/references/solana/pinocchio/spl-token-transfer"
PROOF_FORGE_PROJECT_NAME="proofforge-spl-token-transfer-live"
PINOCCHIO_PROJECT_NAME="pinocchio-spl-token-transfer-reference"
PROOF_FORGE_ELF="$OUT_DIR/$PROOF_FORGE_PROJECT_NAME.so"
PROOF_FORGE_ARTIFACT="$OUT_DIR/proof-forge-artifact.json"
PINOCCHIO_BUILD_DIR="$OUT_DIR/pinocchio-build"
PINOCCHIO_ELF="$OUT_DIR/$PINOCCHIO_PROJECT_NAME.so"
PAYER_KEYPAIR="$OUT_DIR/payer.json"
PROOF_FORGE_PROGRAM_KEYPAIR="$OUT_DIR/proofforge-program-keypair.json"
PINOCCHIO_PROGRAM_KEYPAIR="$OUT_DIR/pinocchio-program-keypair.json"
JS_TEMPLATE="$REPO_ROOT/Tests/solana/spl_token_transfer_cpi_web3_smoke.mjs"
NODE_PROJECT="$OUT_DIR/web3"
SURFPOOL_BIN="${SURFPOOL:-surfpool}"
SOLANA_BIN="${SOLANA:-solana}"
KEYGEN="${SOLANA_KEYGEN:-solana-keygen}"
NPM_BIN="${NPM:-npm}"
CARGO_BUILD_SBF_BIN="${CARGO_BUILD_SBF:-cargo-build-sbf}"
SBPF_ARCH="${PROOF_FORGE_SOLANA_SPL_TOKEN_TRANSFER_CPI_SBPF_ARCH:-v0}"
SOLANA_RUSTUP_TOOLCHAIN="${PROOF_FORGE_PINOCCHIO_RUSTUP_TOOLCHAIN:-1.89.0-sbpf-solana-v1.52}"
RPC_HOST="${PROOF_FORGE_SURFPOOL_HOST:-127.0.0.1}"
RPC_PORT="${PROOF_FORGE_PINOCCHIO_SPL_TOKEN_TRANSFER_SURFPOOL_PORT:-8912}"
WS_PORT="${PROOF_FORGE_PINOCCHIO_SPL_TOKEN_TRANSFER_SURFPOOL_WS_PORT:-8913}"
RPC_URL="http://$RPC_HOST:$RPC_PORT"
WS_URL="ws://$RPC_HOST:$WS_PORT"
SURFPOOL_LOG_DIR="$OUT_DIR/surfpool-logs"
TOKEN_DECIMALS="${PROOF_FORGE_SOLANA_TOKEN_DECIMALS:-9}"
TRANSFER_AMOUNT="${PROOF_FORGE_SOLANA_TOKEN_TRANSFER_AMOUNT:-250000000}"
INITIAL_AMOUNT="${PROOF_FORGE_SOLANA_TOKEN_INITIAL_AMOUNT:-1000000000}"
SURFPOOL_PID=""

fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "SKIP: $1" >&2; exit 2; }

rustupCargoAvailable() {
  [ -x "$HOME/.cargo/bin/cargo" ] &&
    PATH="$HOME/.cargo/bin:$PATH" cargo +"$SOLANA_RUSTUP_TOOLCHAIN" --version >/dev/null 2>&1
}

printSbfToolchainHint() {
  cat >&2 <<EOF
Pinocchio reference SBF build needs Solana rustc/platform-tools.
Suggested repair:
  PATH="\$HOME/.cargo/bin:\$PATH" cargo-build-sbf --install-only --force-tools-install --tools-version v1.52
Then rerun:
  PROOF_FORGE_PINOCCHIO_USE_RUSTUP=1 scripts/solana/pinocchio-spl-token-transfer-live-equivalence.sh
EOF
}

cleanup() {
  if [ -n "$SURFPOOL_PID" ] && kill -0 "$SURFPOOL_PID" >/dev/null 2>&1; then
    kill "$SURFPOOL_PID" >/dev/null 2>&1 || true
    for _ in $(seq 1 10); do
      if ! kill -0 "$SURFPOOL_PID" >/dev/null 2>&1; then
        wait "$SURFPOOL_PID" >/dev/null 2>&1 || true
        return
      fi
      sleep 1
    done
    kill -9 "$SURFPOOL_PID" >/dev/null 2>&1 || true
    wait "$SURFPOOL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
command -v "$SURFPOOL_BIN" >/dev/null 2>&1 || skip "surfpool not on PATH (set SURFPOOL=/path/to/surfpool)"
command -v "$SOLANA_BIN" >/dev/null 2>&1 || skip "solana CLI not on PATH (set SOLANA=/path/to/solana)"
command -v "$KEYGEN" >/dev/null 2>&1 || skip "solana-keygen not on PATH (set SOLANA_KEYGEN=/path/to/solana-keygen)"
command -v "$CARGO_BUILD_SBF_BIN" >/dev/null 2>&1 || skip "cargo-build-sbf not on PATH"
command -v sbpf >/dev/null 2>&1 || skip "sbpf not on PATH"
command -v node >/dev/null 2>&1 || skip "node not on PATH"
command -v "$NPM_BIN" >/dev/null 2>&1 || skip "npm not on PATH (set NPM=/path/to/npm)"
command -v python3 >/dev/null 2>&1 || fail "python3 not on PATH"
[ -f "$JS_TEMPLATE" ] || fail "Web3.js smoke template not found: $JS_TEMPLATE"
[ -f "$REFERENCE_DIR/Cargo.toml" ] || fail "Pinocchio reference Cargo.toml missing: $REFERENCE_DIR/Cargo.toml"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$PINOCCHIO_BUILD_DIR" "$NODE_PROJECT" "$SURFPOOL_LOG_DIR"

echo "=== Pinocchio SPL Token transfer live equivalence step 1: build ProofForge fixture ELF ==="
lake env proof-forge --solana-spl-token-transfer-cpi-elf --solana-sbpf-arch "$SBPF_ARCH" \
  -o "$PROOF_FORGE_ELF" \
  --artifact-output "$PROOF_FORGE_ARTIFACT" \
  || fail "proof-forge --solana-spl-token-transfer-cpi-elf failed"
[ -f "$PROOF_FORGE_ELF" ] || fail "ProofForge ELF not produced: $PROOF_FORGE_ELF"

echo "=== Pinocchio SPL Token transfer live equivalence step 2: build Pinocchio reference ELF ==="
use_no_rustup_override=0
case "${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-auto}" in
  1|true|yes|auto)
    if rustupCargoAvailable; then
      export PATH="$HOME/.cargo/bin:$PATH"
      echo "  using rustup Solana toolchain: $SOLANA_RUSTUP_TOOLCHAIN"
    elif [ "${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-auto}" = "auto" ]; then
      use_no_rustup_override=1
      echo "  rustup Solana toolchain unavailable; trying PATH rustc with --no-rustup-override"
    else
      printSbfToolchainHint
      skip "rustup Solana toolchain unavailable: $SOLANA_RUSTUP_TOOLCHAIN"
    fi
    ;;
  0|false|no)
    use_no_rustup_override=1
    ;;
  *)
    fail "invalid PROOF_FORGE_PINOCCHIO_USE_RUSTUP value: ${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-}"
    ;;
esac
buildPinocchioReference() {
  if [ "$use_no_rustup_override" = "1" ]; then
    "$CARGO_BUILD_SBF_BIN" --no-rustup-override \
      --manifest-path "$REFERENCE_DIR/Cargo.toml" \
      --no-default-features \
      --features bpf-entrypoint \
      --sbf-out-dir "$PINOCCHIO_BUILD_DIR" \
      --arch "$SBPF_ARCH"
  else
    "$CARGO_BUILD_SBF_BIN" \
      --manifest-path "$REFERENCE_DIR/Cargo.toml" \
      --no-default-features \
      --features bpf-entrypoint \
      --sbf-out-dir "$PINOCCHIO_BUILD_DIR" \
      --arch "$SBPF_ARCH"
  fi
}
if ! buildPinocchioReference \
    > "$OUT_DIR/pinocchio-build.stdout.log" \
    2> "$OUT_DIR/pinocchio-build.stderr.log"; then
  echo "Pinocchio cargo-build-sbf stdout:" >&2
  sed -n '1,160p' "$OUT_DIR/pinocchio-build.stdout.log" >&2 || true
  echo "Pinocchio cargo-build-sbf stderr:" >&2
  sed -n '1,160p' "$OUT_DIR/pinocchio-build.stderr.log" >&2 || true
  printSbfToolchainHint
  skip "Pinocchio reference SBF build failed"
fi
PINOCCHIO_BUILT_ELF="$(find "$PINOCCHIO_BUILD_DIR" -maxdepth 1 -type f -name '*.so' | head -n 1)"
[ -n "$PINOCCHIO_BUILT_ELF" ] || fail "Pinocchio ELF not found in $PINOCCHIO_BUILD_DIR"
cp "$PINOCCHIO_BUILT_ELF" "$PINOCCHIO_ELF"

echo "=== Pinocchio SPL Token transfer live equivalence step 3: generate local keypairs ==="
"$KEYGEN" new --no-bip39-passphrase --silent -o "$PAYER_KEYPAIR" --force \
  || fail "payer keypair generation failed"
"$KEYGEN" new --no-bip39-passphrase --silent -o "$PROOF_FORGE_PROGRAM_KEYPAIR" --force \
  || fail "ProofForge program keypair generation failed"
"$KEYGEN" new --no-bip39-passphrase --silent -o "$PINOCCHIO_PROGRAM_KEYPAIR" --force \
  || fail "Pinocchio program keypair generation failed"
PAYER_PUBKEY="$("$KEYGEN" pubkey "$PAYER_KEYPAIR")"
PROOF_FORGE_PROGRAM_ID="$("$KEYGEN" pubkey "$PROOF_FORGE_PROGRAM_KEYPAIR")"
PINOCCHIO_PROGRAM_ID="$("$KEYGEN" pubkey "$PINOCCHIO_PROGRAM_KEYPAIR")"
echo "  payer: $PAYER_PUBKEY"
echo "  ProofForge program id: $PROOF_FORGE_PROGRAM_ID"
echo "  Pinocchio program id: $PINOCCHIO_PROGRAM_ID"

echo "=== Pinocchio SPL Token transfer live equivalence step 4: start Surfpool ==="
"$SURFPOOL_BIN" start \
  --host "$RPC_HOST" \
  --port "$RPC_PORT" \
  --ws-port "$WS_PORT" \
  --offline \
  --no-tui \
  --no-studio \
  --no-deploy \
  --airdrop-keypair-path "$PAYER_KEYPAIR" \
  --log-path "$SURFPOOL_LOG_DIR" \
  > "$OUT_DIR/surfpool.stdout.log" 2> "$OUT_DIR/surfpool.stderr.log" &
SURFPOOL_PID="$!"

for _ in $(seq 1 60); do
  if "$SOLANA_BIN" --url "$RPC_URL" cluster-version >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$SURFPOOL_PID" >/dev/null 2>&1; then
    echo "Surfpool stdout:" >&2
    sed -n '1,160p' "$OUT_DIR/surfpool.stdout.log" >&2 || true
    echo "Surfpool stderr:" >&2
    sed -n '1,160p' "$OUT_DIR/surfpool.stderr.log" >&2 || true
    fail "surfpool exited before RPC became available"
  fi
  sleep 1
done
"$SOLANA_BIN" --url "$RPC_URL" cluster-version >/dev/null 2>&1 \
  || fail "surfpool RPC did not become ready at $RPC_URL"
echo "  RPC ready: $RPC_URL"
"$SOLANA_BIN" --url "$RPC_URL" airdrop 40 "$PAYER_PUBKEY" >/dev/null \
  || fail "airdrop to payer failed"

echo "=== Pinocchio SPL Token transfer live equivalence step 5: deploy both programs ==="
"$SOLANA_BIN" program deploy \
  --url "$RPC_URL" \
  --keypair "$PAYER_KEYPAIR" \
  --program-id "$PROOF_FORGE_PROGRAM_KEYPAIR" \
  --skip-feature-verify \
  --skip-preflight \
  --use-rpc \
  "$PROOF_FORGE_ELF" \
  || fail "ProofForge program deploy failed"
"$SOLANA_BIN" program deploy \
  --url "$RPC_URL" \
  --keypair "$PAYER_KEYPAIR" \
  --program-id "$PINOCCHIO_PROGRAM_KEYPAIR" \
  --skip-feature-verify \
  --skip-preflight \
  --use-rpc \
  "$PINOCCHIO_ELF" \
  || fail "Pinocchio program deploy failed"

echo "=== Pinocchio SPL Token transfer live equivalence step 6: run Web3.js behavior checks ==="
cp "$JS_TEMPLATE" "$NODE_PROJECT/spl_token_transfer_cpi_web3_smoke.mjs"
if [ ! -f "$NODE_PROJECT/package.json" ]; then
  ( cd "$NODE_PROJECT" && "$NPM_BIN" init -y >/dev/null ) \
    || fail "npm init failed"
fi
( cd "$NODE_PROJECT" && "$NPM_BIN" install --silent @solana/web3.js@^1.98.0 @solana/spl-token@^0.4.14 ) \
  || fail "npm install @solana/web3.js @solana/spl-token failed"

PROOF_FORGE_SOLANA_RPC_URL="$RPC_URL" \
PROOF_FORGE_SOLANA_WS_URL="$WS_URL" \
PROOF_FORGE_SOLANA_PAYER="$PAYER_KEYPAIR" \
PROOF_FORGE_SOLANA_PROGRAM_ID="$PROOF_FORGE_PROGRAM_ID" \
PROOF_FORGE_SOLANA_TOKEN_DECIMALS="$TOKEN_DECIMALS" \
PROOF_FORGE_SOLANA_TOKEN_TRANSFER_AMOUNT="$TRANSFER_AMOUNT" \
PROOF_FORGE_SOLANA_TOKEN_INITIAL_AMOUNT="$INITIAL_AMOUNT" \
  node "$NODE_PROJECT/spl_token_transfer_cpi_web3_smoke.mjs" > "$OUT_DIR/proofforge-result.json" \
  || fail "Web3.js ProofForge SPL Token transfer_checked CPI checks failed"
PROOF_FORGE_SOLANA_RPC_URL="$RPC_URL" \
PROOF_FORGE_SOLANA_WS_URL="$WS_URL" \
PROOF_FORGE_SOLANA_PAYER="$PAYER_KEYPAIR" \
PROOF_FORGE_SOLANA_PROGRAM_ID="$PINOCCHIO_PROGRAM_ID" \
PROOF_FORGE_SOLANA_TOKEN_DECIMALS="$TOKEN_DECIMALS" \
PROOF_FORGE_SOLANA_TOKEN_TRANSFER_AMOUNT="$TRANSFER_AMOUNT" \
PROOF_FORGE_SOLANA_TOKEN_INITIAL_AMOUNT="$INITIAL_AMOUNT" \
  node "$NODE_PROJECT/spl_token_transfer_cpi_web3_smoke.mjs" > "$OUT_DIR/pinocchio-result.json" \
  || fail "Web3.js Pinocchio SPL Token transfer_checked CPI checks failed"

python3 - "$OUT_DIR/proofforge-result.json" "$OUT_DIR/pinocchio-result.json" <<'PY'
import json
import pathlib
import sys

proof = json.loads(pathlib.Path(sys.argv[1]).read_text())
reference = json.loads(pathlib.Path(sys.argv[2]).read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

def as_int(result, field):
    return int(result[field])

for label, result in (("ProofForge", proof), ("Pinocchio", reference)):
    transfer = as_int(result, "transferAmount")
    source_before = as_int(result, "sourceBefore")
    source_after = as_int(result, "sourceAfter")
    destination_before = as_int(result, "destinationBefore")
    destination_after = as_int(result, "destinationAfter")
    recorded = as_int(result, "recordedAmount")
    require(source_before - source_after == transfer,
            f"{label} source delta mismatch: {result}")
    require(destination_after - destination_before == transfer,
            f"{label} destination delta mismatch: {result}")
    require(recorded == transfer,
            f"{label} state write mismatch: {result}")

for field in ("decimals", "transferAmount", "recordedAmount"):
    require(proof[field] == reference[field],
            f"{field} mismatch: proof={proof[field]} reference={reference[field]}")

print(json.dumps({
    "proofForgeProgramId": proof["programId"],
    "pinocchioProgramId": reference["programId"],
    "decimals": proof["decimals"],
    "transferAmount": proof["transferAmount"],
    "proofForgeRecordedAmount": proof["recordedAmount"],
    "pinocchioRecordedAmount": reference["recordedAmount"],
}, sort_keys=True))
PY

echo "=== Pinocchio SPL Token transfer_checked live equivalence: PASS ==="
