/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Product honesty: TokenFeature × primary target support matrix.
-/
import ProofForge.Contract.Token
import ProofForge.Target.Registry

open ProofForge.Contract.Token
open ProofForge.Target

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def main : IO Unit := do
  let rows := primaryFeatureMatrix
  require (rows.size == primaryTokenTargetIds.size * knownFeatureIds.size)
    s!"matrix size {rows.size}"

  -- EVM: core full; extension features + permit reject (T2.2 permanent policy).
  for f in corePortableFeatures do
    require (featureSupportOnTarget "evm" f == .full)
      s!"evm should fully support {f.id}"
    require (planSucceedsForFeature evm f)
      s!"evm planForTarget should succeed for {f.id}"
  for f in solanaExtensionFeatures do
    require (featureSupportOnTarget "evm" f == .reject)
      s!"evm should reject {f.id}"
    require (!planSucceedsForFeature evm f)
      s!"evm planForTarget must fail for {f.id}"
  require (featureSupportOnTarget "evm" .permit == .reject)
    "evm permanently rejects permit until EIP-2612 materializer"
  require (!planSucceedsForFeature evm .permit)
    "evm planForTarget must fail for permit"
  match planForTarget evm {
    name := "Fee", symbol := "FEE", decimals := 9, features := #[.transferFee]
  } with
  | .ok _ => throw (IO.userError "EVM must reject transfer_fee permanently")
  | .error msg =>
      require (msg.contains "product policy" || msg.contains "rejects")
        s!"EVM reject should state product policy, got: {msg}"
      require (msg.contains "solana-sbpf-asm")
        s!"EVM reject should point to Solana: {msg}"

  -- Solana: core + extension full (Token-2022 when needed).
  for f in corePortableFeatures do
    require (featureSupportOnTarget "solana-sbpf-asm" f == .full)
      s!"solana should support core {f.id}"
    require (planSucceedsForFeature solanaSbpfAsm f)
      s!"solana plan ok for {f.id}"
  for f in solanaExtensionFeatures do
    require (featureSupportOnTarget "solana-sbpf-asm" f == .full)
      s!"solana should support extension {f.id}"
    -- transfer_fee + non_transferable together is invalid; single-feature ok
    if f != .transferFee && f != .nonTransferable then
      require (planSucceedsForFeature solanaSbpfAsm f)
        s!"solana plan ok for {f.id}"
    else
      require (planSucceedsForFeature solanaSbpfAsm f)
        s!"solana single-feature plan ok for {f.id}"

  -- NEAR: core NEP-141 plan lane; extension features reject.
  for f in corePortableFeatures do
    require (featureSupportOnTarget "wasm-near" f == .full)
      s!"wasm-near should plan core {f.id}"
    require (planSucceedsForFeature wasmNear f)
      s!"wasm-near planForTarget should succeed for {f.id}"
  for f in solanaExtensionFeatures do
    require (featureSupportOnTarget "wasm-near" f == .reject)
      s!"wasm-near should reject extension {f.id}"
    require (!planSucceedsForFeature wasmNear f)
      s!"wasm-near plan must fail for {f.id}"
  match planForTarget wasmNear {
    name := "NearFT", symbol := "NFT", decimals := 18, features := #[.mintable, .burnable]
  } with
  | .error e => throw (IO.userError s!"NEAR mintable+burnable plan: {e}")
  | .ok p =>
      require (p.standard == .nep141) "NEAR plan standard is nep-141"
      require (p.artifactKind == .nearNep141Plan) "NEAR plan artifact kind"
  require (featureSupportOnTarget "wasm-stellar-soroban" .mintable == .noLane)
    "soroban has no TokenSpec lane yet"
  match planForTarget wasmStellarSoroban {
    name := "X", symbol := "X", decimals := 0, features := #[.mintable]
  } with
  | .ok _ => throw (IO.userError "soroban TokenSpec plan must fail")
  | .error msg =>
      require (msg.contains "no TokenSpec lane")
        s!"soroban error should name no TokenSpec lane, got: {msg}"

  -- Combined FeeToken intent: Solana ok, EVM reject.
  let fee : TokenSpec := {
    name := "Fee"
    symbol := "FEE"
    decimals := 9
    features := #[.transferFee]
  }
  match planForTarget solanaSbpfAsm fee with
  | .error e => throw (IO.userError s!"Solana FeeToken should plan: {e}")
  | .ok p =>
      require (p.standard == .splToken2022) "FeeToken → Token-2022 on Solana"
  match planForTarget evm fee with
  | .ok _ => throw (IO.userError "EVM must reject transfer_fee")
  | .error e =>
      require (e.contains "transfer_fee") "EVM reject names the feature"

  IO.println s!"token-feature-matrix: ok ({rows.size} rows · evm·solana·near honesty)"
