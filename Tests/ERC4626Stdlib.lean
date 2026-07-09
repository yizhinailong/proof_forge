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
  require (entryFeeShares 1000 0 == 0) "fee zero"
  require (entryFeeShares 1000 100 == 10) "fee 1%"
  require (netAfterEntryFee 1000 100 == 990) "net after entry 1%"
  require (netAfterExitFee 1000 100 == 990) "net after exit 1%"
  require (grossSharesForNet 990 100 == some 1000) "gross for net mint"
  require (grossSharesForNet 100 0 == some 100) "gross identity"
  -- fee-on-transfer: Spec accounts **actual** received (99), not requested (100)
  match depositActual? empty 99 0 with
  | none => throw (IO.userError "fot actual deposit")
  | some (sFot, shFot) =>
      require (shFot == 99 && sFot.totalAssets == 99) "fot uses actual delta"
  match deposit? s0 100 0 with
  | none => throw (IO.userError "deposit should succeed")
  | some (s1, shares1) =>
      require (shares1 == 100) "first deposit 1:1 shares"
      require (s1.totalAssets == 100 && s1.totalSupply == 100) "deposit amounts"
      -- still 1:1 after first deposit
      require (convertToShares s1 40 == 40) "post-deposit convert"
      match withdraw? s1 40 0 with
      | none => throw (IO.userError "withdraw should succeed")
      | some (s2, burned) =>
          require (burned == 40) "withdraw burns 1:1 shares"
          require (s2.totalAssets == 60 && s2.totalSupply == 60) "withdraw remaining"
      match withdraw? s1 200 0 with
      | some _ => throw (IO.userError "over-withdraw must fail")
      | none => pure ()
      -- pro-rata after donation: assets grow without minting shares
      let sDonated := { totalAssets := s1.totalAssets + 100, totalSupply := s1.totalSupply }
      require (convertToShares sDonated 100 == 50)
        "donation: 100 assets → 50 shares (100*100/200)"
      require (convertToAssets sDonated 50 == 100)
        "donation: 50 shares → 100 assets"
      match deposit? sDonated 100 0 with
      | none => throw (IO.userError "pro-rata deposit should succeed")
      | some (s3, sh3) =>
          require (sh3 == 50) "pro-rata mint shares"
          require (s3.totalAssets == 300 && s3.totalSupply == 150) "pro-rata totals"
      -- entry fee: user gets 99%, totalSupply still gross
      match deposit? empty 1000 100 with
      | none => throw (IO.userError "fee deposit should succeed")
      | some (sFee, userSh) =>
          require (userSh == 990) "user net after 1% fee"
          require (sFee.totalSupply == 1000 && sFee.totalAssets == 1000) "gross supply"
          -- exit fee: redeem all supply-equivalent path via Spec
          match redeem? sFee 1000 100 with
          | none => throw (IO.userError "redeem with exit fee should succeed")
          | some (sOut, userAssets) =>
              require (userAssets == 990) "user net assets after 1% exit fee"
              require (sOut.totalAssets == 0 && sOut.totalSupply == 0) "emptied"
      match deposit? s1 0 0 with
      | some _ => throw (IO.userError "zero deposit must fail")
      | none => pure ()

  let m := ProofForge.Contract.Stdlib.ERC4626.module
  require (m.name == "ERC4626") "module name"
  let names := m.entrypoints.map (·.name)
  for n in #["deposit", "mint", "withdraw", "redeem", "convertToShares",
              "convertToAssets", "totalAssets", "asset", "balanceOf", "maxWithdraw",
              "previewDeposit", "previewMint", "previewWithdraw", "previewRedeem"] do
    require (names.any (· == n)) s!"entrypoint {n}"

  require (m.capabilities.any (· == .crosscallInvoke)) "asset pull uses crosscall"
  require (m.state.any (fun s => s.id == "convertScratch")) "pro-rata scratch slot"
  require (m.state.any (fun s => s.id == "actualAssets")) "fot actual assets slot"
  require (m.state.any (fun s => s.id == "balanceScratch")) "fot balance scratch"

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

  IO.println "erc4626-stdlib: ok (pro-rata·entry/exit fee·EVM·Solana; NEAR honest reject)"
  pure 0

end ProofForge.Tests.ERC4626Stdlib

def main : IO UInt32 :=
  ProofForge.Tests.ERC4626Stdlib.main
