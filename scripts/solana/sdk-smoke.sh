#!/usr/bin/env bash
# Smoke test for the Solana SDK target-extension path.
#
# This gate validates that a contract written with `ProofForge.Solana` SDK
# helpers emits:
#   - sBPF assembly
#   - manifest.toml with PDA/CPI extension metadata
#   - proof-forge-artifact.json with capability plan and Solana extension data
#
# If `sbpf` and `solana-keygen` are available, it also verifies that the
# emitted assembly can be placed in a standard sbpf project and built.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${PROOF_FORGE_SOLANA_SDK_OUT:-build/solana-sdk}"
ASM_OUTPUT="$OUT_DIR/SolanaVault.s"
ARTIFACT_OUTPUT="$OUT_DIR/proof-forge-artifact.json"
MANIFEST_OUTPUT="$OUT_DIR/manifest.toml"
PROJECT_NAME="proofforge-solana-vault"
SBPF_BIN="${SBPF:-sbpf}"
KEYGEN="${SOLANA_KEYGEN:-solana-keygen}"

fail() { echo "FAIL: $1" >&2; exit 1; }

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
command -v python3 >/dev/null 2>&1 || fail "python3 not on PATH"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "=== Solana SDK step 1: emit SDK fixture ==="
lake env proof-forge --emit-solana-sdk-sbpf \
  -o "$ASM_OUTPUT" \
  --artifact-output "$ARTIFACT_OUTPUT" \
  || fail "proof-forge --emit-solana-sdk-sbpf failed"

[ -f "$ASM_OUTPUT" ] || fail "assembly file not written: $ASM_OUTPUT"
[ -f "$MANIFEST_OUTPUT" ] || fail "manifest not written: $MANIFEST_OUTPUT"
[ -f "$ARTIFACT_OUTPUT" ] || fail "artifact metadata not written: $ARTIFACT_OUTPUT"

echo "=== Solana SDK step 2: validate manifest and artifact metadata ==="
python3 - "$MANIFEST_OUTPUT" "$ARTIFACT_OUTPUT" "$ASM_OUTPUT" <<'PY'
import json
import pathlib
import sys
import tomllib

manifest_path = pathlib.Path(sys.argv[1])
artifact_path = pathlib.Path(sys.argv[2])
asm_path = pathlib.Path(sys.argv[3])
manifest = tomllib.loads(manifest_path.read_text())
artifact = json.loads(artifact_path.read_text())
asm = asm_path.read_text()

caps = set(artifact.get("capabilities", []))
required_caps = {"storage.scalar", "account.explicit", "storage.pda", "crosscall.cpi"}
missing = sorted(required_caps - caps)
if missing:
    raise SystemExit(f"missing capabilities in artifact: {missing}")

pdas = artifact.get("solanaExtensions", {}).get("pdas", [])
cpis = artifact.get("solanaExtensions", {}).get("cpis", [])
if not pdas or pdas[0].get("name") != "vault":
    raise SystemExit("artifact missing vault PDA extension")
if not cpis or cpis[0].get("name") != "token_transfer":
    raise SystemExit("artifact missing token_transfer CPI extension")

manifest_pdas = manifest.get("solana", {}).get("pda", [])
manifest_cpis = manifest.get("solana", {}).get("cpi", [])
if not manifest_pdas or manifest_pdas[0].get("name") != "vault":
    raise SystemExit("manifest missing vault PDA extension")
if not manifest_cpis or manifest_cpis[0].get("program") != "spl_token":
    raise SystemExit("manifest missing spl_token CPI extension")

for needle in [
    "sol_pda_derive_vault:",
    "call sol_create_program_address",
    "sol_cpi_token_transfer:",
    "call sol_invoke_signed_c",
]:
    if needle not in asm:
        raise SystemExit(f"assembly missing {needle!r}")

print("metadata validation: ok")
PY

echo "=== Solana SDK step 3: optional sbpf build ==="
if command -v "$SBPF_BIN" >/dev/null 2>&1 && command -v "$KEYGEN" >/dev/null 2>&1; then
  PROJECT_DIR="$OUT_DIR/sdk-build"
  rm -rf "$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR/deploy" "$PROJECT_DIR/src/$PROJECT_NAME"

  "$KEYGEN" new --no-bip39-passphrase --silent \
    -o "$PROJECT_DIR/deploy/$PROJECT_NAME-keypair.json" --force \
    || fail "solana-keygen failed"

  cp "$ASM_OUTPUT" "$PROJECT_DIR/src/$PROJECT_NAME/$PROJECT_NAME.s"
  printf '[package]\nname = "%s"\nversion = "0.1.0"\nedition = "2021"\n' "$PROJECT_NAME" \
    > "$PROJECT_DIR/Cargo.toml"
  : > "$PROJECT_DIR/src/lib.rs"

  ( cd "$PROJECT_DIR" && "$SBPF_BIN" build ) || fail "sbpf build failed"
  [ -f "$PROJECT_DIR/deploy/$PROJECT_NAME.so" ] || fail "ELF not produced"
  echo "sbpf build: ok"
else
  echo "sbpf build: skipped (requires sbpf and solana-keygen)"
fi

echo "=== Solana SDK smoke: PASS ==="
