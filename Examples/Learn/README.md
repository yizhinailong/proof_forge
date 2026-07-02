# Learn Source Examples

These files are grammar seeds for the standalone Learn authoring layer. They
show the source shape ProofForge should accept before lowering into
`ContractSpec` and portable IR.

They are intentionally not Lean files. Today, the executable equivalent lives in
`ProofForge.Contract.Source` through the embedded `contract_source` syntax:

- `Counter.learn` mirrors the portable Counter source.
- `ValueVault.learn` mirrors `ProofForge.Contract.Examples.ValueVault`.

The next implementation step is to parse these files into a source AST, lower
that AST to the existing `ContractSpec` boundary, and compare the generated IR
against the current macro-generated examples.
