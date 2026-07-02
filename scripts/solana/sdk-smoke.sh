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
required_caps = {"storage.scalar", "account.explicit", "storage.pda", "runtime.allocator", "crosscall.cpi"}
missing = sorted(required_caps - caps)
if missing:
    raise SystemExit(f"missing capabilities in artifact: {missing}")

allocators = artifact.get("solanaExtensions", {}).get("allocators", [])
instructions = artifact.get("solanaInstructions", [])
pdas = artifact.get("solanaExtensions", {}).get("pdas", [])
cpis = artifact.get("solanaExtensions", {}).get("cpis", [])
pda_actions = artifact.get("solanaExtensions", {}).get("pdaActions", [])
cpi_actions = artifact.get("solanaExtensions", {}).get("cpiActions", [])
if not allocators or allocators[0].get("kind") != "bump":
    raise SystemExit("artifact missing bump runtime allocator")
if allocators[0].get("model") != "downward-bump":
    raise SystemExit("artifact missing downward-bump allocator model")
if allocators[0].get("heapStart") != "0x300000000":
    raise SystemExit("artifact missing Solana heap start")
if allocators[0].get("heapBytes") != "32768":
    raise SystemExit("artifact missing Solana heap size")
if len(instructions) != 2:
    raise SystemExit(f"artifact instruction schema count mismatch: {len(instructions)}")
instruction_accounts = [account.get("name") for account in instructions[0].get("accounts", [])]
expected_instruction_accounts = [
    "nonce",
    "vault_account",
    "source",
    "mint",
    "destination",
    "authority",
    "spl_token",
]
if instruction_accounts != expected_instruction_accounts:
    raise SystemExit(f"artifact instruction accounts mismatch: {instruction_accounts}")
program_accounts = [account for account in instructions[0].get("accounts", []) if account.get("name") == "spl_token"]
if not program_accounts or program_accounts[0].get("owner") != "executable":
    raise SystemExit("artifact missing SPL Token executable account schema")
if not pdas or pdas[0].get("name") != "vault":
    raise SystemExit("artifact missing vault PDA extension")
if not cpis or cpis[0].get("name") != "token_transfer":
    raise SystemExit("artifact missing token_transfer CPI extension")
if cpis[0].get("protocol") != "spl-token":
    raise SystemExit("artifact missing spl-token CPI protocol")
if cpis[0].get("dataLayout") != "spl-token.transfer_checked":
    raise SystemExit("artifact missing SPL Token transfer_checked data layout")
account_names = [account.get("name") for account in cpis[0].get("accounts", [])]
if account_names != ["source", "mint", "destination", "authority"]:
    raise SystemExit(f"artifact CPI accounts mismatch: {account_names}")
if not pda_actions or pda_actions[0].get("entrypoint") != "touch" or pda_actions[0].get("pda") != "vault":
    raise SystemExit("artifact missing touch PDA action")
if not cpi_actions or cpi_actions[0].get("entrypoint") != "touch" or cpi_actions[0].get("cpi") != "token_transfer":
    raise SystemExit("artifact missing touch CPI action")

manifest_allocators = manifest.get("solana", {}).get("allocator", [])
manifest_instructions = manifest.get("instruction", [])
manifest_pdas = manifest.get("solana", {}).get("pda", [])
manifest_cpis = manifest.get("solana", {}).get("cpi", [])
manifest_pda_actions = manifest.get("solana", {}).get("entrypoint_pda", [])
manifest_cpi_actions = manifest.get("solana", {}).get("entrypoint_cpi", [])
if not manifest_allocators or manifest_allocators[0].get("kind") != "bump":
    raise SystemExit("manifest missing bump runtime allocator")
if manifest_allocators[0].get("model") != "downward-bump":
    raise SystemExit("manifest missing downward-bump allocator model")
if manifest_allocators[0].get("heap_start") != "0x300000000":
    raise SystemExit("manifest missing Solana heap start")
if manifest_allocators[0].get("heap_bytes") != 32768:
    raise SystemExit("manifest missing Solana heap size")
if len(manifest_instructions) != 2:
    raise SystemExit(f"manifest instruction schema count mismatch: {len(manifest_instructions)}")
manifest_instruction_accounts = [account.get("name") for account in manifest_instructions[0].get("accounts", [])]
if manifest_instruction_accounts != expected_instruction_accounts:
    raise SystemExit(f"manifest instruction accounts mismatch: {manifest_instruction_accounts}")
manifest_program_accounts = [
    account for account in manifest_instructions[0].get("accounts", [])
    if account.get("name") == "spl_token"
]
if not manifest_program_accounts or manifest_program_accounts[0].get("owner") != "executable":
    raise SystemExit("manifest missing SPL Token executable account schema")
if not manifest_pdas or manifest_pdas[0].get("name") != "vault":
    raise SystemExit("manifest missing vault PDA extension")
if not manifest_cpis or manifest_cpis[0].get("program") != "spl_token":
    raise SystemExit("manifest missing spl_token CPI extension")
if manifest_cpis[0].get("protocol") != "spl-token":
    raise SystemExit("manifest missing spl-token CPI protocol")
if manifest_cpis[0].get("data_layout") != "spl-token.transfer_checked":
    raise SystemExit("manifest missing SPL Token transfer_checked data layout")
if not manifest_pda_actions or manifest_pda_actions[0].get("entrypoint") != "touch":
    raise SystemExit("manifest missing touch PDA action")
if not manifest_cpi_actions or manifest_cpi_actions[0].get("entrypoint") != "touch":
    raise SystemExit("manifest missing touch CPI action")

for needle in [
    "solana.allocator runtime: kind=bump model=downward-bump heap_start=0x300000000 heap_bytes=32768",
    "account.validation[1:vault_account]: owner=program",
    "account.validation[2:source]: writable=true",
    "account.validation[4:destination]: writable=true",
    "sol_pda_derive_vault:",
    "solana.pda.seed vault[0] \"vault\"",
    "stb [r5+0], 118",
    "solana.pda.seed vault[1] \"authority\"",
    "stxdw [r6+0], r5",
    "stxdw [r6+8], r3",
    "add64 r3, INSTRUCTION_DATA_LEN",
    "call sol_create_program_address",
    "PDA result stored at stack offset 64",
    "call sol_pda_derive_vault",
    "sol_cpi_token_transfer:",
    "call sol_invoke_signed_c",
    "call sol_cpi_token_transfer",
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
