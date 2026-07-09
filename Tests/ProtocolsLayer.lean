/-
Layer B Protocols smoke: catalog surface + EVM IERC20 selector packing +
NEAR FT method registration + Solana facade export.
-/
import ProofForge.Protocols
import ProofForge.Backend.Evm.IR
import ProofForge.Contract.Builder
import ProofForge.Contract.Surface

namespace ProofForge.Tests.ProtocolsLayer

open ProofForge.Contract.Builder
open ProofForge.Protocols.Evm.IERC20
open ProofForge.Protocols.Near.FungibleToken

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

/-- Minimal contract that CALLs an external IERC20.transfer. -/
def ierc20ClientSpec : ProofForge.Contract.ContractSpec :=
  build "ProtocolsIerc20Client" do
    scalarState "nonce" .u64
    let token ← declareToken "token.peer"
    entrySelector "pull" "01" do
      letBind "_ok" .u64 (transfer token (u64 1) (u64 100))
      effect (storageScalarWrite "nonce" (u64 1))

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

  match ProofForge.Backend.Evm.IR.renderModule {
    ierc20ClientSpec.module with
    entrypoints := ierc20ClientSpec.module.entrypoints.map fun ep =>
      if ep.name == "pull" then { ep with selector? := some "01000000" } else ep
  } with
  | .error e => throw (IO.userError s!"EVM IERC20 client render failed: {e.message}")
  | .ok yul =>
      -- Selector is packed via shl(224, selector); accept hex or decimal form.
      let selDec := toString selectorTransfer
      require (
          contains yul selDec ||
          contains yul "2835717307" ||
          contains yul "0xa9059cbb" ||
          contains yul "a9059cbb"
        ) s!"Yul missing IERC20 transfer selector (got fragment without {selDec})"
      require (contains yul "crosscall" || contains yul "__proof_forge_crosscall")
        "Yul missing crosscall helper for IERC20 transfer"
      require (contains yul "100")
        "Yul missing transfer amount arg"

  require (nearFtClientSpec.module.nearCrosscallStrings.any (· == "my_ft"))
    "NEAR FT client registers peer id"
  require (nearFtClientSpec.module.nearCrosscallStrings.any (· == "ft_transfer"))
    "NEAR FT client registers ft_transfer method"

  IO.println "protocols-layer: ok (solana facade · evm ierc20 · near ft)"
  pure 0

end ProofForge.Tests.ProtocolsLayer

def main : IO UInt32 :=
  ProofForge.Tests.ProtocolsLayer.main
