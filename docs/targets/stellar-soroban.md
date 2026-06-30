# Stellar Soroban Target

Status: **Research (docs-first candidate)**

Candidate target id: **`wasm-stellar-soroban`**

This note records the first ProofForge classification for Stellar smart
contracts, commonly associated with Soroban. It does not add a Lean target
profile yet.

Primary sources:

- [Stellar smart contracts overview](https://developers.stellar.org/docs/build/smart-contracts/overview)
- [Getting Started](https://developers.stellar.org/docs/build/smart-contracts/getting-started)
- [Setup](https://developers.stellar.org/docs/build/smart-contracts/getting-started/setup)
- [Hello World](https://developers.stellar.org/docs/build/smart-contracts/getting-started/hello-world)
- [Deploy to Testnet](https://developers.stellar.org/docs/build/smart-contracts/getting-started/deploy-to-testnet)
- [Storing Data](https://developers.stellar.org/docs/build/smart-contracts/getting-started/storing-data)
- [Contract Storage](https://developers.stellar.org/docs/build/guides/storage)
- [Contract Authorization](https://developers.stellar.org/docs/build/guides/auth/contract-authorization)

## Classification

Stellar/Soroban belongs in the Wasm-host family, but it must be a separate
target from NEAR and CosmWasm.

```text
Stellar smart contract target
  -> Rust/Soroban SDK authoring model today
  -> Wasm artifact compiled for wasm32v1-none
  -> Stellar host environment and Env API
  -> Stellar CLI validation, deploy, and invoke flow
```

This is not "generic Wasm." Wasm is the executable artifact format. The contract
ABI, host functions, storage model, authorization model, deployment lifecycle,
resource limits, and tooling are Stellar-specific.

## Why This Matters For ProofForge

The existing Wasm-family direction is correct: share only the common Wasm
runtime pieces, and keep chain adapters separate.

For Soroban, the target-specific concerns are:

- contracts are currently Rust/Soroban SDK programs compiled to Wasm;
- the setup path uses Rust `v1.84.0` or newer and the `wasm32v1-none` target;
- `stellar contract build` is the first native build command to mirror;
- deployment is a two-step model: upload/install Wasm bytes, then instantiate a
  contract ID that points at those bytes;
- storage has instance, persistent, and temporary forms, with TTL and archival
  semantics;
- authorization is explicit through address-based calls such as
  `require_auth()` and `require_auth_for_args()`;
- contract accounts can implement `__check_auth()` for custom authorization;
- cross-contract calls use generated client-style calls and host-managed
  authorization context;
- events, tokens, and Stellar Asset Contract integration are target-native
  surfaces, not generic Wasm features.

## Candidate Target Family

Candidate family:

```text
wasm-host
```

Candidate artifact shape:

```text
stellar-soroban-package
  - Wasm module
  - contract spec/interface metadata
  - deployment manifest for upload + instantiate
  - optional generated bindings
  - validation/test report from Stellar CLI or sandbox
```

The first ProofForge artifact should be reviewable and runnable through the
Stellar CLI or sandbox before claiming broader platform support.

## Candidate Capabilities

Most core capabilities overlap with existing Wasm-host targets:

| Existing capability | Soroban interpretation |
|---|---|
| `storage.scalar` | Instance/persistent/temporary contract storage entry. |
| `storage.map` | Typed key-value storage through Soroban storage maps. |
| `caller.sender` | Source account/invoker context where available. |
| `events.emit` | Contract event publishing. |
| `crosscall.invoke` | Cross-contract invocation through generated clients. |
| `env.block` | Ledger/network context reads. |
| `crypto.hash` | Host/Soroban SDK crypto helpers. |

Candidate capabilities that may need explicit ids later:

| Candidate capability | Meaning |
|---|---|
| `auth.require` | Address-level authorization through `require_auth` or equivalent payload binding. |
| `auth.account_contract` | Contract account authorization through `__check_auth`. |
| `storage.ttl` | Explicit TTL extension, archival, and restoration behavior. |
| `artifact.contract_spec` | Contract interface/spec metadata used by CLI and generated bindings. |
| `asset.stellar` | Stellar Asset Contract or token-interface integration. |

Do not add these ids to `ProofForge.Target.Capability` until a target profile
and lowering rules are reviewed.

## Implementation Road

### Road 1: Native Soroban Package Sourcegen

This is the most conservative first spike. Generate or wrap a Rust/Soroban SDK
package that can be built with the Stellar CLI.

First spike:

- choose a Counter-like storage example;
- generate a minimal Soroban package or manifest around hand-authored Rust;
- build with `stellar contract build`;
- validate tests with `cargo test` or Stellar's sandbox path;
- record the Wasm path, contract spec, and tool versions in artifact metadata.

This path validates target semantics before attempting a direct Lean runtime
bridge.

### Road 2: Wasm Host Bridge

This road mirrors NEAR/CosmWasm more directly: Lean lowers to a Wasm module and
a Stellar-specific host bridge.

First spike:

- define the minimal `Lean.Stellar` SDK surface;
- map storage, events, and authorization to Soroban host calls;
- emit a Wasm artifact acceptable to Stellar tooling;
- prove that the generic Wasm runtime does not force-link NEAR or CosmWasm
  bridge code.

This should wait until the Wasm runtime split is real enough to avoid another
one-off adapter.

## Non-Goals For The First Pass

- Do not add `wasm-stellar-soroban` to the code registry yet.
- Do not merge Soroban with `wasm-near` or `wasm-cosmwasm`.
- Do not treat Rust/Soroban SDK details as ProofForge's long-term IR.
- Do not ignore TTL/state archival when modeling storage.
- Do not model authorization as a simple `msg.sender` equivalent.
- Do not claim supported Stellar output until a local build/deploy/invoke smoke
  exists.

## Research Exit Criteria

Soroban can leave Research only when we have:

- a reviewed target profile proposal;
- a decided first spike path: native Soroban package sourcegen or direct Wasm
  host bridge;
- a minimal Counter-like shared scenario;
- a documented toolchain requirement set, including Rust, `wasm32v1-none`, and
  Stellar CLI;
- at least one reproducible local validation command;
- artifact metadata for Wasm, contract spec, deployment manifest, and validation
  result.
