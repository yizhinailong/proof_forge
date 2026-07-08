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

  -- Slice 2: Context field portability split. Portable env fields
  -- (timestamp/chainId/epochHeight/checkpointId/userId/userIdHash/contractId)
  -- are family-shared; EVM-only fields (baseFee/prevRandao/coinbase/origin/
  -- gasPrice/gasLeft/randomSeed/blockHash) classify as EVM target-family-only.
  require ContextField.timestamp.isPortableEnv "timestamp must be portable env"
  require ContextField.chainId.isPortableEnv "chainId must be portable env"
  require ContextField.epochHeight.isPortableEnv "epochHeight must be portable env"
  require ContextField.checkpointId.isPortableEnv "checkpointId must be portable env"
  require ContextField.userId.isPortableEnv "userId must be portable env"
  require ContextField.contractId.isPortableEnv "contractId must be portable env"
  require (!ContextField.baseFee.isPortableEnv) "baseFee must be EVM-only"
  require (!ContextField.prevRandao.isPortableEnv) "prevRandao must be EVM-only"
  require (!ContextField.coinbase.isPortableEnv) "coinbase must be EVM-only"
  require (!ContextField.origin.isPortableEnv) "origin must be EVM-only"
  require (!ContextField.gasPrice.isPortableEnv) "gasPrice must be EVM-only"
  require (!ContextField.gasLeft.isPortableEnv) "gasLeft must be EVM-only"
  require (!ContextField.randomSeed.isPortableEnv) "randomSeed must be EVM-only"
  require (!(ContextField.isPortableEnv (ContextField.blockHash (Expr.literal (.u64 0))))) "blockHash must be EVM-only"

  -- A module reading a portable env field stays portable-core; reading an
  -- EVM-only field produces an EVM-family finding and is not portable-core.
  let envReadEp : Entrypoint := {
    name := "envRead", returns := .u64,
    body := #[.return (.effect (.contextRead .timestamp))]
  }
  let portableEnvReadModule : Module := { counterModule with entrypoints := #[envReadEp] }
  require (isPortableCoreModule portableEnvReadModule)
    "module reading a portable env field must stay portable-core"
  let evmEnvReadEp : Entrypoint := {
    name := "evmEnvRead", returns := .u64,
    body := #[.return (.effect (.contextRead .baseFee))]
  }
  let evmOnlyEnvReadModule : Module := { counterModule with entrypoints := #[evmEnvReadEp] }
  require (!isPortableCoreModule evmOnlyEnvReadModule)
    "module reading an EVM-only env field must not be portable-core"
  require ((familyOnlyViolations evmOnlyEnvReadModule .evm).isEmpty)
    "EVM-only env field must be legal for EVM family"
  require ((familyOnlyViolations evmOnlyEnvReadModule .solana).size > 0)
    "EVM-only env field must violate Solana family lowering"

  -- Slice 2: Portable identity type vocabulary. `.address` is the chain-neutral
  -- account/identity handle; it is a portable identity and carries no
  -- family-only finding.
  require (ValueType.isPortableIdentity ValueType.address)
    "ValueType.address must be a portable identity handle"
  require (!ValueType.isPortableIdentity ValueType.u64)
    "ValueType.u64 must not be a portable identity handle"
  require (familyOnlyViolations counterModule .solana).isEmpty
    "Counter (uses no .address) stays portable across families"

  -- Slice 2: Aptos entrypoint lowering is shape-based, not name-based. A
  -- Counter-shape module with renamed entrypoints (`init`/`bump`/`read`)
  -- lowers successfully and the generated source carries the renamed
  -- function names.
  let renamedCounterModule : Module := {
    counterModule with
    entrypoints := #[
      { name := "init",  selector? := none, returns := .unit,
        body := #[.effect (.storageScalarWrite "count" (.literal (.u64 0)))] },
      { name := "bump", selector? := none, returns := .unit,
        body := #[.letBind "n" .u64 (.effect (.storageScalarRead "count")),
                  .effect (.storageScalarWrite "count" (.add (.local "n") (.literal (.u64 1))))] },
      { name := "read", selector? := none, returns := .u64,
        body := #[.return (.effect (.storageScalarRead "count"))] }
    ]
  }
  match ProofForge.Backend.Move.Aptos.renderModule renamedCounterModule with
  | .ok src =>
      require (src.contains "public entry fun init(")
        "Aptos lowering must emit the renamed init entrypoint `init`"
      require (src.contains "public entry fun bump(")
        "Aptos lowering must emit the renamed increment entrypoint `bump`"
      require (src.contains "public fun read(")
        "Aptos lowering must emit the renamed get entrypoint `read`"
      require (!src.contains "public entry fun initialize(")
        "Aptos lowering must not fall back to the hardcoded `initialize` name"
  | .error e =>
      throw (IO.userError s!"Aptos should lower renamed-entrypoint Counter by shape: {e.message}")

  -- An entrypoint with an unsupported body shape is rejected.
  let badEp : Entrypoint := {
    name := "weird", returns := .unit,
    body := #[.assert (.literal (.u64 0)) "bad" none]
  }
  let badShapeModule : Module := { counterModule with entrypoints := #[badEp] }
  match ProofForge.Backend.Move.Aptos.renderModule badShapeModule with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Aptos must reject an unsupported entrypoint body shape")

  IO.println "ir-portability: ok"
