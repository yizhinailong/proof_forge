# Authoring Model

ProofForge should not ask application developers to author `ContractSpec`
objects directly. `ContractSpec` is a compiler-owned boundary: source syntax
lowers into it, target routing consumes it, and backends print target artifacts
from the resulting IR and target-extension metadata.

## Layers

The current stack has three authoring layers:

| Layer | Status | Purpose |
|---|---|---|
| Learn source | Planned standalone source format | User-facing contract language. A developer writes portable contract logic once and selects a target such as EVM, Solana, Move, or Wasm at build time. |
| `contract_source` | Implemented v1 embedded source syntax | Transitional Lean macro frontend. It lets the repo express portable state, entrypoints, events, arithmetic, and first Solana account/PDA/CPI declarations without hand-building `ContractSpec` strings. |
| `ContractSpec` / IR | Internal compiler artifact | Stable bridge into target routing, capability checks, backend lowering, AST/printer stages, manifests, IDL, clients, and deployable packages. |

The intended user experience is Learn-first. `contract_source` is useful because
it is executable inside the current Lean/Lake repo and proves the lowering path,
but it is not the final language parser.

The string-heavy `ContractSpec` and Builder examples should therefore be read
as compiler fixtures, not as the product surface. They describe the same
program shape that the compiler consumes after parsing, capability routing, and
target-extension expansion. Application authors should increasingly see
language syntax in `.learn` files, while tests keep the Builder fixtures as the
reviewed expected IR.

## Source Principles

- Portable contracts should express business logic without target-specific
  deployment details.
- Target-specific capabilities should be requested through typed SDK forms, not
  raw string plumbing.
- Chain dispatch belongs to build configuration and target routing. Source code
  should remain reusable when a target can provide equivalent capabilities.
- Target extensions, such as Solana account/PDA/CPI declarations, may appear in
  source when the contract intentionally needs chain-native semantics. Those
  extensions lower to target metadata and helper actions, not to portable IR
  constructors unless multiple chain families share the same semantic shape.
- Literal strings are acceptable for real protocol bytes, such as PDA literal
  seeds. They should not be the primary representation for accounts, owners,
  capability names, methods, or deployment configuration.

## Current Syntax Boundary

`ProofForge.Contract.Learn` now parses the checked-in `.learn` examples under
`Examples/Learn/` into a small source AST and lowers that AST to the same
`ContractSpec`/portable IR boundary used by `contract_source`. The parser covers
the portable scalar/event subset plus the first Solana target-extension forms
for accounts, PDA derivation, System Program transfer/create-account CPI, and
SPL Token transfer, mint, burn, approve, and revoke CPI. It also accepts
selector-bearing entrypoints such as `entry mint selector "04"(amount: u64)`,
so Solana instruction tags can be represented in Learn source instead of only
in Builder fixtures.
`ProofForge.Contract.Source` remains the executable embedded syntax layer and
covers:

- portable scalar state;
- entrypoints and queries with typed parameters;
- local bindings, assignment, return, event emission, and checked arithmetic
  syntax;
- Solana allocator selection;
- Solana account constraints;
- Solana PDA declarations and derivation statements;
- Solana System Program `transfer` and `create_account` CPI declarations and
  invocation statements;
- Solana SPL Token `transfer_checked`, `mint_to`, `burn`, `approve`, and
  `revoke` CPI declarations and invocation statements.

Examples such as `ProofForge.Contract.Examples.ValueVault` should be read as
v1 source examples, not as the final `.learn` grammar. They exist to keep the
compiler pipeline executable while the standalone Learn parser is introduced.

## Target Routing

The build target chooses the lowering path:

```text
Learn source
  -> source AST
  -> ContractSpec / portable IR
  -> target resolver + capability routing
  -> target semantic AST
  -> printer / assembler / package emitter
```

For Solana, target extensions attach account schemas, PDA seeds, CPI layouts,
IDL, clients, and sBPF assembly helpers. For EVM, routing derives ABI selectors,
Yul, bytecode, ABI metadata, and deployment files. The source author should not
need to manually switch between these internals when the contract is portable.

## Next Implementation Steps

1. Expand the Learn parser beyond the current Vault/System CPI Solana subset to
   cover Token-2022, sysvars, logs, memory, crypto, return-data helpers, and
   the remaining framework-level account/data declarations.
2. Gradually replace string-bearing Solana declarations with typed account,
   owner, program, and capability references.
3. Keep backend artifact checks unchanged so the new Learn syntax proves the
   same EVM/Solana package output.
