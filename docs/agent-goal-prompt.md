# Durable agent goal prompt (ProofForge)

Copy this into a long-running goal / agent session. It is the **continuous
work charter** for portable SDK + host abstraction (not a one-shot task).

---

## Goal

Advance ProofForge so authors write **business intent only**, and `--target`
selects native form on the primary hosts **EVM · Solana · NEAR** (plus existing
Wasm adapters). Keep Layer **A Host / B Protocols / C Stdlib** honest.

## Standing rules

1. **No silent drop** — unsupported layout/capability → compile/preflight reject.
2. **No big-bang renames** — prefer facades + inventory over mass moves.
3. **Primary triad first** — EVM / Solana / NEAR before other chains.
4. **Evidence before claim** — run the relevant `lake env lean --run` / `just` gate.
5. **Small mergeable commits** — one slice per commit; update docs inventory.
6. **Do not open PR** unless the human asks.

## Layer map (always keep in mind)

| Layer | Meaning | Code |
|-------|---------|------|
| **A Host** | Runtime primitives (storage, log, remote, crypto) | `Capability`, `HostRuntime`, `HostBridge`, backends |
| **B Protocols** | Call *existing* on-chain programs/interfaces | `ProofForge.Protocols.*` |
| **C Stdlib** | *You deploy* the implementation | `Contract/Stdlib/*` |

## Work queue (pick top incomplete item, finish, repeat)

### A — Host runtime

- [x] `HostRuntime` catalog (EVM opcode / Solana syscall / NEAR host_import)
- [ ] Wire more lowerers to *reference* catalog symbols in comments/diagnostics
- [ ] Extend catalog for Soroban / CosmWasm host effects already partially lowered
- [ ] Reject/diagnose when a capability is claimed but HostEffect has `n/a` for target

### B — Protocols

- [x] Solana Programs facade + vault token-account path
- [x] EVM IERC20 + IERC721 clients + fixtures
- [x] NEAR FT peer client + fixture
- [ ] EVM Multicall / Permit2 thin clients (optional)
- [ ] NEAR deeper JSON/Borsh arg packing honesty
- [ ] Solana: only high-value remaining layouts (no confidential pretence)

### C — Stdlib / product

- [ ] Keep portable product path free of chain DSL (`just portable-default`)
- [ ] TokenSpec feature → standard routing gaps only when user-visible

### Hygiene

- [ ] Keep `docs/protocols-layer.md` + `docs/host-runtime.md` in sync with code
- [ ] Prefer extending `Tests/ProtocolsLayer.lean` / `Tests/HostRuntime.lean`

## Definition of done for one loop

1. One inventory row or one client/fixture advanced.  
2. Test green.  
3. Doc line updated.  
4. Commit with focused message.  
5. Re-read this prompt; pick next unchecked item.

## Out of scope unless asked

- New chain backends  
- Live network gates requiring missing tools  
- Force-push / production deploy  
- Rewriting Solana packing into a new package tree  

## One-liner restart

> Continue ProofForge Layer A/B/C: HostRuntime completeness, Protocols clients,
> honest rejects; primary hosts EVM·Solana·NEAR; small commits; run smokes;
> follow `docs/agent-goal-prompt.md`.
-/
