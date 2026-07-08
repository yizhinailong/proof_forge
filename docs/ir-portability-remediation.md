# IR Portability Remediation

Status: **In progress (D-050 corrected 2026-07-09 — target-resolved binding)**

Addresses the review finding that the portable IR evolved under EVM pressure.
The authoring surface and IR stay **chain-neutral**; chain-native materialization
is chosen only by `--target`.

Related: [portable-ir.md](portable-ir.md), [D-027](decisions.md),
[D-028](decisions.md), [D-050](decisions.md),
`ProofForge/IR/Portability.lean`, `ProofForge/Target/StorageBinding.lean`.

## Principle (non-negotiable)

```text
Author / portable IR          Target adapter (--target)
─────────────────────         ─────────────────────────
state count: scalar U64  →    evm        → contract storage slot
                         →    solana     → account data field
                         →    wasm-near  → host KV key
                         →    move-aptos → has-key resource
                         →    move-sui   → object with UID
```

Authors **never** write `objectState` / `resourceState` / EVM slot annotations
in the portable path. Those are lowering *outputs*, not IR *inputs*.

## Wrong direction (reverted)

An early D-050 draft put `StorageOwner.resource` / `.object` on `StateDecl`
and exposed `objectState` / `resourceState` builders. That forced authors to
pick a chain at write time and violated D-028. **Removed.**

## Correct layering

| Layer | Owns | Does not own |
|---|---|---|
| Contract Intent / `contract_source` | Portable state, entrypoints, arithmetic, events | Object vs resource vs slot |
| Portable IR (`StateDecl`) | Shape: `scalar` / `map` / `array` + `ValueType` | Chain binding model |
| Capability plan | `storage.scalar`, … | How a chain stores it |
| `Target.StorageBinding` | Profile → native binding enum | Author annotations |
| Backend plan / emit | Materialize binding (Yul `sstore`, Move `has key`, …) | Portable business logic |

## Slice 1 (landed, corrected)

- [x] Portable `StateDecl` is shape-only (no owner field)
- [x] `Target.StorageBinding` resolves binding from target id/family
- [x] EVM/Solana/NEAR/Aptos/Sui adapters map the **same** Counter IR
- [x] Neutral renames: `paramAbiWords`, `proxyPattern?` (metadata, not author intent)
- [x] `ProofForge.IR.Portability` flags true family-only *constructors*
      (create2, NEAR Promise ops, fallback/receive) — not storage binding
- [x] `just ir-portability-smoke`

## Slice 2 (next)

- [ ] Move NEAR Promise `Expr` constructors behind host-extension metadata (D-027)
- [ ] Generalize Move entrypoint lowering beyond Counter body shapes
- [ ] Context field split: portable env vs EVM-only (`baseFee`, `prevRandao`, …)
- [ ] Portable identity type vocabulary (`ValueType.address` → documented as
      chain-neutral account/identity handle; target ABI renames in metadata)
- [ ] Surface `storageBinding` in artifact/deploy JSON for debugging

## Author guidance

```lean
-- One source for every target:
scalarState "count" .u64

-- Build:
--   proof-forge build --target evm ...
--   proof-forge build --target move-sui ...
--   proof-forge build --target move-aptos ...
```

Target Extension SDKs (Solana PDA/CPI, …) remain the only place for
*explicit* chain-native authoring — and they still lower through capabilities
and metadata, not portable IR constructors (D-027).
