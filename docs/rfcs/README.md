# ProofForge RFCs

RFCs define durable architecture decisions for ProofForge. They describe
intended capabilities before implementation, and separate current behavior from
research or future backend targets.

Process: proposals start as Draft, move to **Accepted** when recorded in
[decisions.md](../decisions.md) and cross-linked docs are aligned.

## Index

| RFC | Status | Summary |
|---|---|---|
| [0001](0001-multichain-platform.md) | Accepted | Lean-first multi-chain contract platform architecture |
| [0002](0002-target-implementation-design.md) | Accepted | Target profiles, build pipelines, and backend implementation design |
| [0003](0003-portable-ir-and-runtime.md) | Draft | Portable IR, capability lowering, runtime profiles |
| [0004](0004-evm-semantic-plan.md) | Draft | EVM semantic plan and Yul AST boundary |
| [0005](0005-solana-sbpf-assembly-backend.md) | Accepted | Solana sBPF assembly backend — direct codegen route bypassing the Zig runtime |
| [0006](0006-multichain-token-sdk.md) | Draft | Multi-chain Token SDK: ERC-20 on EVM, SPL Token / Token-2022 plans on Solana |

## Related

- [Documentation index](../INDEX.md)
- [Design decisions](../decisions.md)
- [Implementation backlog](../implementation-backlog.md)
- [Target notes](../targets/README.md)
- [中文文档](../zh/README.md)
