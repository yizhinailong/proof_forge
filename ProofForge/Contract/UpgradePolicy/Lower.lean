import ProofForge.Contract.UpgradePolicy

namespace ProofForge.Contract.UpgradePolicy

/-- Reject unsupported (target, policy, proxy) combinations with a clear diagnostic. -/
def checkSupported (targetId : String) (policy : UpgradePolicy) (proxyPattern? : Option ProxyPattern) :
    Except String Unit :=
  match targetId, policy, proxyPattern? with
  | "evm", .authority _, some .uups => .ok ()
  -- Transparent proxy is declared in ProxyPattern but EVM Plan only lowers
  -- `proxyPattern?=uups` → uupsProxy; transparent yields revert-not-proxy.
  -- Honest reject until a real transparent dispatch exists.
  | "evm", .authority _, some .transparent =>
      .error
        "EVM target does not materialize `transparent` proxy yet (Plan only wires uups); \
use `proxy_pattern uups` or `immutable`"
  | "evm", .authority _, _ =>
      .error "EVM target does not support `authority` upgrade policy without a documented proxy pattern; declare `proxy_pattern uups` or use `immutable`"
  | "evm", .governance _, _ =>
      .error "EVM target does not support `governance` upgrade policy in v0"
  | "solana-sbpf-asm", .governance _, _ =>
      .error "Solana target does not support `governance` upgrade policy in v0"
  | "wasm-near", .governance _, _ =>
      .error "NEAR target does not support `governance` upgrade policy in v0"
  | "aleo-leo", .authority _, _ =>
      .error "Aleo target only supports `immutable` upgrade policy"
  | "aleo-leo", .governance _, _ =>
      .error "Aleo target only supports `immutable` upgrade policy"
  | "psy-dpn", .authority _, _ =>
      .error "Psy DPN target only supports `immutable` upgrade policy"
  | "psy-dpn", .governance _, _ =>
      .error "Psy DPN target only supports `immutable` upgrade policy"
  | _, _, _ => .ok ()

/-! ### Portable upgrade / lifecycle materialize (gap-analysis route step 5)

Chains implement upgrade differently; portable authors declare **intent**
(`immutable` / `authority` / `governance`) and optional EVM `ProxyPattern`.
-/

/-- Native lifecycle shape on a target. -/
inductive LifecycleShape where
  | immutableDeploy
  | evmProxy
  | solanaUpgradeAuthority
  | nearRedeployMigrate
  deriving BEq, DecidableEq, Repr

def LifecycleShape.id : LifecycleShape → String
  | .immutableDeploy => "lifecycle.immutable-deploy"
  | .evmProxy => "lifecycle.evm-proxy"
  | .solanaUpgradeAuthority => "lifecycle.solana-upgrade-authority"
  | .nearRedeployMigrate => "lifecycle.near-redeploy-migrate"

structure UpgradeMaterialization where
  targetId : String
  policyKind : String
  shape : LifecycleShape
  note : String
  deriving Repr, BEq

def upgradeReject (targetId : String) (reason : String) : String :=
  s!"UpgradePolicy: target `{targetId}` cannot materialize upgrade intent: {reason}"

/-- Materialize upgrade/lifecycle intent for primary triad (or honest-reject). -/
def materializeUpgrade (targetId : String) (policy : UpgradePolicy)
    (proxyPattern? : Option ProxyPattern) : Except String UpgradeMaterialization := do
  checkSupported targetId policy proxyPattern?
  match targetId, policy with
  | "evm", .immutable =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .immutableDeploy
        note := "deploy runtime bytecode; no proxy"
      }
  | "evm", .authority _ =>
      -- Only UUPS has a real EVM lower path today.
      match proxyPattern? with
      | some .uups =>
          .ok {
            targetId := targetId
            policyKind := policy.kind
            shape := .evmProxy
            note := "EVM proxy pattern `uups` + upgrade authority"
          }
      | some .transparent =>
          .error (upgradeReject targetId
            "transparent proxy not lowered (Plan maps only uups → uupsProxy); use uups")
      | none =>
          .error (upgradeReject targetId
            "authority requires proxy_pattern uups (no silent default to a missing lower)")
  | "solana-sbpf-asm", .immutable =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .immutableDeploy
        note := "program deploy with no upgrade authority (or revoked)"
      }
  | "solana-sbpf-asm", .authority _ =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .solanaUpgradeAuthority
        note := "BPF loader upgrade authority; not EVM proxy"
      }
  | "wasm-near", .immutable =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .immutableDeploy
        note := "deploy once; no code replace"
      }
  | "wasm-near", .authority _ =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .nearRedeployMigrate
        note := "NEAR redeploy code + state migrate method (not proxy delegatecall)"
      }
  | "evm", .governance _ | "solana-sbpf-asm", .governance _ | "wasm-near", .governance _ =>
      .error (upgradeReject targetId "governance upgrade not materialized in v0")
  -- Research / experimental targets: immutable-only deploy is honest; authority
  -- and governance are already rejected by checkSupported.
  | "psy-dpn", .immutable
  | "aleo-leo", .immutable =>
      .ok {
        targetId := targetId
        policyKind := policy.kind
        shape := .immutableDeploy
        note := "experimental target: immutable deploy only"
      }
  | _, _ =>
      .error (upgradeReject targetId s!"no lifecycle row for policy `{policy.kind}`")

def primaryTargetIds : Array String := #["evm", "solana-sbpf-asm", "wasm-near"]

end ProofForge.Contract.UpgradePolicy
