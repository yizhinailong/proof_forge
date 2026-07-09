/-
Layer B Protocols smoke: catalog + EVM IERC20/721 examples + NEAR FT peer
example + Solana facade inventory.
-/
import ProofForge.Protocols
import ProofForge.Backend.Evm.IR
import ProofForge.Backend.WasmHost.EmitWat
import ProofForge.Contract.Builder
import Examples.Backend.Evm.Contracts.Ierc20Client
import Examples.Backend.Evm.Contracts.Ierc721Client
import Examples.Backend.WasmNear.FtPeerClient

namespace ProofForge.Tests.ProtocolsLayer

open ProofForge.Contract.Builder

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def main : IO UInt32 := do
  require (ProofForge.Protocols.layerId == "protocols") "layer id"
  require (ProofForge.Protocols.primaryHosts.contains "evm") "hosts include evm"
  require (ProofForge.Protocols.Solana.catalogId == "protocols.solana") "solana catalog"
  require (ProofForge.Protocols.Solana.knownFamilies.contains "spl-token") "spl-token family"
  require (ProofForge.Protocols.Solana.knownFamilies.contains "token-2022") "token-2022 family"
  require (ProofForge.Protocols.Solana.supportedDataLayouts.contains "spl-token.initialize_account3")
    "inventory lists initialize_account3"
  require (ProofForge.Protocols.Solana.supportedDataLayouts.contains "token-2022.pause")
    "inventory lists token-2022.pause"
  require (ProofForge.Protocols.Solana.rejectedLayoutExamples.any (·.contains "confidential"))
    "inventory documents confidential reject"
  require (ProofForge.Protocols.Evm.IERC20.catalogId == "protocols.evm.ierc20") "ierc20 catalog"
  require (ProofForge.Protocols.Evm.IERC721.catalogId == "protocols.evm.ierc721") "ierc721 catalog"
  require (ProofForge.Protocols.Evm.IERC20.selectorTransfer == 0xa9059cbb) "transfer selector"
  require (ProofForge.Protocols.Evm.IERC721.selectorOwnerOf == 0x6352211e) "ownerOf selector"
  require (ProofForge.Protocols.Evm.IERC721.selectorSafeTransferFrom == 0x42842e0e)
    "safeTransferFrom selector"
  require (ProofForge.Protocols.Near.FungibleToken.methodFtTransfer == "ft_transfer")
    "ft_transfer method name"
  require (ProofForge.Protocols.Near.FungibleToken.methodStorageDeposit == "storage_deposit")
    "storage_deposit method name"
  let _ := ProofForge.Protocols.Solana.splTokenInitializeAccount3Call
    "init" "acct" "mint" "owner"
  let _ := ProofForge.Protocols.Solana.splToken2022PauseCall "pause" "mint" "authority"

  -- EVM IERC20 example
  let ierc20 := Examples.Backend.Evm.Contracts.Ierc20Client.module
  require (ierc20.entrypoints.any (·.name == "pushTokens")) "Ierc20Client has pushTokens"
  require (ierc20.nearCrosscallStrings.any (· == "token.peer")) "Ierc20Client registers token.peer"
  match ProofForge.Backend.Evm.IR.renderModule ierc20 with
  | .error e => throw (IO.userError s!"EVM Ierc20Client render failed: {e.message}")
  | .ok yul =>
      let transferSel := toString ProofForge.Protocols.Evm.IERC20.selectorTransfer
      require (
          contains yul transferSel || contains yul "2835717307" ||
          contains yul "a9059cbb" || contains yul "0xa9059cbb"
        ) "Yul missing IERC20.transfer selector"
      require (
          contains yul (toString ProofForge.Protocols.Evm.IERC20.selectorBalanceOf) ||
          contains yul "70a08231"
        ) "Yul missing IERC20.balanceOf selector"
      require (
          contains yul (toString ProofForge.Protocols.Evm.IERC20.selectorTotalSupply) ||
          contains yul "18160ddd"
        ) "Yul missing IERC20.totalSupply selector"
      require (contains yul "crosscall" || contains yul "__proof_forge_crosscall")
        "Yul missing crosscall helper for IERC20 client"

  -- EVM IERC721 example
  let ierc721 := Examples.Backend.Evm.Contracts.Ierc721Client.module
  require (ierc721.entrypoints.any (·.name == "moveToken")) "Ierc721Client has moveToken"
  require (ierc721.nearCrosscallStrings.any (· == "nft.peer")) "Ierc721Client registers nft.peer"
  match ProofForge.Backend.Evm.IR.renderModule ierc721 with
  | .error e => throw (IO.userError s!"EVM Ierc721Client render failed: {e.message}")
  | .ok yul =>
      require (
          contains yul (toString ProofForge.Protocols.Evm.IERC721.selectorTransferFrom) ||
          contains yul "23b872dd"
        ) "Yul missing IERC721.transferFrom selector"
      require (
          contains yul (toString ProofForge.Protocols.Evm.IERC721.selectorSafeTransferFrom) ||
          contains yul "42842e0e"
        ) "Yul missing IERC721.safeTransferFrom selector"
      require (
          contains yul (toString ProofForge.Protocols.Evm.IERC721.selectorOwnerOf) ||
          contains yul "6352211e"
        ) "Yul missing IERC721.ownerOf selector"
      require (contains yul "crosscall" || contains yul "__proof_forge_crosscall")
        "Yul missing crosscall helper for IERC721 client"

  -- NEAR FT peer example
  let nearFt := Examples.Backend.WasmNear.FtPeerClient.module
  require (nearFt.entrypoints.any (·.name == "pay")) "FtPeerClient has pay"
  require (nearFt.entrypoints.any (·.name == "pay_with_callback")) "FtPeerClient has pay_with_callback"
  require (nearFt.nearCrosscallStrings.any (· == "my_ft")) "FtPeerClient registers my_ft peer"
  require (nearFt.nearCrosscallStrings.any (· == "ft_transfer")) "FtPeerClient registers ft_transfer"
  require (nearFt.nearCrosscallStrings.any (· == "ft_transfer_call"))
    "FtPeerClient registers ft_transfer_call"
  require (nearFt.nearCrosscallStrings.any (· == "ft_balance_of"))
    "FtPeerClient registers ft_balance_of"
  require (nearFt.nearCrosscallStrings.any (· == "ft_total_supply"))
    "FtPeerClient registers ft_total_supply"
  match ProofForge.Backend.WasmHost.EmitWat.renderModule nearFt with
  | .error e => throw (IO.userError s!"NEAR FtPeerClient render failed: {e.message}")
  | .ok wat =>
      require (contains wat "promise_create") "FtPeerClient WAT missing promise_create"
      require (contains wat "ft_transfer" || contains wat "my_ft")
        "FtPeerClient WAT should embed FT peer/method pool data"

  IO.println "protocols-layer: ok (solana inventory · evm ierc20/721 · near ft peer)"
  pure 0

end ProofForge.Tests.ProtocolsLayer

def main : IO UInt32 :=
  ProofForge.Tests.ProtocolsLayer.main
