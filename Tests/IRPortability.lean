/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

D-050 IR portability smoke: Counter is portable-core; Move object ownership is
flagged as Move-family-only; EVM rejects non-contract storage owners.
-/
import ProofForge.IR.Portability
import ProofForge.IR.Examples.Counter
import ProofForge.Backend.Move.Sui
import ProofForge.Backend.Move.Aptos
import ProofForge.Backend.Evm.Validate
import ProofForge.Target.Registry

open ProofForge.IR
open ProofForge.IR.Portability
open ProofForge.Target

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def counterModule : Module := ProofForge.IR.Examples.Counter.module

def objectCounterModule : Module := {
  counterModule with
  state := #[{ id := "count", kind := .scalar, type := .u64, owner := .object }]
}

def resourceCounterModule : Module := {
  counterModule with
  state := #[{ id := "count", kind := .scalar, type := .u64, owner := .resource }]
}

def main : IO Unit := do
  -- Shared Counter fixture stays portable across primary targets.
  require (isPortableCoreModule counterModule)
    "Counter module must classify as portable-core (+ neutral selector metadata)"
  require (familyOnlyViolations counterModule .evm).isEmpty
    "Counter must not carry non-EVM family-only constructors"
  require (familyOnlyViolations counterModule .solana).isEmpty
    "Counter must not carry non-Solana family-only constructors"
  require (familyOnlyViolations counterModule .wasmHost).isEmpty
    "Counter must not carry non-Wasm family-only constructors"

  -- Explicit Sui object ownership is Move-family-only.
  let objectFindings := classifyModule objectCounterModule
  require (objectFindings.any fun f =>
      match f.class_ with
      | .targetFamilyOnly .move => true
      | _ => false)
    "StorageOwner.object must classify as move target-family-only"
  require (!(isPortableCoreModule objectCounterModule))
    "object-owned Counter is not a portable-core module"
  require ((familyOnlyViolations objectCounterModule .evm).size > 0)
    "object ownership must violate EVM family lowering"
  require (familyOnlyViolations objectCounterModule .move).isEmpty
    "object ownership must be legal for Move family"

  -- Sui accepts object owner and portable contract owner; rejects resource.
  match ProofForge.Backend.Move.Sui.requireScalarState objectCounterModule with
  | .ok "count" => pure ()
  | .ok other => throw (IO.userError s!"Sui object owner unexpected field `{other}`")
  | .error e => throw (IO.userError s!"Sui should accept object owner: {e.message}")
  match ProofForge.Backend.Move.Sui.requireScalarState counterModule with
  | .ok "count" => pure ()
  | .ok other => throw (IO.userError s!"Sui portable owner unexpected field `{other}`")
  | .error e => throw (IO.userError s!"Sui should accept portable contract owner: {e.message}")
  match ProofForge.Backend.Move.Sui.requireScalarState resourceCounterModule with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Sui must reject StorageOwner.resource")

  -- Aptos accepts resource owner and portable contract owner; rejects object.
  match ProofForge.Backend.Move.Aptos.requireScalarState resourceCounterModule with
  | .ok "count" => pure ()
  | .ok other => throw (IO.userError s!"Aptos resource owner unexpected field `{other}`")
  | .error e => throw (IO.userError s!"Aptos should accept resource owner: {e.message}")
  match ProofForge.Backend.Move.Aptos.requireScalarState objectCounterModule with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Aptos must reject StorageOwner.object")

  -- EVM validate rejects Move ownership models.
  match ProofForge.Backend.Evm.Validate.validateState objectCounterModule with
  | .error e =>
      require (e.message.contains "StorageOwner.object")
        s!"EVM object rejection message unexpected: {e.message}"
  | .ok _ => throw (IO.userError "EVM must reject StorageOwner.object")
  match ProofForge.Backend.Evm.Validate.validateState resourceCounterModule with
  | .error e =>
      require (e.message.contains "StorageOwner.resource")
        s!"EVM resource rejection message unexpected: {e.message}"
  | .ok _ => throw (IO.userError "EVM must reject StorageOwner.resource")
  match ProofForge.Backend.Evm.Validate.validateState counterModule with
  | .ok _ => pure ()
  | .error e => throw (IO.userError s!"EVM must accept portable Counter: {e.message}")

  -- Capability emission for explicit owners.
  require (objectCounterModule.capabilities.any (· == .storageObject))
    "object owner must declare storage.object capability"
  require (resourceCounterModule.capabilities.any (· == .storageResource))
    "resource owner must declare storage.resource capability"
  require (moveSui.capabilities.contains .storageObject)
    "move-sui profile must advertise storage.object"
  require (moveAptos.capabilities.contains .storageResource)
    "move-aptos profile must advertise storage.resource"

  IO.println "ir-portability: ok"
