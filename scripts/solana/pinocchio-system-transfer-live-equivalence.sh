#!/usr/bin/env bash
# ProofForge vs Pinocchio System transfer live equivalence on Surfpool.
#
# Builds the generated ProofForge System transfer CPI ELF and the checked-in
# Pinocchio reference ELF, deploys both programs to the same Surfpool instance,
# invokes the same Web3.js System transfer scenario against each program, and
# compares the observable lamport delta plus state write.
#
# Exit codes:
#   0 - live equivalence passed
#   1 - a gate failed
#   2 - a prerequisite is missing (skipped)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_PINOCCHIO_SYSTEM_TRANSFER_LIVE_OUT:-build/solana-pinocchio-system-transfer-live}"
REFERENCE_DIR="$REPO_ROOT/references/solana/pinocchio/system-transfer"
PROOF_FORGE_PROJECT_NAME="proofforge-system-transfer-live"
PINOCCHIO_PROJECT_NAME="pinocchio-system-transfer-reference"
PROOF_FORGE_ELF="$OUT_DIR/$PROOF_FORGE_PROJECT_NAME.so"
PROOF_FORGE_ARTIFACT="$OUT_DIR/proof-forge-artifact.json"
PINOCCHIO_BUILD_DIR="$OUT_DIR/pinocchio-build"
PINOCCHIO_ELF="$OUT_DIR/$PINOCCHIO_PROJECT_NAME.so"
PAYER_KEYPAIR="$OUT_DIR/payer.json"
PROOF_FORGE_PROGRAM_KEYPAIR="$OUT_DIR/proofforge-program-keypair.json"
PINOCCHIO_PROGRAM_KEYPAIR="$OUT_DIR/pinocchio-program-keypair.json"
JS_TEMPLATE="$REPO_ROOT/Tests/solana/system_cpi_web3_smoke.mjs"
NODE_PROJECT="$OUT_DIR/web3"
SURFPOOL_BIN="${SURFPOOL:-surfpool}"
SOLANA_BIN="${SOLANA:-solana}"
KEYGEN="${SOLANA_KEYGEN:-solana-keygen}"
NPM_BIN="${NPM:-npm}"
CARGO_BUILD_SBF_BIN="${CARGO_BUILD_SBF:-cargo-build-sbf}"
SBPF_ARCH="${PROOF_FORGE_SOLANA_SYSTEM_CPI_SBPF_ARCH:-v0}"
SOLANA_RUSTUP_TOOLCHAIN="${PROOF_FORGE_PINOCCHIO_RUSTUP_TOOLCHAIN:-1.89.0-sbpf-solana-v1.52}"
RPC_HOST="${PROOF_FORGE_SURFPOOL_HOST:-127.0.0.1}"
RPC_PORT="${PROOF_FORGE_PINOCCHIO_SYSTEM_TRANSFER_SURFPOOL_PORT:-8908}"
WS_PORT="${PROOF_FORGE_PINOCCHIO_SYSTEM_TRANSFER_SURFPOOL_WS_PORT:-8909}"
RPC_URL="http://$RPC_HOST:$RPC_PORT"
SURFPOOL_LOG_DIR="$OUT_DIR/surfpool-logs"
LAMPORTS="${PROOF_FORGE_SOLANA_TRANSFER_LAMPORTS:-5000}"
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
  PATH="\$HOME/.cargo/bin:\$PATH" cargo-build-sbf --force-tools-install --tools-version v1.52
Then rerun:
  PROOF_FORGE_PINOCCHIO_USE_RUSTUP=1 scripts/solana/pinocchio-system-transfer-live-equivalence.sh
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

echo "=== Pinocchio live equivalence step 1: build ProofForge fixture ELF ==="
lake env proof-forge --solana-system-cpi-elf --solana-sbpf-arch "$SBPF_ARCH" \
  -o "$PROOF_FORGE_ELF" \
  --artifact-output "$PROOF_FORGE_ARTIFACT" \
  || fail "proof-forge --solana-system-cpi-elf failed"
[ -f "$PROOF_FORGE_ELF" ] || fail "ProofForge ELF not produced: $PROOF_FORGE_ELF"

echo "=== Pinocchio live equivalence step 2: build Pinocchio reference ELF ==="
build_sbf_args=()
case "${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-auto}" in
  1|true|yes|auto)
    if rustupCargoAvailable; then
      export PATH="$HOME/.cargo/bin:$PATH"
      echo "  using rustup Solana toolchain: $SOLANA_RUSTUP_TOOLCHAIN"
    elif [ "${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-auto}" = "auto" ]; then
      build_sbf_args+=(--no-rustup-override)
      echo "  rustup Solana toolchain unavailable; trying PATH rustc with --no-rustup-override"
    else
      printSbfToolchainHint
      skip "rustup Solana toolchain unavailable: $SOLANA_RUSTUP_TOOLCHAIN"
    fi
    ;;
  0|false|no)
    build_sbf_args+=(--no-rustup-override)
    ;;
  *)
    fail "invalid PROOF_FORGE_PINOCCHIO_USE_RUSTUP value: ${PROOF_FORGE_PINOCCHIO_USE_RUSTUP:-}"
    ;;
esac
if ! "$CARGO_BUILD_SBF_BIN" "${build_sbf_args[@]}" \
    --manifest-path "$REFERENCE_DIR/Cargo.toml" \
    --no-default-features \
    --features bpf-entrypoint \
    --sbf-out-dir "$PINOCCHIO_BUILD_DIR" \
    --arch "$SBPF_ARCH" \
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

echo "=== Pinocchio live equivalence step 3: generate local keypairs ==="
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

echo "=== Pinocchio live equivalence step 4: start Surfpool ==="
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
"$SOLANA_BIN" --url "$RPC_URL" airdrop 30 "$PAYER_PUBKEY" >/dev/null \
  || fail "airdrop to payer failed"

echo "=== Pinocchio live equivalence step 5: deploy both programs ==="
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

echo "=== Pinocchio live equivalence step 6: run Web3.js behavior checks ==="
cp "$JS_TEMPLATE" "$NODE_PROJECT/system_cpi_web3_smoke.mjs"
if [ ! -f "$NODE_PROJECT/package.json" ]; then
  ( cd "$NODE_PROJECT" && "$NPM_BIN" init -y >/dev/null ) \
    || fail "npm init failed"
fi
( cd "$NODE_PROJECT" && "$NPM_BIN" install --silent @solana/web3.js@^1.98.0 ) \
  || fail "npm install @solana/web3.js failed"

PROOF_FORGE_SOLANA_RPC_URL="$RPC_URL" \
PROOF_FORGE_SOLANA_PAYER="$PAYER_KEYPAIR" \
PROOF_FORGE_SOLANA_PROGRAM_ID="$PROOF_FORGE_PROGRAM_ID" \
PROOF_FORGE_SOLANA_TRANSFER_LAMPORTS="$LAMPORTS" \
  node "$NODE_PROJECT/system_cpi_web3_smoke.mjs" > "$OUT_DIR/proofforge-result.json" \
  || fail "Web3.js ProofForge System CPI checks failed"
PROOF_FORGE_SOLANA_RPC_URL="$RPC_URL" \
PROOF_FORGE_SOLANA_PAYER="$PAYER_KEYPAIR" \
PROOF_FORGE_SOLANA_PROGRAM_ID="$PINOCCHIO_PROGRAM_ID" \
PROOF_FORGE_SOLANA_TRANSFER_LAMPORTS="$LAMPORTS" \
  node "$NODE_PROJECT/system_cpi_web3_smoke.mjs" > "$OUT_DIR/pinocchio-result.json" \
  || fail "Web3.js Pinocchio System CPI checks failed"

python3 - "$OUT_DIR/proofforge-result.json" "$OUT_DIR/pinocchio-result.json" <<'PY'
import json
import pathlib
import sys

proof = json.loads(pathlib.Path(sys.argv[1]).read_text())
reference = json.loads(pathlib.Path(sys.argv[2]).read_text())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

for label, result in (("ProofForge", proof), ("Pinocchio", reference)):
    delta = result["recipientAfter"] - result["recipientBefore"]
    require(delta == result["lamports"], f"{label} recipient delta mismatch: {result}")
    require(result["recorded"] == result["lamports"], f"{label} state write mismatch: {result}")

for field in ("lamports", "recorded"):
    require(proof[field] == reference[field],
            f"{field} mismatch: proof={proof[field]} reference={reference[field]}")

print(json.dumps({
    "proofForgeProgramId": proof["programId"],
    "pinocchioProgramId": reference["programId"],
    "lamports": proof["lamports"],
    "proofForgeRecorded": proof["recorded"],
    "pinocchioRecorded": reference["recorded"],
}, sort_keys=True))
PY

echo "=== Pinocchio System transfer live equivalence: PASS ==="
