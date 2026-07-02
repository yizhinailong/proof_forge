# Learn Source Examples

These files are grammar seeds for the standalone Learn authoring layer.
`ProofForge.Contract.Learn` parses the current portable subset into a source AST
and lowers it into `ContractSpec` and portable IR.

They are intentionally not Lean files. The executable embedded equivalent still
lives in `ProofForge.Contract.Source` through the `contract_source` syntax:

- `Counter.learn` mirrors the portable Counter source.
- `ValueVault.learn` mirrors `ProofForge.Contract.Examples.ValueVault`.

`Tests/LearnSource.lean` checks that these files lower to the same IR modules as
the macro-generated examples. The next implementation step is extending this
parser to typed Solana target-extension forms.
