# Host runtime abstraction (Layer A)

Status: **Active (2026-07-09)**  
Audience: compiler + multi-chain product  
Related: [protocols-layer](protocols-layer.md), [capability-registry](capability-registry.md),
`ProofForge.Target.HostRuntime`, `ProofForge.Target.HostBridge`,
`ProofForge.Backend.Solana.Syscalls`.

## 0. Host-native packing layers (siblings)

| Host | Pack / encode layer | Role |
|------|---------------------|------|
| NEAR / Wasm | `WasmHost.JsonEncode` | promise / event JSON objects |
| EVM | `Evm.AbiEncode` | calldata layouts (Call[], bytes, …) |
| Solana | CPI `dataLayout` (`Extension.Cpi`) | instruction data words |

Authors and Protocols build **schemas**; backends lower once. Do not hand-roll
putc / mstore / ix bytes at call sites.

## 1. Question

> Solana has syscalls, EVM has opcodes/precompiles, NEAR has host imports —
> did we abstract those so the framework can support any chain?

**Short answer:** yes at the **intent / capability** layer; **partially** at the
**native symbol inventory** layer — now formalized as `HostRuntime`.

Authors never write `sol_log_64_` or `SLOAD`. They write portable IR. Targets
materialize. What was missing was one table that says, for each portable
effect, which **native** symbol each chain uses.

## 2. Three sub-layers of “host”

```text
  Author / IR
       │  emit, storage read, remoteCall, caller, …
       ▼
  Capability          (gate: does target claim support?)
       │
       ▼
  HostEffect          (HostRuntime catalog — portable effect id)
       │
       ▼
  NativeBinding       (opcode | syscall | host_import + symbol)
       │
       ▼
  Backend lowerer     (Yul / sBPF / EmitWat actually emits it)
```

| Piece | Role | Location |
|-------|------|----------|
| Portable IR effects | What the contract *means* | `IR`, Surface |
| `Capability` | Support matrix / reject | `Target/Capability.lean` |
| `HostEffect` + `NativeBinding` | **Syscall/opcode inventory** | `Target/HostRuntime.lean` |
| `HostBridge` | Wasm import/export metadata | `Target/HostBridge.lean` |
| Solana `Syscalls` | sBPF symbol constants | `Backend/Solana/Syscalls.lean` |
| Backend lowerers | Real codegen | Evm / Solana / WasmHost |

## 3. Primary triad map (summary)

| HostEffect | EVM | Solana | NEAR |
|------------|-----|--------|------|
| storage read/write | `sload`/`sstore` | account data | `env.storage_*` |
| log | `log0..4` | `sol_log_64_` | `env.log_utf8` |
| caller | `caller` | signer account | `env.signer_account_id` |
| value | `callvalue` | lamports field | `env.attached_deposit` |
| block env | `number`/`timestamp` | `sol_get_clock_sysvar` | `env.block_timestamp` |
| keccak / sha256 | opcode / precompile | `sol_keccak256` / `sol_sha256` | host crypto |
| remote | `call` | `sol_invoke_signed_c` | `env.promise_create` |
| return data | `return` / returndatacopy | `sol_set/get_return_data` | `value_return` / `promise_result` |
| PDA | CREATE2 (weak) | `sol_create_program_address` | n/a |

Full machine-readable table: `ProofForge.Target.HostRuntime.HostEffect.bindings`.

## 4. What “support any chain” means here

1. **Add a target profile** (`Registry`) with capabilities.  
2. **Fill `HostEffect.bindings`** for that `targetId` (or document `n/a`).  
3. **Implement backend lower** for each used effect.  
4. **Optional:** extend `HostBridge` if Wasm-shaped.

New chains do **not** require authors to learn new syscall names. They require
a materializer that honors the same `HostEffect` / Capability surface.

## 5. Honesty

- Inventory ≠ full lowering coverage. Some bindings are notes (“via account
  pointers”) until every path is a single symbol.
- Family-only ops (EVM `CREATE2`, Solana PDA) stay capability-gated.
- **Capability vs n/a gate (shipped):** `requireHostRuntimeHonesty` rejects when a
  plan requests a capability whose linked `HostEffect` has symbol `n/a` on the
  target (e.g. `storage.pda` on `wasm-near`). Wired into
  `requireCapabilityPlan` / `resolveSpec` so diagnostics name `HostRuntime`.
- Layer **B** (Protocols) is *programs/interfaces*, not host syscalls.
- Layer **C** (Stdlib) is *your* contract body.

## 6. Wasm adapters (Soroban · CosmWasm)

Rows live in `HostEffect.adapterBindings` for targets
`wasm-stellar-soroban` and `wasm-cosmwasm`. Real symbols where the host bridge
already lowers them (`env._get`/`_put`, `invoke_contract`, `execute_msg`,
`db_read`/`db_write`); explicit `n/a` elsewhere (PDA, compute, …).

## 7. Lowerer catalog reference

Solana sBPF event lowering emits a comment from `catalogRefComment .logEmit`:

```text
; HostRuntime host.log.emit → syscall:sol_log_64_
```

Smokes assert this string appears in real `SbpfAsm.renderModule` output.

## 8. Tests

`Tests/HostRuntime.lean` — catalog shape, primary + adapter targets, support counts,
`requireHostRuntimeHonesty` + `resolveSpec` PDA-on-NEAR reject, catalog-ref on EventProbe.
-/
