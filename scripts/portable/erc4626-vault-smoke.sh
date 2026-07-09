#!/usr/bin/env bash
# Wave ε Layer C: ERC-4626 stdlib vault body multi-target smoke.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.elan/bin:$HOME/.local/bin:$HOME/.foundry/bin:$PATH"

OUT="${PROOF_FORGE_ERC4626_OUT:-build/portable/erc4626-vault}"
DRIVER="$OUT/emit.lean"

fail() { echo "FAIL: $1" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "missing $1"; }
require_contains() { grep -Fq -- "$2" "$1" || fail "$3 missing '$2' in $1"; }

command -v lake >/dev/null 2>&1 || fail "lake not on PATH"
rm -rf "$OUT"
mkdir -p "$OUT/evm" "$OUT/solana" "$OUT/near"

echo "=== product-erc4626-vault: build stdlib ==="
lake build ProofForge.Contract.Stdlib.ERC4626 ProofForge.Backend.Evm.IR \
  ProofForge.Backend.Solana.SbpfAsm ProofForge.Backend.WasmHost.EmitWat >/dev/null \
  || fail "lake build ERC4626 failed"

cat >"$DRIVER" <<'EOF'
import ProofForge.Contract.Stdlib.ERC4626
import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmHost.EmitWat

def require (c : Bool) (m : String) : IO Unit :=
  if c then pure () else throw (IO.userError m)

def main : IO Unit := do
  let m := ProofForge.Contract.Stdlib.ERC4626.module
  require (m.entrypoints.any (·.name == "deposit")) "has deposit"
  require (m.entrypoints.any (·.name == "withdraw")) "has withdraw"
  require (m.entrypoints.any (·.name == "convertToShares")) "has convertToShares"
  require (m.entrypoints.any (·.name == "totalAssets")) "has totalAssets"
  require (m.entrypoints.any (·.name == "asset")) "has asset"
  require (m.state.any (fun s => s.id == "totalAssets")) "totalAssets state"
  require (m.state.any (fun s => s.id == "shareBalances") ||
    m.state.any (fun s => s.id == "totalSupply")) "share state"
  -- EVM plan
  match ProofForge.Backend.Evm.Plan.buildModulePlan m with
  | .error e => throw (IO.userError s!"EVM plan: {e.message}")
  | .ok _ => pure ()
  -- Pin selectors for Yul emit (product modules are name-only)
  let mEvm : ProofForge.IR.Module := {
    m with
    entrypoints := m.entrypoints.map fun ep =>
      match ep.name with
      | "init" => { ep with selector? := some "8129fc1c" }
      | "deposit" => { ep with selector? := some "6e553f65" }
      | "mint" => { ep with selector? := some "94bf804d" }
      | "withdraw" => { ep with selector? := some "b460af94" }
      | "redeem" => { ep with selector? := some "ba087652" }
      | "convertToShares" => { ep with selector? := some "c6e6f592" }
      | "convertToAssets" => { ep with selector? := some "07a2d13a" }
      | "totalAssets" => { ep with selector? := some "01e1d114" }
      | "asset" => { ep with selector? := some "38d52e0f" }
      | "totalSupply" => { ep with selector? := some "18160ddd" }
      | "balanceOf" => { ep with selector? := some "70a08231" }
      | "maxDeposit" => { ep with selector? := some "402d267d" }
      | "maxMint" => { ep with selector? := some "c63d75b6" }
      | "maxWithdraw" => { ep with selector? := some "ce96cb77" }
      | "maxRedeem" => { ep with selector? := some "d905777e" }
      | "transfer" => { ep with selector? := some "a9059cbb" }
      | "approve" => { ep with selector? := some "095ea7b3" }
      | _ => ep
  }
  match ProofForge.Backend.Evm.IR.renderModule mEvm with
  | .error e => throw (IO.userError s!"EVM Yul: {e.message}")
  | .ok yul =>
      IO.FS.writeFile "build/portable/erc4626-vault/evm/ERC4626.yul" yul
      require (yul.contains "deposit" || yul.contains "6e553f65" || yul.contains "f_")
        "yul has deposit path"
  match ProofForge.Backend.Solana.SbpfAsm.renderModule m with
  | .error e => throw (IO.userError s!"Solana: {e.message}")
  | .ok src =>
      IO.FS.writeFile "build/portable/erc4626-vault/solana/ERC4626.s" src
      require (src.length > 0) "solana asm non-empty"
  match ProofForge.Backend.WasmHost.EmitWat.renderModule m with
  | .error e => throw (IO.userError s!"NEAR: {e.message}")
  | .ok wat =>
      IO.FS.writeFile "build/portable/erc4626-vault/near/ERC4626.wat" wat
      require (wat.contains "deposit") "near exports deposit"
  IO.println "erc4626-vault emit: ok"
EOF

echo "=== product-erc4626-vault: multi-target emit ==="
lake env lean --run "$DRIVER" || fail "emit driver failed"
require_file "$OUT/evm/ERC4626.yul"
require_file "$OUT/solana/ERC4626.s"
require_file "$OUT/near/ERC4626.wat"
require_contains "$OUT/near/ERC4626.wat" "deposit" "NEAR deposit"
require_contains "$OUT/near/ERC4626.wat" "totalAssets" "NEAR totalAssets"
require_contains "$OUT/solana/ERC4626.s" "entrypoint" "Solana entrypoint"

echo "product-erc4626-vault: ok (stdlib body · EVM Yul · Solana · NEAR)"
