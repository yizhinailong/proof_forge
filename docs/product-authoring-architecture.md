# Product Authoring Architecture

Status: **Planning (2026-07-09)**  
Audience: product + compiler design  
Related: [authoring-model](authoring-model.md), [D-028](decisions.md),
[D-027](decisions.md), [D-050](decisions.md),
[RFC 0006 Token SDK](rfcs/0006-multichain-token-sdk.md),
[IR portability remediation](ir-portability-remediation.md).

## 1. Product thesis (north star)

**Ideal product path — the only thing the user must choose is `--target`.**

```text
  User writes:   business logic only
  User chooses:  --target solana-sbpf-asm | evm | wasm-near | …
  Platform does: everything chain-native (DSL, accounts, ABI, CPI, host, token standard)
```

Solana Account / PDA / CPI, NEAR Promise / host imports, EVM slots / selectors /
CREATE2, Move resource / object — these are **not authoring languages**. They
are **materialization backends** the compiler drives after target selection.

```text
  ┌─────────────────────────────────────────────────────────┐
  │  L1  Author: business intents ONLY                      │
  │      state · entry · rules · token features · roles     │
  │      (no account, no pda, no cpi, no promise, no slot)  │
  └───────────────────────────┬─────────────────────────────┘
                              │  contract_source / TokenSpec
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │  L2–L3  Compiler: portable IR + capabilities            │
  └───────────────────────────┬─────────────────────────────┘
                              │  --target <id>
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │  L4  Target materializer (automatic)                    │
  │      may *internally* emit Solana plan / CPI frames /   │
  │      EVM Yul / NEAR WAT — authors never write that DSL  │
  └─────────────────────────────────────────────────────────┘
```

**What this means for “native DSL”:**  
Today’s Solana `account` / `pda` / `cpi` syntax and similar chain DSLs are a
**temporary compiler / fixture surface**, not the product. They may remain as:

1. **Compiler-internal IR** (preferred end state): only target plans speak them; or  
2. **Research / pinocchio / live-gate fixtures**: engineers testing the backend; or  
3. **Advanced escape hatch** (discouraged): power users who accept non-portability.

They must **not** appear in Shared product tutorials. The SDK does not ask
users to “call the Solana DSL”; the Solana **adapter** calls it (or generates
equivalent plan data) when `--target solana-sbpf-asm` is set.

This is D-028 / RFC 0006 taken all the way: chain models are platform problems.

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
| **L5 Chain materializer internals** | Solana plan/CPI packing, EVM Yul, NEAR EmitWat — **compiler-owned** | Author-facing “write CPI in Lean” as the default path |

**L5 rule (updated):** Chain DSL is **not** a second product language.  
`ProofForge.Contract.Source.Solana` exists today as a bridge for backend
fixtures; the product goal is that Shared contracts never need it because
L4 auto-materializes accounts/CPI from portable IR. Tutorials must never
require writing PDA/CPI.

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

### Phase B — Automatic chain materialization (compiler)  ← **next product focus**

**Goal:** From **portable IR alone**, each target synthesizes everything that
today still tempts people to write chain DSL by hand.

| Pattern | EVM auto | Solana auto | NEAR auto |
|---|---|---|---|
| Scalar / map state | storage slots / layout | **one program data account** (default) + borsh/layout | host KV keys |
| Token balances | map in contract / ERC-20 | **mint + ATA + SPL/Token-2022 CPI plan** (TokenSpec already partial) | NEP-141 |
| Auth (ownable) | address + guard | signer/authority account checks synthesized | predecessor |
| Cross-call intent | CALL | **CPI frame from intent** (no hand-written account metas) | Promise create/then from intent |
| Events | LOG topics | sol_log / structured log | log_utf8 JSON |
| PDA (only if needed) | n/a | **derived from business ids** (vault id, mint, …) not author seed tables | n/a |

**User-visible success:**  

```lean
-- Shared/Counter.lean  (unchanged portable source)
import ProofForge.Contract.Source
contract_source Counter do
  state count : .u64
  entry initialize do ...
  entry increment do ...
  query get returns (.u64) do ...
```

```sh
proof-forge build --target solana-sbpf-asm ...   # no Source.Solana import
  → Solana.Plan synthesizes: data account, discriminators, entrypoint tags
  → sBPF asm + IDL + client — author never wrote `account` / `pda` / `cpi`
```

Implementation sketch:

1. **`Target.Materialize` / strengthen existing plans**
   - Input: portable `Module` + `CapabilityPlan` + target profile.
   - Output: `Evm.Plan` / `Solana.Plan` / Wasm plan (RFC 0014 stages).
2. **Solana auto-layout (B.2 priority)**
   - Portable scalar/map → single writable state account + payer/system as needed.
   - TokenSpec path already materializes mint/ATA/CPI — extend pattern to
     general `contract_source` modules (Counter, ValueVault, StakingVault).
   - PDA only when the **business** needs a deterministic address; seeds come
     from intent metadata, not author DSL.
3. **Retire author-facing chain DSL from the product story**
   - `Source.Solana` → document as **fixture/backend test only**.
   - Long term: generate Solana.Plan structures in Lean without expanding
     user-written `account` syntax at all.
4. **NEAR auto-host**
   - Materialize Promise from portable `crosscall.invoke` + async policy;
     remove author-facing `nearPromise*` from portable Expr (D-050 Slice 3).

**Exit:** Shared RoleGatedToken / StakingVault / Counter compile to Solana
**without** `import Source.Solana` and without any `account`/`cpi` line, and
pass Solana light gates.

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

| Order | Slice | Status / why |
|---|---|---|
| 1 | Portable-default lint + docs | ✅ Landed |
| 2 | TokenSpec feature-only; standard from target | ✅ Landed |
| 3 | Solana Source opt-in (stop default teaching CPI) | ✅ Landed (bridge) |
| 4 | **Solana auto-materialize portable IR → Plan/accounts** | ✅ B.2 landed for portable state → default account (`Materialize.lean`, `solanaMaterialization` artifact field, `just solana-auto-materialize`) |
| 5 | NEAR Promise out of portable Expr; crosscall materialize | IR hygiene + async |
| 6 | Mark `Source.Solana` fixture-only; demote from product docs | After auto-materialize works for Counter/Vault |
| 7 | Stdlib portable policies → multi-target lowering | One Ownable/Token intent |
| 8 | Spec/Builder de-EVM naming | Product surface cleanup |

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
