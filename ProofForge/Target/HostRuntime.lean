/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer A — Host runtime primitive catalog

Portable contracts never name chain syscalls. They express **host effects**
(storage, log, caller, remote, …) via IR + Capability. Each target materializes
those effects as native primitives:

| Host shape | EVM | Solana | NEAR (Wasm) |
|------------|-----|--------|-------------|
| Kind | opcode / Yul builtin | sBPF syscall | `env.*` host import |
| Examples | `SLOAD`, `CALL`, `LOG*` | `sol_log_*`, `sol_invoke_signed_c` | `storage_read`, `promise_create` |

This module is the **single inventory** of those mappings for the primary
triad. It does not replace backend lowering — it documents and gates “what
native symbol stands for this portable effect”.

See `docs/host-runtime.md` · `docs/protocols-layer.md` (Layer A).
-/
import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.Target.HostRuntime

open ProofForge.Target

/-- How a host exposes a runtime primitive. -/
inductive NativeKind where
  /-- EVM opcode or Yul builtin (`SLOAD`, `keccak256`, `call`). -/
  | opcode
  /-- Solana sBPF syscall (`sol_log_64_`, `sol_invoke_signed_c`). -/
  | syscall
  /-- Wasm host import (`env.storage_read`, `env.promise_create`). -/
  | hostImport
  deriving BEq, DecidableEq, Repr

def NativeKind.id : NativeKind → String
  | .opcode => "opcode"
  | .syscall => "syscall"
  | .hostImport => "host_import"

/-- One native binding of a portable host effect. -/
structure NativeBinding where
  /-- Target id (`evm`, `solana-sbpf-asm`, `wasm-near`, …). -/
  targetId : String
  kind : NativeKind
  /-- Canonical native symbol (opcode name, syscall name, or `env.foo`). -/
  symbol : String
  /-- Optional note (partial, spike, family-only). -/
  note? : Option String := none
  deriving BEq, Repr

/-- Portable host effects that backends must materialize (Layer A).

These are **finer** than Capability ids when one capability fans out to
several native ops (e.g. crypto.hash → keccak vs sha256 vs blake3). -/
inductive HostEffect where
  | storageRead
  | storageWrite
  | logEmit
  | caller
  | valueNative
  | envBlock
  | cryptoKeccak
  | cryptoSha256
  | remoteInvoke
  | remoteInvokeSigned
  | assertFail
  | memoryCopy
  | memorySet
  | returnDataGet
  | returnDataSet
  | computeRemaining
  | pda
  | pdaFind
  deriving BEq, DecidableEq, Repr

def HostEffect.id : HostEffect → String
  | .storageRead => "host.storage.read"
  | .storageWrite => "host.storage.write"
  | .logEmit => "host.log.emit"
  | .caller => "host.caller"
  | .valueNative => "host.value.native"
  | .envBlock => "host.env.block"
  | .cryptoKeccak => "host.crypto.keccak"
  | .cryptoSha256 => "host.crypto.sha256"
  | .remoteInvoke => "host.remote.invoke"
  | .remoteInvokeSigned => "host.remote.invoke_signed"
  | .assertFail => "host.assert.fail"
  | .memoryCopy => "host.memory.copy"
  | .memorySet => "host.memory.set"
  | .returnDataGet => "host.return_data.get"
  | .returnDataSet => "host.return_data.set"
  | .computeRemaining => "host.compute.remaining"
  | .pda => "host.pda.create"
  | .pdaFind => "host.pda.find"

instance : ToString HostEffect where
  toString e := e.id

/-- Map a host effect to the Capability that gates it (when one exists). -/
def HostEffect.capability? : HostEffect → Option Capability
  | .storageRead | .storageWrite => some .storageScalar
  | .logEmit => some .eventsEmit
  | .caller => some .callerSender
  | .valueNative => some .valueNative
  | .envBlock => some .envBlock
  | .cryptoKeccak | .cryptoSha256 => some .cryptoHash
  | .remoteInvoke => some .crosscallInvoke
  | .remoteInvokeSigned => some .crosscallCpi
  | .assertFail => some .assertions
  | .memoryCopy | .memorySet => some .runtimeMemory
  | .returnDataGet | .returnDataSet => some .runtimeReturnData
  | .computeRemaining => some .runtimeComputeUnits
  | .pda | .pdaFind => some .storagePda

/-- Primary-triad native bindings for each portable host effect. -/
def HostEffect.bindings : HostEffect → Array NativeBinding
  | .storageRead => #[
      { targetId := "evm", kind := .opcode, symbol := "sload" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "account_data_load",
        note? := some "via input account data pointers (not a single sol_* syscall)" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.storage_read" }
    ]
  | .storageWrite => #[
      { targetId := "evm", kind := .opcode, symbol := "sstore" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "account_data_store",
        note? := some "via input account data pointers" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.storage_write" }
    ]
  | .logEmit => #[
      { targetId := "evm", kind := .opcode, symbol := "log0..log4" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_log_64_" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.log_utf8" }
    ]
  | .caller => #[
      { targetId := "evm", kind := .opcode, symbol := "caller" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "tx_signer_account",
        note? := some "from instruction accounts (signer flag)" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.signer_account_id" }
    ]
  | .valueNative => #[
      { targetId := "evm", kind := .opcode, symbol := "callvalue" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "lamports_field",
        note? := some "account lamports; no msg.value equivalent" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.attached_deposit" }
    ]
  | .envBlock => #[
      { targetId := "evm", kind := .opcode, symbol := "number/timestamp" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_get_clock_sysvar" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.block_timestamp" }
    ]
  | .cryptoKeccak => #[
      { targetId := "evm", kind := .opcode, symbol := "keccak256" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_keccak256" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.keccak256",
        note? := some "when enabled by capability surface" }
    ]
  | .cryptoSha256 => #[
      { targetId := "evm", kind := .opcode, symbol := "sha256_precompile",
        note? := some "precompile 0x02" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_sha256" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.sha256" }
    ]
  | .remoteInvoke => #[
      { targetId := "evm", kind := .opcode, symbol := "call" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_invoke_signed_c",
        note? := some "portable peer CPI; seeds empty when unsigned" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.promise_create" }
    ]
  | .remoteInvokeSigned => #[
      { targetId := "evm", kind := .opcode, symbol := "call",
        note? := some "no PDA seeds; EVM uses msg.sender authority" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_invoke_signed_c" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.promise_create",
        note? := some "NEAR has no PDA seed model; account id auth" }
    ]
  | .assertFail => #[
      { targetId := "evm", kind := .opcode, symbol := "revert" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_panic_" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.panic",
        note? := some "or trap via unreachable" }
    ]
  | .memoryCopy => #[
      { targetId := "evm", kind := .opcode, symbol := "mcopy/mstore",
        note? := some "memory model in Yul" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_memcpy_" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "memory.intrinsic",
        note? := some "Wasm memory ops; not env import" }
    ]
  | .memorySet => #[
      { targetId := "evm", kind := .opcode, symbol := "mstore" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_memset_" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "memory.intrinsic" }
    ]
  | .returnDataGet => #[
      { targetId := "evm", kind := .opcode, symbol := "returndatacopy" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_get_return_data" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.promise_result" }
    ]
  | .returnDataSet => #[
      { targetId := "evm", kind := .opcode, symbol := "return" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_set_return_data" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.value_return" }
    ]
  | .computeRemaining => #[
      { targetId := "evm", kind := .opcode, symbol := "gas" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_remaining_compute_units" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "env.prepaid_gas",
        note? := some "when enabled" }
    ]
  | .pda => #[
      { targetId := "evm", kind := .opcode, symbol := "create2",
        note? := some "address derivation only; not PDA" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_create_program_address" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "n/a",
        note? := some "no PDA model on NEAR" }
    ]
  | .pdaFind => #[
      { targetId := "evm", kind := .opcode, symbol := "n/a" },
      { targetId := "solana-sbpf-asm", kind := .syscall, symbol := "sol_try_find_program_address" },
      { targetId := "wasm-near", kind := .hostImport, symbol := "n/a" }
    ]

/-- All catalogued portable host effects. -/
def allEffects : Array HostEffect := #[
  .storageRead, .storageWrite, .logEmit, .caller, .valueNative, .envBlock,
  .cryptoKeccak, .cryptoSha256, .remoteInvoke, .remoteInvokeSigned, .assertFail,
  .memoryCopy, .memorySet, .returnDataGet, .returnDataSet, .computeRemaining,
  .pda, .pdaFind
]

def primaryTargetIds : Array String := #["evm", "solana-sbpf-asm", "wasm-near"]

/-- Bindings for one target (may be empty if effect is n/a). -/
def bindingsForTarget (effect : HostEffect) (targetId : String) : Array NativeBinding :=
  effect.bindings.filter (fun b => b.targetId == targetId)

/-- True if this target has at least one real binding (not symbol `n/a`). -/
def supports (effect : HostEffect) (targetId : String) : Bool :=
  (bindingsForTarget effect targetId).any (fun b => b.symbol != "n/a")

/-- Count supported effects on a target (for smoke metrics). -/
def supportedCount (targetId : String) : Nat :=
  allEffects.foldl (fun n e => if supports e targetId then n + 1 else n) 0

/-- Catalog id for docs / diagnostics. -/
def catalogId : String := "host.runtime"

end ProofForge.Target.HostRuntime
