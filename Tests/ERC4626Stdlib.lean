/-
Layer C ERC-4626 stdlib: pro-rata Spec + module surface.
-/
import ProofForge.Contract.Stdlib.ERC4626
import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmHost.EmitWat

namespace ProofForge.Tests.ERC4626Stdlib

open ProofForge.Contract.Stdlib.ERC4626.Spec

def require (c : Bool) (m : String) : IO Unit :=
  if c then pure () else throw (IO.userError m)

def main : IO UInt32 := do
  -- Empty vault is 1:1
  let s0 := empty
  require (s0.totalAssets == 0 && s0.totalSupply == 0) "empty zero"
  require (convertToShares s0 50 == 50) "empty convert shares"
  require (convertToAssets s0 50 == 50) "empty convert assets"
  match deposit? s0 100 with
  | none => throw (IO.userError "deposit should succeed")
  | some (s1, shares1) =>
      require (shares1 == 100) "first deposit 1:1 shares"
      require (s1.totalAssets == 100 && s1.totalSupply == 100) "deposit amounts"
      -- still 1:1 after first deposit
      require (convertToShares s1 40 == 40) "post-deposit convert"
      match withdraw? s1 40 with
      | none => throw (IO.userError "withdraw should succeed")
      | some (s2, burned) =>
          require (burned == 40) "withdraw burns 1:1 shares"
          require (s2.totalAssets == 60 && s2.totalSupply == 60) "withdraw remaining"
      match withdraw? s1 200 with
      | some _ => throw (IO.userError "over-withdraw must fail")
      | none => pure ()
      -- pro-rata after donation: assets grow without minting shares
      let sDonated := { totalAssets := s1.totalAssets + 100, totalSupply := s1.totalSupply }
      require (convertToShares sDonated 100 == 50)
        "donation: 100 assets → 50 shares (100*100/200)"
      require (convertToAssets sDonated 50 == 100)
        "donation: 50 shares → 100 assets"
      match deposit? sDonated 100 with
      | none => throw (IO.userError "pro-rata deposit should succeed")
      | some (s3, sh3) =>
          require (sh3 == 50) "pro-rata mint shares"
          require (s3.totalAssets == 300 && s3.totalSupply == 150) "pro-rata totals"
      match deposit? s1 0 with
      | some _ => throw (IO.userError "zero deposit must fail")
      | none => pure ()

  let m := ProofForge.Contract.Stdlib.ERC4626.module
  require (m.name == "ERC4626") "module name"
  let names := m.entrypoints.map (·.name)
  for n in #["deposit", "mint", "withdraw", "redeem", "convertToShares",
              "convertToAssets", "totalAssets", "asset", "balanceOf", "maxWithdraw"] do
    require (names.any (· == n)) s!"entrypoint {n}"

  require (m.capabilities.any (· == .crosscallInvoke)) "asset pull uses crosscall"
  require (m.state.any (fun s => s.id == "convertScratch")) "pro-rata scratch slot"

  match ProofForge.Backend.Evm.Plan.buildModulePlan m with
  | .error e => throw (IO.userError s!"EVM plan: {e.message}")
  | .ok _ => pure ()
  match ProofForge.Backend.Solana.SbpfAsm.renderModule m with
  | .error e => throw (IO.userError s!"Solana: {e.message}")
  | .ok src => require (src.length > 0) "solana"
  -- NEAR: IERC20 selector remotes need a string pool; honest reject without it.
  match ProofForge.Backend.WasmHost.EmitWat.renderModule m with
  | .ok _ => throw (IO.userError "NEAR should reject empty nearCrosscallStrings for asset pull")
  | .error e =>
      require (e.message.contains "nearCrosscallStrings" || e.message.contains "crosscall")
        s!"NEAR honesty diagnostic, got: {e.message}"

  IO.println "erc4626-stdlib: ok (pro-rata Spec·EVM·Solana; NEAR honest reject)"
  pure 0

end ProofForge.Tests.ERC4626Stdlib

def main : IO UInt32 :=
  ProofForge.Tests.ERC4626Stdlib.main
