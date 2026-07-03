# SDK Ecosystem Gap Analysis (2026-07)

Status: **Planning document; audited 2026-07-04**

Gate P0 is closed — the three primary chains have production-grade
compilers, artifact emission, deploy manifests, testkit parity, and
resource budgets. But "production-grade compiler" ≠ "any contract can
be written and deployed." This page records the SDK / ecosystem feature
gaps that block the goal of full developer coverage on each chain.

Each section is ordered by priority (P0 = blocks "any contract", P1 =
blocks common patterns, P2 = polish / broader coverage).

---

## EVM

The EVM backend has the deepest IR coverage: 99 constructors classified
(98 validated, 1 unsupported by design). Foundry + Anvil gates are green.
But the SDK surface — what a Solidity developer would write — has large
gaps.

### Token standards

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| ERC-20 | Partial | `ProofForge/Contract/Token/Evm.lean` emits selectors/events; `learn-token-erc20-vm-smoke.sh` exercises it; but stdlib surface is non-canonical | P0 |
| ERC-721 (NFT) | Missing | No `ERC721`/`ownerOf`/`safeTransferFrom` path | P0 |
| ERC-1155 (multi-token) | Missing | No batch receiver or multi-token path | P1 |
| ERC-4626 (vault standard) | Missing | VerifiedVault is custom, not ERC-4626 interface | P1 |
| ERC-2612 (permit) | Missing | TokenSpec advertises `erc20.permit` but no EVM lowering | P1 |
| ERC-1820 / ERC-777 | Missing | No hook registry or ERC-777 sender/recipient hooks | P2 |
| ERC-165 (supportsInterface) | Missing | No `supportsInterface` in any example or SDK path | P0 |

### Access patterns

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| Ownable | Covered | `stdlib/Ownable.lean` — owner storage, onlyOwner, transfer, renounce | — |
| AccessControl (roles) | Missing | Single-owner only; no role grant/revoke | P0 |
| Pausable | Partial | `stdlib/Pausable.lean` has pause/unpause guards but no owner/role auth | P1 |
| ReentrancyGuard | Partial | VerifiedVault hand-rolls nonReentrant; no reusable stdlib guard | P1 |

### Proxy / Upgrade patterns

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| UUPS proxy | Missing | UpgradePolicy rejects non-immutable EVM policies | P1 |
| Transparent proxy | Missing | Same rejection | P1 |
| Beacon proxy | Missing | Same rejection | P2 |
| Diamonds (EIP-2535) | Missing | No facet/loupe storage pattern | P2 |
| CREATE2 factory | Partial | IR lowers `create2`; Foundry proves deterministic deploy; no reusable factory template | P1 |

### DeFi primitives

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| AMM / swap | Missing | No pool/swap example | P1 |
| Flash loan | Missing | No flash/loan callback pattern | P2 |
| Staking | Missing | No staking example | P2 |
| Vault primitive | Partial | VerifiedVault + ValueVault cover deposit/withdraw; not ERC-4626 | P1 |
| Oracle integration | Missing | No Chainlink/oracle example | P2 |

### ABI / constructor / errors

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| Custom errors (0.8.4+) | Partial | Structured revert payloads exist; no Solidity custom-error selector surface | P1 |
| Structured events | Covered | Named events, indexed topics, aggregate data — all lowered | — |
| Constructor args | Partial | Static word ABI blobs only; no dynamic types; scenarios use empty constructors | P0 |
| Storage packing | Missing | One slot per field; no packing/layout optimizer | P1 |
| Batch operations | Missing | No multicall / batch mint/transfer pattern | P1 |
| Factory deployment | Partial | Foundry deploys init code; no reusable factory contract | P1 |

---

## Solana

The Solana backend has the richest SDK extension surface: PDA derivation,
CPI packing, sysvars, syscalls, IDL/client generation, and Pinocchio
reference-equivalence gates. But common ecosystem patterns are still
missing.

### Account model

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| PDA derivation | Covered | `Surface.lean` typed seeds; `pda-web3-smoke.sh` validates | — |
| Account constraints (signer/writable/owner) | Covered | Signer/writable checks lower to the sBPF prologue; owner checks now cover current-program ownership, executable program accounts, and named owner-account references, with missing owner references rejected during lowering | — |
| Multi-account schemas | Covered | Manifest composes state + PDA + CPI + declared accounts | — |
| Close account | Missing | No close-account action (only `set_authority` enum) | P0 |
| Reallocation | Partial | Backend reserves `MAX_PERMITTED_DATA_INCREASE`; no user-facing realloc API | P0 |
| Address lookup tables | Missing | No ALT support in client or examples | P2 |

### CPI coverage

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| System transfer | Covered | Live Surfpool + Pinocchio reference | — |
| System create_account | Covered | Live Surfpool + Pinocchio reference | — |
| SPL Token transfer_checked | Covered | Live Surfpool + Pinocchio reference | — |
| SPL Token mint_to/burn/approve/revoke | Covered | Live Surfpool + Pinocchio reference | — |
| SPL Token set_authority | Covered | Live Surfpool + Pinocchio reference | — |
| Memo / Stake / Vote / Config | Missing | Extension lowering stops at System + SPL Token | P1 |
| ComputeBudgetInstruction | Covered | Solana manifest/IDL/client/package metadata exposes per-entrypoint compute-unit limit and priority-fee advice; generated TS clients emit `ComputeBudgetProgram` pre-instructions | — |

### Token-2022 extensions

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| transfer_fee | Partial | Plan/Surfpool execution; no direct sBPF CPI lowering | P0 |
| non_transferable | Partial | Plan/Surfpool execution; no direct sBPF CPI lowering | P0 |
| confidential_transfer | Missing | No plan or backend support | P1 |
| transfer_hook | Missing | No plan or backend support | P1 |
| metadata_pointer / permanent_delegate / interest_bearing / default_account_state / immutable_owner / memo_transfer | Missing | No plan or backend support | P2 |

### Ecosystem

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| Metaplex NFT / token metadata | Missing | No Metaplex helpers in Surface or Extension | P1 |
| Compressed NFTs (Bubblegum) | Missing | No Bubblegum support | P2 |
| SPL Governance | Missing | No governance program support | P2 |
| Anchor-style derive constraints | Partial | Manual `accountConstraint` / `pdaAccount` primitives; no derive macro | P1 |
| Pinocchio reference breadth | Partial | 5 reference programs; target ≥10 | P1 |

---

## NEAR / Wasm

The NEAR/Wasm backend has the shallowest SDK surface. EmitWat covers
scalar state, events, hash, context, control flow, arrays, and structs
— but NEAR's real contract model (Promise API, tokens, account model,
economics) is almost entirely missing.

### Contract model

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| Entrypoint ABI (Borsh params + returns) | Partial | Only u32/u64/bool/hash decoded; no aggregate ABI | P0 |
| State storage (scalar/map/hash) | Covered | storage_read/write/has_key lowered | — |
| Generic events via log_utf8 | Covered | EmitWat event lowering + offline host | — |
| Cross-contract calls (Promise API) | Missing | No promise imports in HostBridge or EmitWat | P0 |
| Callback handling | Missing | No promise_then / promise_results | P0 |

### Token standards

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| NEP-141 (fungible token) | Missing | No FT example or fixture | P0 |
| NEP-145 (storage management) | Missing | No storage-management fixture | P1 |
| NEP-148 (metadata) | Missing | No metadata fixture | P1 |
| NEP-171 (NFT) | Missing | No NFT example | P1 |
| NEP-178 (NFT enumeration) | Missing | No enumeration example | P2 |
| NEP-448 (multi-token) | Missing | No multi-token example | P2 |

### Account model

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| current_account_id / predecessor_account_id | Partial | Hashed context IDs only; no full account-id string | P0 |
| signer_account_id | Missing | No signer host import | P0 |
| Access keys | Missing | No function-call/full-access key APIs | P1 |
| Storage staking / byte accounting | Missing | No storage_usage / staking host APIs | P1 |

### Economics

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| attached_deposit (native value) | Missing | Target profile advertises valueNative but no deposit host fn | P0 |
| balance_of / balance_change | Missing | No balance host APIs | P1 |
| prepaid_gas / used_gas / GAS_PRICE | Missing | Only external fuel reporting; no in-contract gas APIs | P1 |

### Crypto / misc

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| sha256 | Covered | EmitWat + offline host | — |
| keccak256 | Missing | No import beyond sha256 | P1 |
| ripemd160 / ecrecover / ed25519_verify | Missing | No host imports | P1 |
| block_height | Covered | EmitWat + offline host | — |
| block_timestamp / epoch_height / random_seed | Missing | Offline host only tracks block_index | P1 |
| storage_remove | Missing | No remove host import | P1 |

### Deployment

| Feature | Status | Evidence | Priority |
|---|---|---|---|
| Real NEAR broadcast smoke | Missing | Deploy metadata is offline-only | P1 |
| near-api-js client wrapper | Partial | Generic functionCall wrapper; no view/gas/deposit options | P1 |

---

## Summary: P0 blockers per chain

**EVM (5 P0):** ERC-20 completion, ERC-721 NFT, ERC-165, AccessControl roles, Constructor dynamic args

**Solana (3 open P0, 2 closed P0):** Close account, Reallocation API, Token-2022 direct sBPF CPI (transfer_fee + non_transferable). Account constraint owner validation and ComputeBudgetInstruction are closed.

**NEAR (6 P0):** Promise API (create/then/and/batch), Callback handling, NEP-141 FT, signer_account_id, attached_deposit, Aggregate ABI (structs/arrays in entrypoint params)

Total: 14 open P0 blockers across three chains. These must close before "any
contract can be written and deployed" is true for any chain.
