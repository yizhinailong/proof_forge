import ProofForge.Contract.UpgradePolicy

namespace ProofForge.Contract.UpgradePolicy

/-- Reject unsupported (target, policy) combinations with a clear diagnostic. -/
def checkSupported (targetId : String) (policy : UpgradePolicy) : Except String Unit :=
  match targetId, policy with
  | "evm", .authority _ =>
      .error "EVM target does not support `authority` upgrade policy in v0; use `immutable` or implement a documented proxy pattern"
  | "evm", .governance _ =>
      .error "EVM target does not support `governance` upgrade policy in v0"
  | "solana-sbpf-asm", .governance _ =>
      .error "Solana target does not support `governance` upgrade policy in v0"
  | "wasm-near", .governance _ =>
      .error "NEAR target does not support `governance` upgrade policy in v0"
  | "aleo-leo", .authority _ =>
      .error "Aleo target only supports `immutable` upgrade policy"
  | "aleo-leo", .governance _ =>
      .error "Aleo target only supports `immutable` upgrade policy"
  | "psy-dpn", .authority _ =>
      .error "Psy DPN target only supports `immutable` upgrade policy"
  | "psy-dpn", .governance _ =>
      .error "Psy DPN target only supports `immutable` upgrade policy"
  | _, _ => .ok ()

end ProofForge.Contract.UpgradePolicy
