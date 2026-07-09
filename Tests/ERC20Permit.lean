/-
ERC20Permit Layer C + crypto.ecrecover capability honesty.
-/
import ProofForge.Contract.Stdlib.ERC20Permit
import ProofForge.Backend.Evm.Plan
import ProofForge.Target
import ProofForge.IR.Contract

namespace ProofForge.Tests.ERC20Permit

open ProofForge.Target

def require (c : Bool) (m : String) : IO Unit :=
  if c then pure () else throw (IO.userError m)

def main : IO UInt32 := do
  let m := ProofForge.Contract.Stdlib.ERC20Permit.module
  require (m.entrypoints.any (·.name == "permit")) "has permit"
  require (m.entrypoints.any (·.name == "nonces")) "has nonces"
  require (m.entrypoints.any (·.name == "DOMAIN_SEPARATOR")) "has DOMAIN_SEPARATOR"
  require (m.entrypoints.any (·.name == "setPermitSig")) "has setPermitSig"
  require (m.state.any (fun s => s.id == "nonces")) "nonces map"
  require (m.state.any (fun s => s.id == "domainSeparator")) "domain sep"

  -- Module capabilities must include crypto.ecrecover
  let caps := m.capabilities
  require (caps.any (· == .cryptoEcrecover)) s!"expected cryptoEcrecover in {caps.map (·.id)}"

  -- EVM resolves; NEAR does not advertise crypto.ecrecover
  require (evm.capabilities.any (· == .cryptoEcrecover)) "evm has crypto.ecrecover"
  require (!(wasmNear.capabilities.any (· == .cryptoEcrecover))) "near lacks crypto.ecrecover"

  match ProofForge.Backend.Evm.Plan.buildModulePlan m with
  | .error e => throw (IO.userError s!"EVM plan: {e.message}")
  | .ok _ => pure ()

  IO.println "erc20-permit: ok"
  pure 0

end ProofForge.Tests.ERC20Permit

def main : IO UInt32 :=
  ProofForge.Tests.ERC20Permit.main
