/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

D-050: portable IR stays chain-neutral; `--target` selects storage binding.
-/
import ProofForge.IR.Portability
import ProofForge.IR.Examples.Counter
import ProofForge.Backend.Move.Sui
import ProofForge.Backend.Move.Aptos
import ProofForge.Backend.Evm.Validate
import ProofForge.Target.Registry
import ProofForge.Target.StorageBinding

open ProofForge.IR
open ProofForge.IR.Portability
open ProofForge.Target

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def counterModule : Module := ProofForge.IR.Examples.Counter.module

def main : IO Unit := do
  -- Same portable Counter IR for every primary target.
  require (isPortableCoreModule counterModule)
    "Counter module must classify as portable-core (+ neutral selector metadata)"
  require (familyOnlyViolations counterModule .evm).isEmpty
    "Counter must not carry non-EVM family-only constructors"
  require (familyOnlyViolations counterModule .solana).isEmpty
    "Counter must not carry non-Solana family-only constructors"
  require (familyOnlyViolations counterModule .wasmHost).isEmpty
    "Counter must not carry non-Wasm family-only constructors"
  require (familyOnlyViolations counterModule .move).isEmpty
    "Counter must not carry non-Move family-only constructors"

  -- Target (not author) chooses native storage binding.
  require (evm.storageBinding == .contractGlobal)
    "evm must bind portable state as contract-global storage"
  require (solanaSbpfAsm.storageBinding == .accountData)
    "solana-sbpf-asm must bind portable state as account data"
  require (wasmNear.storageBinding == .hostKeyValue)
    "wasm-near must bind portable state as host key/value"
  require (moveAptos.storageBinding == .moveResource)
    "move-aptos must bind portable state as Move resource"
  require (moveSui.storageBinding == .moveObject)
    "move-sui must bind portable state as Move object"
  require ((storageBindingForTargetId? "move-sui") == some .moveObject)
    "storageBindingForTargetId? must resolve move-sui"

  -- Same IR accepted by EVM, Sui, and Aptos adapters (target maps binding).
  match ProofForge.Backend.Evm.Validate.validateState counterModule with
  | .ok _ => pure ()
  | .error e => throw (IO.userError s!"EVM must accept portable Counter: {e.message}")
  match ProofForge.Backend.Move.Sui.requireScalarState counterModule with
  | .ok "count" => pure ()
  | .ok other => throw (IO.userError s!"Sui unexpected field `{other}`")
  | .error e => throw (IO.userError s!"Sui must accept portable Counter: {e.message}")
  match ProofForge.Backend.Move.Aptos.requireScalarState counterModule with
  | .ok "count" => pure ()
  | .ok other => throw (IO.userError s!"Aptos unexpected field `{other}`")
  | .error e => throw (IO.userError s!"Aptos must accept portable Counter: {e.message}")

  -- Portable scalar state declares only storage.scalar — never chain-native caps.
  require (counterModule.capabilities.all fun c =>
      !(c == .storagePda))
    "portable Counter must not require Solana-only storage.pda"
  require (!(counterModule.capabilities.any fun c => c.id == "storage.resource"))
    "portable IR must not emit storage.resource"
  require (!(counterModule.capabilities.any fun c => c.id == "storage.object"))
    "portable IR must not emit storage.object"

  IO.println "ir-portability: ok"
