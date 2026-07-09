# Shared Portable Examples

`Examples/Shared` is the **portable-default product path**: authors write
business logic (or `TokenSpec` features) only. `proof-forge build --target …`
materializes chain form (EVM slots/ABI, Solana accounts/CPI/SPL, NEAR host, …).

**Rules (enforced by `just portable-default`):**

- Import `ProofForge.Contract.Source` only — **not**
  `ProofForge.Contract.Source.Solana` (Solana account/PDA/CPI opt-in) or
  `ProofForge.Contract.Source.Near` (NEAR Promise host-extension opt-in).
- No `import ProofForge.Solana` / chain backends in Shared sources.
- No author-selected `TokenStandard` (ERC-20 / SPL / Token-2022) — only
  `TokenFeature`s; `planForTarget` resolves the standard.
- No Account/PDA/CPI DSL (`account` / `pda` / `cpi` / `invoke` …) — those
  require `import ProofForge.Contract.Source.Solana` under `ProofForge/Solana/Examples`.
- No NEAR Promise constructors (`nearPromiseThen` …) — use portable `remoteCall`.
- No host string-pool APIs (`registerNearCrosscallString`, `nearAddressLit`) —
  use `declareRemote` + `remoteCallRef` with **logical** peer ids
  (e.g. `peer.callee`). Host ids: explicit CLI `--peer logical=host` or
  `--peers-demo` (default is **no** rewrite).

Target directories such as `Examples/Evm`, `Examples/Solana`, and
`Examples/WasmNear` keep chain-specific fixtures, golden files, and
compatibility entrypoints. New portable product examples should start here.

## Primary Multi-Target Examples

These examples are checked as one source across EVM, Solana sBPF, and
NEAR/Wasm:

| Example | Source | Checked demo |
|---|---|---|
| Counter | [Counter.lean](Counter.lean) | `just portable-counter-multi-target` |
| RemoteCall | [RemoteCall.lean](RemoteCall.lean) | `just portable-remote-call-multi-target` (goldens under `goldens/RemoteCall.*`) |
| ArrayExample | [ArrayExample.lean](ArrayExample.lean) | `just portable-array-example-multi-target` |
| Ownable | [Ownable.lean](Ownable.lean) | `just portable-stdlib-core-multi-target`; shared facade over the canonical stdlib mixin |
| Pausable | [Pausable.lean](Pausable.lean) | `just portable-stdlib-core-multi-target`; shared facade over the canonical stdlib mixin |
| ReentrancyGuard | [ReentrancyGuard.lean](ReentrancyGuard.lean) | `just portable-stdlib-core-multi-target`; shared facade over the canonical stdlib mixin |
| ValueVault | [ValueVault.lean](ValueVault.lean) | `just portable-value-vault` |
| RoleGatedToken | [RoleGatedToken.lean](RoleGatedToken.lean) | `scripts/portable/role-gated-token-multi-target.sh` |
| StakingVault | [StakingVault.lean](StakingVault.lean) | `scripts/portable/staking-vault-multi-target.sh` |

Each file carries the concrete `evm`, `solana-sbpf-asm`, and `wasm-near`
commands in its header. The `ProofForge.Contract.Examples.Counter` and
`ProofForge.Contract.Examples.ValueVault` modules are compatibility aliases for
these shared sources so formal gates and older tests keep stable import paths.

## High-Level Intent Examples

These examples are not protocol-specific contract code. They describe a
product-level intent once and let target routing choose the chain form:

| Example | Source | Current target status |
|---|---|---|
| FungibleToken | [FungibleToken.lean](FungibleToken.lean) | `just token-intent-smoke` / `just shared-token-intent`; mintable+burnable → EVM ERC-20 or Solana SPL |
| FeeToken | [FeeToken.lean](FeeToken.lean) | feature `transfer_fee` only; Solana → Token-2022; EVM → **reject** (not yet materializable) |
| SoulboundToken | [SoulboundToken.lean](SoulboundToken.lean) | feature `non_transferable` only; Solana → Token-2022; EVM → **reject** |

Shared sources describe **intents and features**, not ERC-20 / SPL / Token-2022.
Those names appear only in plan/artifact output after `--target` is chosen.

Legacy `.learn` examples remain parser/equivalence fixtures. New product
examples should use ordinary `.lean` files with `contract_source` or a
higher-level intent SDK such as `TokenSpec`.
