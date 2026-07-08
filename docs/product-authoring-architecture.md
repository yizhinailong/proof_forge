# Product Authoring Architecture

Status: **Planning (2026-07-09)**  
Audience: product + compiler design  
Related: [authoring-model](authoring-model.md), [D-028](decisions.md),
[D-027](decisions.md), [D-050](decisions.md),
[RFC 0006 Token SDK](rfcs/0006-multichain-token-sdk.md),
[IR portability remediation](ir-portability-remediation.md).

## 1. Product thesis

**Authors write business logic only.**  
**`--target` selects the chain and owns all native mapping.**

```text
  ┌─────────────────────────────────────────────────────────┐
  │  Author: business intents only                          │
  │  state · entry · rules · token features · roles · events│
  └───────────────────────────┬─────────────────────────────┘
                              │  contract_source / TokenSpec
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │  Compiler-owned: ContractSpec + portable IR + caps      │
  │  (chain-neutral shapes; no PDA/CPI/slot/object syntax)  │
  └───────────────────────────┬─────────────────────────────┘
                              │  --target <id>
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │  Target adapter: automatic materialization              │
  │  EVM slots · Solana accounts/PDA/CPI · NEAR host/Promise│
  │  Move resource/object · Token ERC-20 vs SPL/Token-2022  │
  └─────────────────────────────────────────────────────────┘
```

Solana’s account/PDA/CPI model, NEAR’s host/Promise model, EVM’s
storage/ABI/proxy model, and Move’s resource/object model are **platform
problems**, not author problems. The author never picks “I am writing a
Solana program” inside portable source.

This is already the *stated* design (D-028, RFC 0006). The engineering
job is to make the *default product path* match the statement end-to-end.

## 2. What authors should see (default surface)

| Allowed in portable source | Not allowed in portable source |
|---|---|
| State shape (`scalar` / `map` / …) | Storage slots, account metas, PDA seeds (unless policy seeds are pure business literals) |
| Entrypoints + business control flow | `fallback` / `receive` / 4-byte selectors as required author input |
| Checked vs wrapping arithmetic intent | Opcode names, syscalls |
| Roles / ownable / pause / reentrancy **policies** | ERC-1967 slots, Anchor `#[account]` macros |
| Token **business** features: mintable, burnable, capped, fee, soulbound, … | `erc20` / `spl-token` / `token-2022` as author-chosen standards |
| Structured events + portable errors | Topic indexing layout, log_utf8 encoding |
| Cross-contract **intent** (“call method X on peer Y”) | CPI account vectors, Promise chains, STATICCALL/DELEGATECALL |
| Upgrade **policy** (immutable / authority / governance) | UUPS vs transparent proxy implementation |

**Token example (desired):**

```text
token MyToken {
  name "Proof Token"
  symbol "PRF"
  decimals 9
  feature mintable
  feature burnable
  feature transfer_fee   -- business: charge fee on transfer
}
```

```sh
proof-forge build --target evm ...
  → ERC-20 (+ fee logic in contract storage)

proof-forge build --target solana-sbpf-asm ...
  → SPL or Token-2022 plan (transfer_fee extension + CPI plan)
  → no hand-written Account/PDA/CPI in source

proof-forge build --target wasm-near ...
  → NEP-141 (+ fee policy) when NEAR token lane is ready
```

Authors never write `TokenStandard.erc20` or `splToken2022` for the
default path. `planForTarget` already starts this for TokenSpec; the
product rule is: **finish and expand that pattern everywhere.**

## 3. Layer contracts (who owns what)

| Layer | Owns | Must not own |
|---|---|---|
| **L1 Intent API** (`contract_source` portable subset) | Business state, methods, policies, token features | Chain APIs, Account/PDA/CPI syntax, Promise APIs |
| **L2 Portable IR** | Shape + effects + capability ids | `nearPromise*`, CREATE2, fallback/receive as default, object/resource owner |
| **L3 Capability + StorageBinding** | Support matrix; storage materialization enum | Author-visible chain types |
| **L4 Target adapter** | ABI, accounts, PDA derivation templates, CPI packing, host imports, Move object/resource emit, token standard choice | Changing portable business semantics |
| **L5 Target Extension SDK** (opt-in) | Escape hatch when business *requires* chain-native ops | Becoming the default teaching path |

**L5 rule:** Extensions are advanced mode. Portable Counter / Token /
Vault tutorials must never require importing `ProofForge.Solana` or
writing CPI statements.

## 4. Gap analysis (repo today)

| Area | Intended | Current gap |
|---|---|---|
| TokenSpec | Target picks ERC-20 vs SPL/2022 | Direction correct; NEAR/Move token lanes thin; some feature ids still Solana-shaped in docs |
| Stdlib ERC-20 | Should be “portable token mixin” routed by target | Named and lowered primarily as EVM ERC-20 |
| `contract_source` | Portable by default | Documents EVM guards, constructor ABI, Solana PDA/CPI in the same surface |
| Solana Surface | Extension only | Widely used in examples; easy to confuse with default product |
| Portable IR Expr | Chain-neutral | Still carries NEAR Promise + EVM create/static/delegate constructors |
| Storage | Target-resolved (`StorageBinding`) | ✅ Landed (D-050) |
| Context | Portable env vs EVM-only | ✅ Classified; Surface still exposes both |

## 5. Phased plan

### Phase A — Product default path (author experience)

**Goal:** A new developer can write Counter / Token / Vault **without** any
chain keyword in source, and build to `evm`, `solana-sbpf-asm`, `wasm-near`.

1. **Portable-only `contract_source` profile**
   - Document and lint: portable modules must not import Solana/NEAR
     extension helpers.
   - Diagnostics: “PDA/CPI is a Solana extension; omit it for portable
     authoring or pass `--target solana-sbpf-asm` with an explicit
     extension-enabled project.”
2. **Token feature vocabulary = business only**
   - Keep `mintable` / `burnable` / `capped` / `fee` / `non_transferable` /
     `pausable` as portable features.
   - Map at target time: EVM contract logic vs Token-2022 extension vs
     NEAR NEP-141 fields.
   - Deprecate author-facing `TokenStandard` selection for default CLI;
     keep as plan output only.
3. **Role / ownable / pause as portable policies**
   - Stdlib mixins stay portable IR; EVM/Solana/NEAR each lower guards
     and state layout via adapters (not separate ERC/Ownable copies per chain).

**Exit:** `just portable-counter-multi-target` + portable token smoke for
EVM + Solana without extension syntax in shared examples.

#### Phase A status (2026-07-09) — landed

| Item | Evidence |
|---|---|
| Shared portable-default lint | `just portable-default` → `scripts/portable/check-portable-default.py` + topology |
| No chain Surface / TokenStandard in `Examples/Shared` | Gate rejects forbidden imports and `TokenStandard.*` |
| TokenSpec has no author `standard` field | Structure is features-only; `resolveTokenStandard` is adapter-only |
| Feature → standard is target-resolved | FungibleToken → erc20 / spl-token; FeeToken → spl-token-2022 on Solana |
| Unsupported features **reject** (no silent drop) | FeeToken / Soulbound on `evm` error citing `transfer_fee` / `non_transferable` |
| Product docs | `Examples/Shared/README.md`, Token.lean module header |

**Phase B.1 (2026-07-09) — Solana Source opt-in:**

| Item | Evidence |
|---|---|
| Portable default import | `import ProofForge.Contract.Source` |
| Solana extension import | `import ProofForge.Contract.Source.Solana` (re-exports Source + Solana Surface/Builders) |
| Solana examples | `ProofForge/Solana/Examples/*` that use account/PDA/CPI import `Source.Solana` |
| Shared gate | `portable-default` forbids `Source.Solana` and Solana DSL keywords |

Still open for later Phase B: Solana **auto-materialization** of accounts for
portable contracts (not just TokenSpec plans); stop pulling Solana Surface as a
compile-time dependency of the portable elaborator module.

### Phase B — Automatic chain materialization (compiler)

**Goal:** Adapters synthesize accounts/PDA/CPI/host layout from portable IR
for common patterns so authors do not declare them.

| Pattern | EVM | Solana (auto) | NEAR (auto) |
|---|---|---|---|
| Scalar / map state | storage slots | program state account (+ optional PDA for vaults) | host storage keys |
| Token balances | map in contract | ATA + SPL CPI plan | NEP-141 balance map |
| Auth (ownable) | address storage + guard | authority pubkey account / signer check | predecessor account |
| Cross-call intent | CALL | CPI frame synthesized from plan | Promise create/then |
| Events | LOG topics | `sol_log` / event account | `log_utf8` JSON |

Implementation sketch:

1. **`Target.Materialize`** (new module family)
   - Input: portable `Module` + `CapabilityPlan` + target profile.
   - Output: target plan already partially present (`Evm.Plan`,
     `Solana.Plan`, Wasm plan) — unify naming and stage order (RFC 0014).
2. **Solana auto-layout**
   - Default: one data account for portable scalar/map state.
   - TokenSpec: mint + ATA + CPI templates without author account lists.
   - PDA only when policy requires deterministic address (vault, escrow);
     seeds derived from business ids, not hand-written account tables.
3. **NEAR auto-host**
   - Promise still capability-gated; materialize from portable
     `crosscall.invoke` + async policy metadata, **not** portable
     `nearPromise*` Expr constructors (D-050 Slice 3).

**Exit:** Shared RoleGatedToken / StakingVault / TokenSpec examples contain
zero Solana account declarations yet still pass Solana light gates.

### Phase C — Clean portable IR (compiler hygiene)

Already partially tracked in [ir-portability-remediation](ir-portability-remediation.md):

1. Remove / quarantine family-only Expr constructors (NEAR Promise, CREATE2, …).
2. Neutral constructor / init params on `ContractSpec` (drop `evm*` prefixes).
3. Entrypoint kind portable default = `function` only.
4. Identity type remains one portable handle; ABI rename in adapter.

**Exit:** `isPortableCoreModule` true for all shared scenarios; family-only
constructors only appear in extension fixtures.

### Phase D — Explicit extensions (advanced)

Keep Solana PDA/CPI, custom syscalls, raw host imports as **opt-in**:

```lean
import ProofForge.Solana.Surface  -- opt-in; non-portable
```

Rules:

- Extension use → module marked non-portable for other families.
- `--target` mismatch → hard error with “this is a Solana extension.”
- Docs separate “Portable contracts” vs “Chain-native extensions.”

### Phase E — Breadth after parity

Only after portable Token + Vault + Counter parity on three primary
targets:

- NEAR NEP-141 full token lane from same TokenSpec
- Move token / object mapping from same portable token/state
- CosmWasm / Aptos advancement per existing gate schedule

Do **not** open new chains until Phase A–C are credible.

## 6. Token Extension specifically

Token-2022 “extensions” on Solana are **not** author-facing ProofForge
extensions. They are **target materializations** of portable features:

| Portable feature | EVM materialization | Solana materialization |
|---|---|---|
| `transfer_fee` | fee logic in contract | Token-2022 transfer_fee extension + CPI |
| `non_transferable` | transfer guard | Token-2022 non_transferable |
| `mintable` | minter role | mint authority |
| `pausable` | pause flag + guards | pausable extension or wrapper |
| `permit` | EIP-2612 if supported else reject | reject or wrapper (honest diagnostic) |

Author never writes `feature token_2022` or `extension transfer_fee_config`.
They write `feature transfer_fee`; Solana adapter chooses Token-2022.

## 7. Engineering order (next 4–6 slices)

| Order | Slice | Why |
|---|---|---|
| 1 | **Portable-default lint + docs** for `contract_source` | Stops teaching the wrong mental model |
| 2 | **TokenSpec-only product path** for tokens (no standard pick) | Matches user vision; RFC 0006 already points here |
| 3 | **Solana auto state/token materialization** for portable IR | Biggest “accounts/PDA/CPI behind the curtain” win |
| 4 | **NEAR Promise out of portable Expr** + crosscall materialization | IR hygiene + async host story |
| 5 | **Stdlib rename/route**: portable policies → per-target token/access lowering | One Ownable/Token intent, many ABIs |
| 6 | **Spec/Builder de-EVM naming** + CLI defaults | Finish product surface cleanup |

## 8. Success metrics

- Shared examples under `Examples/Shared/` import **no** chain Surface modules.
- `TokenSpec` → EVM + Solana (+ later NEAR) without author-selected standard.
- New contributor tutorial: “write logic → pick target → deploy” with zero
  account/PDA/CPI mentions until the Extension chapter.
- Capability diagnostics remain the only “you can’t do that on this chain”
  feedback — never silent semantic change.

## 9. Non-goals (this phase)

- Replacing Solana’s token program with a custom per-token program by default.
- Full formal refinement of every materialization path before product default
  is usable.
- Unifying all chain economics (gas vs CU vs yocto) into one number for authors
  (budgets stay target-side, D-040).

## 10. Decision needed (product)

When a portable feature cannot be realized on a target:

1. **Reject at compile time** with capability id (default, preferred), or  
2. **Degrade** with a forced opt-in flag (e.g. `--allow-feature-drop`).

Recommendation: **(1) only.** Matches existing platform promise.

---

**Summary line for the team:**  
ProofForge is not “a multi-chain SDK where you write Solana in Lean.”  
It is **a business-intent compiler** where Solana Account/PDA/CPI, NEAR
Promise, EVM ABI/slots, and Move objects are **backend materializations** of
the same intent under `--target`.
