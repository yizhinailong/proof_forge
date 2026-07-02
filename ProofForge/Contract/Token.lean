import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Registry

namespace ProofForge.Contract.Token

open ProofForge.Target

inductive TokenStandard where
  | erc20
  | splToken
  | splToken2022
  deriving BEq, DecidableEq, Repr

def TokenStandard.id : TokenStandard → String
  | .erc20 => "erc20"
  | .splToken => "spl-token"
  | .splToken2022 => "spl-token-2022"

inductive TokenFeature where
  | mintable
  | burnable
  | capped
  | pausable
  | permit
  | transferFee
  | nonTransferable
  | confidentialTransfer
  | transferHook
  deriving BEq, DecidableEq, Repr

def TokenFeature.id : TokenFeature → String
  | .mintable => "mintable"
  | .burnable => "burnable"
  | .capped => "capped"
  | .pausable => "pausable"
  | .permit => "permit"
  | .transferFee => "transfer_fee"
  | .nonTransferable => "non_transferable"
  | .confidentialTransfer => "confidential_transfer"
  | .transferHook => "transfer_hook"

structure TokenSpec where
  name : String
  symbol : String
  decimals : Nat
  initialSupply? : Option Nat := none
  features : Array TokenFeature := #[]
  deriving Repr

def TokenSpec.hasFeature (spec : TokenSpec) (feature : TokenFeature) : Bool :=
  spec.features.any (fun item => item == feature)

def TokenSpec.needsToken2022 (spec : TokenSpec) : Bool :=
  spec.hasFeature .transferFee ||
  spec.hasFeature .nonTransferable ||
  spec.hasFeature .confidentialTransfer ||
  spec.hasFeature .transferHook

inductive TokenArtifactKind where
  | evmErc20Contract
  | solanaSplTokenPlan
  | solanaToken2022Plan
  deriving BEq, DecidableEq, Repr

def TokenArtifactKind.id : TokenArtifactKind → String
  | .evmErc20Contract => "evm-erc20-contract"
  | .solanaSplTokenPlan => "solana-spl-token-plan"
  | .solanaToken2022Plan => "solana-token-2022-plan"

structure TokenPlan where
  targetId : String
  standard : TokenStandard
  artifactKind : TokenArtifactKind
  capabilities : CapabilitySet
  operations : Array String
  notes : Array String := #[]
  deriving Repr

def baseErc20Operations : Array String := #[
  "erc20.total_supply",
  "erc20.balance_of",
  "erc20.transfer",
  "erc20.approve",
  "erc20.allowance",
  "erc20.transfer_from",
  "erc20.events"
]

def evmFeatureOperations (spec : TokenSpec) : Array String :=
  #[] ++
  (if spec.hasFeature .mintable then #["erc20.mint"] else #[]) ++
  (if spec.hasFeature .burnable then #["erc20.burn"] else #[]) ++
  (if spec.hasFeature .capped then #["erc20.cap"] else #[]) ++
  (if spec.hasFeature .pausable then #["erc20.pause"] else #[]) ++
  (if spec.hasFeature .permit then #["erc20.permit"] else #[])

def evmErc20Plan (target : TargetProfile) (spec : TokenSpec) : TokenPlan := {
  targetId := target.id
  standard := .erc20
  artifactKind := .evmErc20Contract
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .eventsEmit,
    .controlConditional,
    .assertions
  ]
  operations := baseErc20Operations ++ evmFeatureOperations spec
  notes := #[
    "EVM lowers a TokenSpec into a per-token ERC-20-compatible contract artifact.",
    "Deployment creates contract bytecode plus ABI/deploy metadata."
  ]
}

def baseSplTokenOperations : Array String := #[
  "spl-token.create_mint",
  "spl-token.create_token_account",
  "spl-token.mint_to",
  "spl-token.transfer_checked",
  "spl-token.approve",
  "spl-token.burn"
]

def token2022FeatureOperations (spec : TokenSpec) : Array String :=
  #[] ++
  (if spec.hasFeature .transferFee then #["token-2022.extension.transfer_fee"] else #[]) ++
  (if spec.hasFeature .nonTransferable then #["token-2022.extension.non_transferable"] else #[]) ++
  (if spec.hasFeature .confidentialTransfer then #["token-2022.extension.confidential_transfer"] else #[]) ++
  (if spec.hasFeature .transferHook then #["token-2022.extension.transfer_hook"] else #[])

def solanaTokenPlan (target : TargetProfile) (spec : TokenSpec) : TokenPlan :=
  let useToken2022 := spec.needsToken2022
  {
    targetId := target.id
    standard := if useToken2022 then .splToken2022 else .splToken
    artifactKind := if useToken2022 then .solanaToken2022Plan else .solanaSplTokenPlan
    capabilities := #[
      .accountExplicit,
      .crosscallCpi,
      .storagePda,
      .eventsEmit,
      .controlConditional,
      .assertions
    ]
    operations := baseSplTokenOperations ++ token2022FeatureOperations spec
    notes := #[
      "Solana lowers a TokenSpec into an SPL Token or Token-2022 mint/account/CPI plan.",
      "Standard Solana tokens use the deployed token program; ProofForge should not generate a per-token SPL contract by default.",
      "Custom token behavior should use Token-2022 extensions, transfer hooks, or a separate wrapper/authority program."
    ]
  }

def planForTarget (target : TargetProfile) (spec : TokenSpec) : Except String TokenPlan :=
  if target.family == .evm then
    .ok (evmErc20Plan target spec)
  else if target.family == .solana then
    .ok (solanaTokenPlan target spec)
  else
    .error s!"target `{target.id}` does not have a TokenSpec lowering plan yet"

end ProofForge.Contract.Token
