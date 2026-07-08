# IR Portability Remediation

Status: **In progress (D-050 slice 1 landed 2026-07-09)**

Addresses the review finding that the portable IR evolved under EVM pressure
and under-expresses Move / account-object ownership, while also carrying
target-family constructors that look portable.

Related: [portable-ir.md](portable-ir.md), [D-027](decisions.md),
[D-050](decisions.md), `ProofForge/IR/Portability.lean`.

## Problem

| Smell | Example | Impact |
|---|---|---|
| EVM-named fields on core IR | `paramEvmAbiWords`, `evmProxyPattern?` | Signals EVM-first design; confuses non-EVM adapters |
| Missing ownership model | State only had shape (`scalar`/`map`/`array`) | Move object/resource semantics forced into Counter-name templates |
| Family-only constructors in `Expr` | `nearPromise*`, `crosscallCreate2`, `fallback`/`receive` | Looks portable; only one family can lower them |
| Docs/code drift | docs listed `account_owned`/`object` kinds; code had `array`/`dynamicArray` | Authors could not express documented shapes |

## Strategy (do not rewrite IR from scratch)

1. **Shape vs ownership** — keep `StateKind` for layout shape; add `StorageOwner`
   for binding model (`contract` default).
2. **Classify, then migrate** — `IR.Portability` tags every non-core constructor;
   backends may reject family-only findings for the wrong family.
3. **Rename EVM baggage** — neutral field names first; move remaining baggage
   into target metadata bags over time (D-027).
4. **No silent semantics** — EVM rejects `resource`/`object` owners; Move
   rejects the wrong owner for its model; portable fixtures stay on `contract`.

## Slice 1 (landed)

- [x] `StorageOwner` + `storage.resource` / `storage.object` capabilities
- [x] `paramAbiWords` / `proxyPattern?` renames (+ compatibility aliases)
- [x] `ProofForge.IR.Portability` classifier
- [x] EVM `validateState` owner checks
- [x] Aptos/Sui accept explicit owners (still Counter MVP for entrypoints)
- [x] `just ir-portability-smoke` in `just check`

## Slice 2 (next)

- [ ] Move NEAR Promise `Expr` constructors behind host-extension metadata
      (keep capability `.nearPromise`; stop looking portable)
- [ ] Generalize Move entrypoint lowering beyond hardcoded
      `initialize`/`increment`/`get` names for scalar object/resource modules
- [ ] Optional: `contract_source` surface helpers for `objectState` /
      `resourceState` in portable authoring docs
- [ ] Context field split: portable env (`timestamp`, `checkpointId`) vs
      EVM-only (`baseFee`, `prevRandao`, `coinbase`)

## Slice 3 (later)

- [ ] Target-metadata bag on `Module` for all family baggage
      (`proxyPattern`, `nearCrosscallStrings`, future Solana layout hints)
- [ ] Expand Portability findings into CLI `check` diagnostics
- [ ] Formal: prove family-only constructors never appear in
      `isPortableCoreModule` witnesses used by three-chain testkit

## Author guidance

```text
Portable (evm + solana + near):
  state count: scalar u64            # owner defaults to contract

Sui-native authoring:
  state count: scalar u64 owner object

Aptos-native authoring:
  state count: scalar u64 owner resource
```

Builder helpers: `scalarState`, `objectState`, `resourceState` in
`ProofForge.Contract.Builder`.
