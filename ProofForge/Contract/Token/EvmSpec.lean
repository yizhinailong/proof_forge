/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Build canonical ERC-20 `ContractSpec` values from Lean `TokenSpec` metadata.
-/
import ProofForge.Contract.Token
import ProofForge.Contract.Stdlib.ERC20

namespace ProofForge.Contract.Token.EvmSpec

open ProofForge.Contract.Token
open ProofForge.Contract.Stdlib.ERC20
open ProofForge.IR

def fungibleSpec : ProofForge.Contract.ContractSpec := spec

private def keepEntrypoint (token : TokenSpec) (entrypoint : Entrypoint) : Bool :=
  entrypoint.name != "init" &&
    (entrypoint.name != "mint" || token.hasFeature .mintable) &&
    (entrypoint.name != "burn" || token.hasFeature .burnable)

private def canonicalSelector? (name : String) : Option String :=
  match name with
  | "totalSupply" => some "18160ddd"
  | "decimals" => some "313ce567"
  | "balanceOf" => some "70a08231"
  | "allowance" => some "dd62ed3e"
  | "transfer" => some "a9059cbb"
  | "approve" => some "095ea7b3"
  | "transferFrom" => some "23b872dd"
  | "mint" => some "40c10f19"
  | "burn" => some "42966c68"
  | _ => none

def withCanonicalSelectors (module : Module) : Module :=
  { module with
    entrypoints := module.entrypoints.map fun entrypoint =>
      { entrypoint with selector? := canonicalSelector? entrypoint.name } }

def moduleFor (token : TokenSpec) : Module :=
  withCanonicalSelectors <|
    { fungibleSpec.module with
      name := token.symbol
      entrypoints := fungibleSpec.module.entrypoints.filter (keepEntrypoint token) }

def specFor (token : TokenSpec) : ProofForge.Contract.ContractSpec :=
  { fungibleSpec with
    name := token.symbol
    module := moduleFor token }

end ProofForge.Contract.Token.EvmSpec
