/-
Chain-agnostic gap-analysis route steps 2–7 smoke:
Identity, sync-subset crosscall + Solana account inference, TokenAuth + FixedPoint,
upgrade lifecycle, PortableMechanics honesty.
-/
import ProofForge.Target.Identity
import ProofForge.Target.CrosscallMaterialize
import ProofForge.Target.PortableMechanics
import ProofForge.Target.HostRuntime
import ProofForge.Contract.Token
import ProofForge.Contract.TokenAuth
import ProofForge.Contract.FixedPoint
import ProofForge.Contract.UpgradePolicy
import ProofForge.Contract.UpgradePolicy.Lower
import ProofForge.IR.Contract

namespace ProofForge.Tests.ChainAgnosticRoute

open ProofForge.Target
open ProofForge.Target.Identity
open ProofForge.Target.CrosscallMaterialize
open ProofForge.Target.PortableMechanics
open ProofForge.Target.HostRuntime
open ProofForge.Contract.Token
open ProofForge.Contract.TokenAuth
open ProofForge.Contract.FixedPoint
open ProofForge.Contract
open ProofForge.Contract.UpgradePolicy
open ProofForge.IR

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

/-- Minimal portable module: one state scalar + empty entry (for account inference). -/
def sampleModule : Module := {
  name := "ChainAgnosticProbe"
  state := #[{ id := "vault", kind := .scalar, type := .u64 }]
  entrypoints := #[{ name := "touch", body := #[] }]
}

/-- Module that uses NEAR async escape hatch (must fail requireSyncSubset). -/
def nearAsyncModule : Module := {
  name := "NearAsyncEscape"
  state := #[]
  entrypoints := #[{
    name := "cb"
    body := #[.return (.nearPromiseResultsCount)]
  }]
}

def main : IO UInt32 := do
  ---------------------------------------------------------------------------
  -- Step 2: Identity
  ---------------------------------------------------------------------------
  require (encodingForTarget "evm" == .evmAddress20) "evm encoding"
  require (encodingForTarget "solana-sbpf-asm" == .solanaPubkey32) "sol encoding"
  require (encodingForTarget "wasm-near" == .nearAccountId) "near encoding"
  match materializeIdentity "evm" .caller with
  | .error msg => throw (IO.userError s!"evm caller: {msg}")
  | .ok m =>
      require (m.byteWidth? == some 20) "evm caller width 20"
      require (m.hostSymbol? == some "caller") "evm caller symbol"
  match materializeIdentity "solana-sbpf-asm" .caller with
  | .error msg => throw (IO.userError s!"sol caller: {msg}")
  | .ok m => require (m.byteWidth? == some 32) "sol caller width 32"
  match materializeIdentity "wasm-near" .caller with
  | .error msg => throw (IO.userError s!"near caller: {msg}")
  | .ok m =>
      require (m.byteWidth?.isNone) "near caller variable width"
      require (m.hostSymbol? == some "env.predecessor_account_id") "near caller host"
  match materializeIdentity "solana-sbpf-asm" .self with
  | .ok _ => throw (IO.userError "sol self must reject until program-id context lower")
  | .error msg =>
      require (contains msg "Identity") "sol self names Identity"
      require (contains msg "identity.self") "sol self names role"
  match materializeIdentity "wasm-near" .self with
  | .error msg => throw (IO.userError s!"near self: {msg}")
  | .ok m => require (m.hostSymbol? == some "env.current_account_id") "near self"
  match materializeIdentity "unknown-target" .caller with
  | .ok _ => throw (IO.userError "unknown target must reject")
  | .error msg => require (contains msg "Identity") "unknown names Identity"
  require (portableTypeName == "Address") "portable type Address"
  require (ValueType.address.name == "Address") "IR ValueType.address"

  ---------------------------------------------------------------------------
  -- Step 3: Sync-subset crosscall + Solana account inference
  ---------------------------------------------------------------------------
  require (portableCrosscallPolicy == .syncRequestResponseOnly) "policy locked"
  match requireSyncSubset sampleModule with
  | .error msg => throw (IO.userError s!"sample should pass sync subset: {msg}")
  | .ok () => pure ()
  match requireSyncSubset nearAsyncModule with
  | .ok () => throw (IO.userError "near async module must fail requireSyncSubset")
  | .error msg =>
      require (contains msg "CrosscallMaterialize") "async reject names module"
      require (contains msg "sync-subset" || contains msg "promise") "async reject mentions policy"
  match materializeSyncRemote "evm" sampleModule "0xpeer" with
  | .error msg => throw (IO.userError s!"evm sync remote: {msg}")
  | .ok m =>
      require (m.nativeForm == .evmCall) "evm form"
      require (m.inferredAccounts?.isNone) "evm no account metas"
  match materializeSyncRemote "solana-sbpf-asm" sampleModule
      "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" with
  | .error msg => throw (IO.userError s!"sol sync remote: {msg}")
  | .ok m =>
      require (m.nativeForm == .solanaCpi) "sol form"
      match m.inferredAccounts? with
      | none => throw (IO.userError "sol must infer accounts")
      | some accs =>
          require (accs.size >= 3) s!"sol inferred ≥3 accounts, got {accs.size}"
          require (accs.any (fun a => a.name == "payer" && a.signer)) "sol payer signer"
          require (accs.any (fun a => a.name == "vault")) "sol includes state vault"
          require (accs.any (fun a => a.name == "token_program"))
            "sol token program for SPL peer"
  match inferSolanaAccounts sampleModule "" with
  | .ok _ => throw (IO.userError "empty peer must fail inference")
  | .error msg =>
      require (contains msg "infer") "empty peer diagnostic"
      require (contains msg "peer") "empty peer names peer"
  match materializeSyncRemote "wasm-near" sampleModule "alice.near" with
  | .error msg => throw (IO.userError s!"near sync remote: {msg}")
  | .ok m =>
      require (m.nativeForm == .nearPromise) "near form"
      require (contains m.asyncSupport "promise") "near promise-create-only"
  match materializeSyncRemote "wasm-near" nearAsyncModule "alice.near" with
  | .ok _ => throw (IO.userError "near async module remote must reject")
  | .error msg => require (contains msg "CrosscallMaterialize") "near async remote reject"

  ---------------------------------------------------------------------------
  -- Step 4: Token core + auth features + FixedPoint
  ---------------------------------------------------------------------------
  -- transfer/balanceOf always full on TokenSpec lanes (no feature required).
  for tid in TokenAuth.primaryTokenTargetIds do
    require (coreOpSupportOnTarget tid .transfer #[] == .full)
      s!"transfer full on {tid}"
    require (coreOpSupportOnTarget tid .balanceOf #[] == .full)
      s!"balanceOf full on {tid}"
    -- mint/burn capability-gated: reject without mintable/burnable features.
    require (coreOpSupportOnTarget tid .mint #[] == .reject)
      s!"mint rejects without mintable on {tid}"
    require (coreOpSupportOnTarget tid .burn #[] == .reject)
      s!"burn rejects without burnable on {tid}"
    require (coreOpSupportOnTarget tid .mint #[.mintable] == .full)
      s!"mint full with mintable on {tid}"
    require (coreOpSupportOnTarget tid .burn #[.burnable] == .full)
      s!"burn full with burnable on {tid}"
    match materializeCoreOp tid .mint #[] with
    | .ok _ => throw (IO.userError s!"mint must reject without mintable on {tid}")
    | .error msg =>
        require (contains msg "TokenAuth") s!"mint reject names TokenAuth on {tid}"
        require (contains msg "mintable") s!"mint reject names mintable on {tid}"
    match materializeCoreOp tid .burn #[] with
    | .ok _ => throw (IO.userError s!"burn must reject without burnable on {tid}")
    | .error msg =>
        require (contains msg "TokenAuth") s!"burn reject names TokenAuth on {tid}"
        require (contains msg "burnable") s!"burn reject names burnable on {tid}"
    match materializeCoreOp tid .mint #[.mintable] with
    | .error msg => throw (IO.userError s!"mint+mintable on {tid}: {msg}")
    | .ok m => require (m.nativeOps.contains "mint") s!"mint op on {tid}"
  match materializeAuth "evm" .allowance with
  | .error msg => throw (IO.userError s!"evm allowance: {msg}")
  | .ok m => require (m.nativeOps.contains "approve") "evm approve"
  match materializeAuth "wasm-near" .allowance with
  | .ok _ => throw (IO.userError "NEAR must reject allowance (no ERC20 polyfill)")
  | .error msg =>
      require (contains msg "TokenAuth") "near allowance TokenAuth"
      require (contains msg "token.auth.allowance") "near allowance feature id"
  match materializeAuth "solana-sbpf-asm" .authority with
  | .error msg => throw (IO.userError s!"sol authority: {msg}")
  | .ok m =>
      require (m.nativeOps.any (fun s => contains s "authority" || contains s "delegate"))
        "sol authority ops"
  match materializeAuth "evm" .authority with
  | .ok _ => throw (IO.userError "EVM must reject SPL authority model")
  | .error msg => require (contains msg "TokenAuth") "evm authority reject"
  match materializeAuth "wasm-near" .storageDeposit with
  | .error msg => throw (IO.userError s!"near storage: {msg}")
  | .ok m => require (m.nativeOps.contains "storage_deposit") "near storage_deposit"
  match materializeAuth "wasm-near" .transferCall with
  | .error msg => throw (IO.userError s!"near transferCall: {msg}")
  | .ok _ => pure ()
  match materializeAuth "evm" .storageDeposit with
  | .ok _ => throw (IO.userError "EVM must reject storageDeposit")
  | .error msg => require (contains msg "TokenAuth") "evm storage reject"
  match validateDecimals 18 with
  | .error msg => throw (IO.userError msg)
  | .ok s =>
      require (s.factor == pow10 18) "scale18 factor"
      require (s.fromWhole 1 == pow10 18) "1 whole → 1e18"
      require (s.toWhole (pow10 18) == 1) "1e18 → 1 whole"
  match validateDecimals 19 with
  | .ok _ => throw (IO.userError "decimals>18 must reject")
  | .error msg => require (contains msg "FixedPoint") "decimals reject"
  require (rescale (pow10 6) scale6 scale18 == pow10 18) "rescale 6→18"
  require (mulScaled scale6 (pow10 6) (2 * pow10 6) == 2 * pow10 6)
    "mulScaled 1.0 * 2.0 @6dp = 2.0"
  match divScaled? scale6 (pow10 6) (2 * pow10 6) with
  | none => throw (IO.userError "divScaled should succeed")
  | some q => require (q == pow10 6 / 2) "divScaled 1/2 @6dp"
  match divScaled? scale6 1 0 with
  | some _ => throw (IO.userError "div by zero must be none")
  | none => pure ()

  ---------------------------------------------------------------------------
  -- Step 5: Upgrade / lifecycle
  ---------------------------------------------------------------------------
  match materializeUpgrade "evm" .immutable none with
  | .error msg => throw (IO.userError s!"evm immutable: {msg}")
  | .ok m => require (m.shape == .immutableDeploy) "evm immutable shape"
  match materializeUpgrade "evm" (.authority "deployer") (some .uups) with
  | .error msg => throw (IO.userError s!"evm uups: {msg}")
  | .ok m =>
      require (m.shape == .evmProxy) "evm proxy shape"
      require (contains m.note "uups") "evm uups note"
  match materializeUpgrade "evm" (.authority "deployer") (some .transparent) with
  | .ok _ => throw (IO.userError "evm transparent must honest-reject (no Plan lower)")
  | .error msg =>
      require (contains msg "transparent" || contains msg "uups" || contains msg "UpgradePolicy")
        "evm transparent reject names pattern"
  match materializeUpgrade "evm" (.authority "deployer") none with
  | .ok _ => throw (IO.userError "evm authority without proxy must reject")
  | .error msg =>
      require (contains msg "proxy" || contains msg "EVM" || contains msg "uups")
        "evm no-proxy reject"
  match materializeUpgrade "solana-sbpf-asm" (.authority "upgrade_auth") none with
  | .error msg => throw (IO.userError s!"sol authority: {msg}")
  | .ok m => require (m.shape == .solanaUpgradeAuthority) "sol upgrade authority"
  match materializeUpgrade "wasm-near" (.authority "owner") none with
  | .error msg => throw (IO.userError s!"near authority: {msg}")
  | .ok m => require (m.shape == .nearRedeployMigrate) "near redeploy+migrate"
  match materializeUpgrade "evm" (.governance "dao") none with
  | .ok _ => throw (IO.userError "evm governance must reject")
  | .error msg =>
      require (contains msg "governance" || contains msg "UpgradePolicy" || contains msg "EVM")
        "evm governance reject"

  ---------------------------------------------------------------------------
  -- Step 6–7: PortableMechanics + HostEnv still honest
  ---------------------------------------------------------------------------
  let triad := HostRuntime.primaryTargetIds
  for tid in triad do
    match materializeMechanic tid .cryptoSha256 with
    | .error msg => throw (IO.userError s!"sha256 must materialize on {tid}: {msg}")
    | .ok m => require (!isNaSymbol m.binding.symbol) s!"sha256@{tid}"
  match materializeMechanic "evm" .cryptoEcrecover with
  | .error msg => throw (IO.userError s!"evm ecrecover: {msg}")
  | .ok m => require (m.binding.symbol == "ecrecover") "ecrecover symbol"
  match materializeMechanic "wasm-near" .cryptoEcrecover with
  | .ok _ => throw (IO.userError "NEAR ecrecover must reject")
  | .error msg =>
      require (contains msg "PortableMechanics") "near ecrecover names mechanics"
      require (contains msg "mech.crypto.ecrecover") "near ecrecover term id"
  match materializeMechanic "evm" .serdeAbi with
  | .error msg => throw (IO.userError s!"evm abi: {msg}")
  | .ok _ => pure ()
  match materializeMechanic "solana-sbpf-asm" .serdeAbi with
  | .ok _ => throw (IO.userError "solana abi must reject")
  | .error msg => require (contains msg "PortableMechanics") "sol abi reject"
  match materializeMechanic "solana-sbpf-asm" .serdeBorsh with
  | .error msg => throw (IO.userError s!"sol borsh: {msg}")
  | .ok _ => pure ()
  match materializeMechanic "wasm-near" .serdeJson with
  | .error msg => throw (IO.userError s!"near json: {msg}")
  | .ok _ => pure ()
  for tid in triad do
    match materializeMechanic tid .errorCode with
    | .error msg => throw (IO.userError s!"errorCode on {tid}: {msg}")
    | .ok _ => pure ()
  -- HostEnv honesty still holds (chainId not aliased)
  match materializeEnv "wasm-near" .chainId with
  | .ok _ => throw (IO.userError "NEAR chainId must still reject")
  | .error msg => require (contains msg "HostEnv") "hostenv chainId"

  IO.println "chain-agnostic-route: ok (identity+sync-crosscall+token-auth+fixedpoint+upgrade+mechanics)"
  pure 0

end ProofForge.Tests.ChainAgnosticRoute

def main : IO UInt32 :=
  ProofForge.Tests.ChainAgnosticRoute.main
