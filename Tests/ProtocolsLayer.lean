/-
Layer B Protocols smoke: catalog surface + EVM IERC20 example Yul +
NEAR FT method registration + Solana facade export.
-/
import ProofForge.Protocols
import ProofForge.Backend.Evm.IR
import ProofForge.Contract.Builder
import Examples.Backend.Evm.Contracts.Ierc20Client

namespace ProofForge.Tests.ProtocolsLayer

open ProofForge.Contract.Builder
open ProofForge.Protocols.Evm.IERC20
open ProofForge.Protocols.Near.FungibleToken

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

/-- NEAR FT peer method registration (string pool). -/
def nearFtClientSpec : ProofForge.Contract.ContractSpec :=
  build "ProtocolsNearFtClient" do
    scalarState "nonce" .u64
    let ft ← declareFtTransfer "my_ft"
    entry "pay" do
      letBind "_p" .u64 (call ft #[u64 50])
      effect (storageScalarWrite "nonce" (u64 1))

def main : IO UInt32 := do
  require (ProofForge.Protocols.layerId == "protocols") "layer id"
  require (ProofForge.Protocols.primaryHosts.contains "evm") "hosts include evm"
  require (ProofForge.Protocols.Solana.catalogId == "protocols.solana") "solana catalog"
  require (ProofForge.Protocols.Solana.knownFamilies.contains "spl-token") "spl-token family"
  require (ProofForge.Protocols.Evm.IERC20.catalogId == "protocols.evm.ierc20") "ierc20 catalog"
  require (ProofForge.Protocols.Evm.IERC20.selectorTransfer == 0xa9059cbb) "transfer selector"
  require (ProofForge.Protocols.Near.FungibleToken.methodFtTransfer == "ft_transfer")
    "ft_transfer method name"
  -- Solana facade re-exports a real builder symbol.
  let _ := ProofForge.Protocols.Solana.splTokenInitializeAccount3Call
    "init" "acct" "mint" "owner"

  -- Layer B example: IERC20 transfer / balanceOf / totalSupply → EVM Yul.
  let ierc20 := Examples.Backend.Evm.Contracts.Ierc20Client.module
  require (ierc20.entrypoints.any (·.name == "pushTokens")) "Ierc20Client has pushTokens"
  require (ierc20.entrypoints.any (·.name == "readBalance")) "Ierc20Client has readBalance"
  require (ierc20.nearCrosscallStrings.any (· == "token.peer"))
    "Ierc20Client registers token.peer"
  match ProofForge.Backend.Evm.IR.renderModule ierc20 with
  | .error e => throw (IO.userError s!"EVM Ierc20Client render failed: {e.message}")
  | .ok yul =>
      let transferSel := toString selectorTransfer
      let balanceSel := toString selectorBalanceOf
      let supplySel := toString selectorTotalSupply
      require (
          contains yul transferSel || contains yul "2835717307" ||
          contains yul "a9059cbb" || contains yul "0xa9059cbb"
        ) "Yul missing IERC20.transfer selector 0xa9059cbb"
      require (
          contains yul balanceSel || contains yul "70a08231" ||
          contains yul "0x70a08231"
        ) "Yul missing IERC20.balanceOf selector 0x70a08231"
      require (
          contains yul supplySel || contains yul "18160ddd" ||
          contains yul "0x18160ddd"
        ) "Yul missing IERC20.totalSupply selector 0x18160ddd"
      require (contains yul "crosscall" || contains yul "__proof_forge_crosscall")
        "Yul missing crosscall helper for IERC20 client"
      require (contains yul "case 0xa1b2c3d4" || contains yul "a1b2c3d4")
        "Yul missing pushTokens entry selector"

  require (nearFtClientSpec.module.nearCrosscallStrings.any (· == "my_ft"))
    "NEAR FT client registers peer id"
  require (nearFtClientSpec.module.nearCrosscallStrings.any (· == "ft_transfer"))
    "NEAR FT client registers ft_transfer method"

  IO.println "protocols-layer: ok (solana facade · evm ierc20 example · near ft)"
  pure 0

end ProofForge.Tests.ProtocolsLayer

def main : IO UInt32 :=
  ProofForge.Tests.ProtocolsLayer.main
