/-
Layer C ERC-4626 stdlib: solvent proofs + module surface.
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
  -- Spec theorems exist (typecheck import). Runtime checks use Nat equalities.
  let s0 := empty
  require (s0.totalAssets == 0 && s0.totalSupply == 0) "empty zero"
  match deposit? s0 100 with
  | none => throw (IO.userError "deposit should succeed")
  | some s1 =>
      require (s1.totalAssets == s1.totalSupply) "deposit solvent eq"
      require (s1.totalAssets == 100 && s1.totalSupply == 100) "deposit amounts"
      match withdraw? s1 40 with
      | none => throw (IO.userError "withdraw should succeed")
      | some s2 =>
          require (s2.totalAssets == s2.totalSupply) "withdraw solvent eq"
          require (s2.totalAssets == 60) "withdraw remaining"
      match withdraw? s1 200 with
      | some _ => throw (IO.userError "over-withdraw must fail")
      | none => pure ()

  let m := ProofForge.Contract.Stdlib.ERC4626.module
  require (m.name == "ERC4626") "module name"
  let names := m.entrypoints.map (·.name)
  for n in #["deposit", "mint", "withdraw", "redeem", "convertToShares",
              "convertToAssets", "totalAssets", "asset", "balanceOf"] do
    require (names.any (· == n)) s!"entrypoint {n}"

  require (m.capabilities.any (· == .crosscallInvoke)) "asset pull uses crosscall"

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

  IO.println "erc4626-stdlib: ok (EVM·Solana emit; NEAR honest reject for selector remotes)"
  pure 0

end ProofForge.Tests.ERC4626Stdlib

def main : IO UInt32 :=
  ProofForge.Tests.ERC4626Stdlib.main
