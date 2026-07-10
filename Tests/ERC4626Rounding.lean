/-
ERC-4626 inverse quote rounding regression.
-/
import ProofForge.Contract.Stdlib.ERC4626

namespace ProofForge.Tests.ERC4626Rounding

open ProofForge.Contract.Stdlib.ERC4626.Spec

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def main : IO UInt32 := do
  let rounding : State := { totalAssets := 2, totalSupply := 3 }
  require (convertToAssetsUp rounding 1 == 1)
    "previewMint must round required assets up"
  require (convertToSharesUp rounding 1 == 2)
    "previewWithdraw must round required shares up"
  require (convertToAssetsUp rounding 0 == 0 && convertToSharesUp rounding 0 == 0)
    "ceil conversion must preserve zero"
  require (convertToAssetsUp { totalAssets := 6, totalSupply := 3 } 1 == 2)
    "ceil conversion must preserve exact division"
  require (previewMintAssets? rounding 990 100 == some 667)
    "previewMint must round up after fee grossing"
  require (previewWithdrawShares rounding 1 == 2)
    "previewWithdraw must use ceil share conversion"
  match withdraw? rounding 1 0 with
  | none => throw (IO.userError "rounded withdraw should succeed")
  | some (next, burned) =>
      require (burned == 2) "withdraw must burn its rounded-up quote"
      require (next.totalAssets == 1 && next.totalSupply == 1)
        "withdraw totals must match the rounded-up burn"
  IO.println "erc4626-rounding: ok"
  pure 0

end ProofForge.Tests.ERC4626Rounding

def main : IO UInt32 :=
  ProofForge.Tests.ERC4626Rounding.main
