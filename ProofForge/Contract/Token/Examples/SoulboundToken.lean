import ProofForge.Contract.Token

namespace ProofForge.Contract.Token.Examples.SoulboundToken

open ProofForge.Contract.Token

def id : String :=
  "SoulboundToken"

def spec : TokenSpec := {
  name := "Soulbound Token"
  symbol := "SBT"
  decimals := 0
  initialSupply? := some 1
  features := #[.mintable, .burnable, .nonTransferable]
}

end ProofForge.Contract.Token.Examples.SoulboundToken
