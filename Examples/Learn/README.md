# Learn Source Examples

These files are grammar seeds for the standalone Learn authoring layer.
`ProofForge.Contract.Learn` parses the current portable subset into a source AST
and lowers it into `ContractSpec` and portable IR.

They are intentionally not Lean files. The executable embedded equivalent still
lives in `ProofForge.Contract.Source` through the `contract_source` syntax:

- `Counter.learn` mirrors the portable Counter source.
- `ValueVault.learn` mirrors `ProofForge.Contract.Examples.ValueVault`.
- `SolanaVault.learn` mirrors `ProofForge.Solana.Examples.Vault` and exercises
  the first Solana target-extension syntax for accounts, PDA derivation, and
  SPL Token CPI.
- `SystemCpi.learn` mirrors `ProofForge.Solana.Examples.SystemCpi`.
- `SystemCreateAccountCpi.learn` mirrors
  `ProofForge.Solana.Examples.SystemCreateAccountCpi`.
- `SplTokenOpsCpi.learn` mirrors
  `ProofForge.Solana.Examples.SplTokenOpsCpi` and exercises selector-bearing
  SPL Token mint, burn, approve, and revoke CPI syntax.

`Tests/LearnSource.lean` checks that these files lower to the same IR modules as
the macro-generated examples, and checks that the Solana target-extension form
renders the same manifest as the embedded source example. The next
implementation step is broadening the parser to Token-2022, sysvars, logs,
memory, crypto, return-data helpers, and typed account/program references that
further reduce string-bearing declarations in user-facing Learn source.
