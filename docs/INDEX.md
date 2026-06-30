# ProofForge Documentation Index

ProofForge is a Lean-first multi-chain smart contract platform. The current
repository contains the EVM backend baseline and the design track for expanding
the compiler, SDK, test runners, and deployment surface to additional chains.

## Design Docs

- [RFCs](rfcs/README.md): architectural proposals and accepted design direction.
- [中文文档](zh/README.md): Chinese strategy notes and feasibility analysis.

## Current RFCs

- [RFC 0001: Lean-first multi-chain contract platform](rfcs/0001-multichain-platform.md)
- [RFC 0002: Target implementation design](rfcs/0002-target-implementation-design.md)

## Chinese Notes

- [多链愿景可行性分析](zh/feasibility-analysis.md)
- [多链技术实现方案](zh/technical-implementation-plan.md)

## Current Implementation Baseline

- EVM contracts can be written in Lean with `ProofForge.Evm`.
- `proof-forge --evm-bytecode` compiles Lean contracts through LCNF, Yul, and
  `solc --strict-assembly`.
- `scripts/evm/foundry-smoke.sh` validates generated runtime bytecode with
  Foundry's local EVM test runner.
