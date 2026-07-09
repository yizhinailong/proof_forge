# Host · Protocols · Stdlib (A / B / C)

Status: **Active product model (2026-07-09)**  
Audience: product + compiler  
Related: [product-authoring-architecture](product-authoring-architecture.md),
[capability-registry](capability-registry.md),
[RFC 0006 Token SDK](rfcs/0006-multichain-token-sdk.md),
portable remote (`Examples/Product/RemoteCall.lean`).

## 1. Why three layers

ProofForge must not conflate:

1. **calling the chain runtime** (storage, log, CPI/CALL/promise syscalls),
2. **calling contracts already on chain** (SPL Token, IERC20 address, NEP-141 peer),
3. **compiling our own contract body** that *implements* a standard (OZ-style ERC-20 mixin, NEP-141 mixin).

Authors usually want (1) always, (2) when integrating ecosystem programs, and
(3) when *they are* the token/ownable contract.

```text
  ┌──────────────────────────────────────────────────────────────┐
  │ A. Host / runtime capabilities                               │
  │    storage · event/log · context · hash · remote materialize │
  │    Capability · HostBridge · Solana.Syscalls · backends      │
  ├──────────────────────────────────────────────────────────────┤
  │ B. Protocols — clients for on-chain programs / interfaces    │
  │    Solana: System · SPL · ATA · Memo · Token-2022 CPI        │
  │    EVM:    IERC20 / IERC721 external CALL clients            │
  │    NEAR:   ft_* / storage_deposit promise clients            │
  ├──────────────────────────────────────────────────────────────┤
  │ C. Stdlib — we deploy this bytecode                          │
  │    Contract/Stdlib: ERC20 · Ownable · Pausable · NEP-141 …   │
  └──────────────────────────────────────────────────────────────┘
```

| Layer | Code lives (today) | Author intent |
|-------|--------------------|---------------|
| **A Host** | `Capability`, **`HostRuntime`** (opcode/syscall/import map), `HostBridge`, backends | “Use chain primitives” |
| **B Protocols** | `ProofForge/Protocols/*` (+ legacy `ProofForge/Solana/Programs`) | “Call existing program/contract” |
| **C Stdlib** | `ProofForge/Contract/Stdlib/*` | “I am the implementation” |

**TokenSpec** sits *above* B and C: `--target` picks whether the platform
materializes SPL CPI plans (B), ERC-20 body (C), or NEP-141 mixin (C).

## 2. Layer A — Host (already wrapped)

Portable surface → capability → materialize:

| Intent | Portable API | EVM | Solana | NEAR |
|--------|--------------|-----|--------|------|
| Storage | scalar/map IR | SLOAD/SSTORE | account data | `storage_*` |
| Events | `emit` / `emitIndexed` | LOG* | `sol_log_*` | host log |
| Context | caller / block / value | CALLER, … | tx accounts | signer / deposit |
| Peer remote | `declareRemote` + `remoteCallRef` | CALL | portable CPI | `promise_create` |
| Protocol CPI (Solana) | Solana Surface CPI builders | — | `sol_invoke_signed_c` + dataLayout | — |

Gates: `Target.Capability`, preflight L0–L1, backend honesty rejects.  
**Native symbol inventory:** `ProofForge.Target.HostRuntime` + [host-runtime.md](host-runtime.md).  
**Capability vs n/a:** `requireHostRuntimeHonesty` (e.g. `storage.pda` on NEAR) fails resolve with a `HostRuntime:` diagnostic — no silent success.

## 3. Layer B — Protocols (this doc’s focus)

**Definition:** thin clients that pack the **native call shape** for software
already deployed (or a standard interface on a user-supplied address).  
No business state machine inside the client.

### 3.1 Inventory (primary three hosts)

#### Solana — official / ecosystem programs

Canonical packing: `ProofForge/Solana/Programs.lean` +
`ProofForge/Backend/Solana/Extension/Cpi.lean`  
Facade: `ProofForge.Protocols.Solana`

| Client | dataLayout / role | Status |
|--------|-------------------|--------|
| System transfer / create_account | `system.*` | ✅ packed |
| SPL Token transfer/mint/burn/approve/… | `spl-token.*` | ✅ packed |
| SPL initialize_mint / initialize_account3 | `spl-token.initialize_*` | ✅ packed |
| Vault-owned token account path | `system.create_account` → `initialize_account3` | ✅ example `Solana/Examples/VaultTokenAccountCpi` |
| Associated Token create | `associated-token.*` | ✅ packed |
| Memo | `memo.memo` | ✅ packed |
| Token-2022 fee / hook / pause / … | `token-2022.*` | ✅ packed (subset; see `Protocols.Solana.supportedDataLayouts`) |
| Confidential / crypto-hard layouts | — | ❌ compile-reject (honest; listed in `rejectedLayoutExamples`) |

#### EVM — external interface clients (not OpenZeppelin deploy)

Facades: `ProofForge.Protocols.Evm.IERC20` · `IERC721`

| Client | Meaning | Status |
|--------|---------|--------|
| IERC20 transfer / approve / transferFrom / balanceOf / totalSupply | CALL + 4-byte selector + ABI words | ✅ thin client |
| IERC20 client fixture | `pushTokens` / `readBalance` / `readSupply` | ✅ `Examples/Backend/Evm/Contracts/Ierc20Client` |
| IERC721 ownerOf / transferFrom / safeTransferFrom / balanceOf / … | CALL + selectors | ✅ thin client |
| IERC721 client fixture | `moveToken` / `safeMoveToken` / `readOwner` | ✅ `Examples/Backend/Evm/Contracts/Ierc721Client` |
| Multicall3 | `aggregate` / `tryAggregate` / `aggregate3` selectors | ✅ `Protocols.Evm.Multicall` + fixture (scalar-bounded) |
| Permit2 | `allowance` / `approve` / `transferFrom` / `permitTransferFrom` | ✅ `Protocols.Evm.Permit2` + fixture (scalar-bounded) |
| OpenZeppelin **as deployable mixin** | — | → **Layer C** (`Stdlib.ERC20` / `ERC721`, …) |

EVM has no single “official ERC-20/721 program”. B-layer is **interface client**;
C-layer is **your token implementation**. `safeTransferFrom` client does not
synthesize `onERC721Received` (same honesty as stdlib).

#### NEAR — NEP clients

Facade: `ProofForge.Protocols.Near.FungibleToken`

| Client | Meaning | Status |
|--------|---------|--------|
| `ft_transfer` / `ft_transfer_call` / `ft_balance_of` / `ft_total_supply` | promise remote with NEP-141 method names | ✅ thin client |
| `ft_metadata` / `storage_deposit` | NEP-148 / NEP-145 method names | ✅ declare helpers |
| FT peer fixture | `pay` / `pay_with_callback` / `query_*` | ✅ `Examples/Backend/WasmNear/FtPeerClient` |
| Arg packing | **JsonEncode** schema → Wasm putc/putstr | ✅ `WasmHost/JsonEncode.lean` |
| | NEP-141 objects via schema (not hand putc) | ✅ `ft_transfer` / `balance_of` / … |
| | unknown methods → legacy JSON scalar array | ✅ |
| NEP-141 **as your FT contract** | — | → **Layer C** (`Stdlib.NearFungibleToken`) |

### 3.2 Module map

```text
ProofForge/Protocols.lean                    -- root re-export
ProofForge/Protocols/Solana.lean             -- B Solana facade + layout inventory
ProofForge/Protocols/Evm/IERC20.lean         -- B IERC20 external CALL client
ProofForge/Protocols/Evm/IERC721.lean        -- B IERC721 external CALL client
ProofForge/Protocols/Evm/Multicall.lean      -- B Multicall3 (scalar-bounded)
ProofForge/Protocols/Evm/Permit2.lean        -- B Permit2 (scalar-bounded)
ProofForge/Protocols/Near/FungibleToken.lean -- B NEP-141 peer client + packing honesty
```

**No big-bang move** of Solana packing out of `Backend/Solana` or
`Solana/Programs` — the Protocols package is the **product index + thin
helpers**. Packing stays where lowering already lives.

## 4. Layer C — Stdlib (deployed bodies)

| Mixin | Role | Not the same as |
|-------|------|-----------------|
| `Stdlib.ERC20` | You **are** the ERC-20 | `Protocols.Evm.IERC20` (call someone else) |
| `Stdlib.Ownable` / Pausable / … | Policy body | Host ownable precompile (none) |
| `Stdlib.NearFungibleToken` | You **are** NEP-141 | `Protocols.Near.FungibleToken` (call someone else) |

## 5. How authors should choose

| Goal | Use |
|------|-----|
| Portable business only, target picks chain shape | `contract_source` / TokenSpec / policies (product default) |
| Call SPL / ATA / System from a Solana program | **B** Solana protocol CPI |
| Call an existing ERC-20 / ERC-721 at an address | **B** IERC20 / IERC721 client |
| Call an existing NEAR FT | **B** Near.FungibleToken peer client |
| Deploy *your* ERC-20 / Ownable / NEP-141 | **C** Stdlib mixin |
| Log, store, general peer remote | **A** Host |

## 6. Execution order (stepwise)

1. ✅ Document A/B/C + inventory (this file)
2. ✅ Protocols module surface + Solana facade
3. ✅ Minimal EVM IERC20 + NEAR FT **clients** (B)
4. ✅ Solana vault token-account e2e + EVM IERC20 client example
5. ✅ NEAR FT peer example · EVM IERC721 client/example · Solana layout inventory export
6. ✅ Multicall + Permit2 clients · NEAR packing honesty · Soroban/CosmWasm HostRuntime rows · catalog-ref lowerer

## 7. Honesty rules

- Unsupported protocol layouts → **compile / preflight reject**, never empty CPI.
- Stdlib must not claim “wraps OpenZeppelin bytecode”; it is a portable mixin.
- Protocol clients must not pretend multi-host ABI if selectors/method names are host-native
  (IERC20 is EVM-shaped; Solana CPI is Solana-shaped; NEP method strings are NEAR-shaped).
  Portable **intent** still uses Layer A `remote` when the call is generic peer logic.
