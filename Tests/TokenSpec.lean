import ProofForge.Contract.Token
import ProofForge.Target.Registry

namespace ProofForge.Tests.TokenSpec

open ProofForge.Contract.Token
open ProofForge.Target

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def hasCapability (plan : TokenPlan) (capability : Capability) : Bool :=
  plan.capabilities.any (fun item => item == capability)

def hasOperation (plan : TokenPlan) (operation : String) : Bool :=
  plan.operations.any (fun item => item == operation)

def fungibleToken : TokenSpec := {
  name := "Proof Token"
  symbol := "PRF"
  decimals := 9
  initialSupply? := some 1000000
  features := #[.mintable, .burnable]
}

def transferFeeToken : TokenSpec := {
  name := "Fee Token"
  symbol := "FEE"
  decimals := 6
  initialSupply? := some 1000000
  features := #[.mintable, .transferFee]
}

def main : IO UInt32 := do
  let evmPlan ←
    match planForTarget evm fungibleToken with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err
  require (evmPlan.standard == .erc20) "EVM token plan should use ERC-20"
  require (evmPlan.artifactKind == .evmErc20Contract) "EVM token plan should emit ERC-20 contract artifact"
  require (hasCapability evmPlan .storageMap) "EVM ERC-20 plan should use mapping storage"
  require (hasOperation evmPlan "erc20.transfer") "EVM ERC-20 plan missing transfer"
  require (hasOperation evmPlan "erc20.approve") "EVM ERC-20 plan missing approve"
  require (hasOperation evmPlan "erc20.mint") "EVM ERC-20 plan missing mintable extension"

  let solanaPlan ←
    match planForTarget solanaSbpfAsm fungibleToken with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err
  require (solanaPlan.standard == .splToken) "Solana token plan should use SPL Token by default"
  require (solanaPlan.artifactKind == .solanaSplTokenPlan) "Solana token plan should emit SPL Token plan"
  require (hasCapability solanaPlan .crosscallCpi) "Solana SPL Token plan should use CPI"
  require (hasCapability solanaPlan .accountExplicit) "Solana SPL Token plan should use explicit accounts"
  require (hasOperation solanaPlan "spl-token.create_mint") "Solana SPL Token plan missing create_mint"
  require (hasOperation solanaPlan "spl-token.transfer_checked") "Solana SPL Token plan missing transfer_checked"

  let token2022Plan ←
    match planForTarget solanaSbpfAsm transferFeeToken with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err
  require (token2022Plan.standard == .splToken2022) "Solana transfer-fee token should use Token-2022"
  require (token2022Plan.artifactKind == .solanaToken2022Plan) "Solana transfer-fee token should emit Token-2022 plan"
  require (hasOperation token2022Plan "token-2022.extension.transfer_fee")
    "Token-2022 plan missing transfer-fee extension"

  match planForTarget wasmNear fungibleToken with
  | .ok _ => throw <| IO.userError "wasm-near unexpectedly accepted TokenSpec"
  | .error err =>
      require (err == "target `wasm-near` does not have a TokenSpec lowering plan yet")
        s!"unexpected unsupported-target diagnostic: {err}"

  IO.println "token-spec: ok"
  return 0

end ProofForge.Tests.TokenSpec

def main : IO UInt32 :=
  ProofForge.Tests.TokenSpec.main
