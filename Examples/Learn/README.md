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
- `LogEvent.learn` mirrors `ProofForge.Solana.Examples.LogEvent` and
  exercises Solana log helper syntax for pubkey and data logs.
- `ReturnDataCompute.learn` mirrors
  `ProofForge.Solana.Examples.ReturnDataCompute` and exercises Solana return
  data plus remaining-compute-unit helper syntax.
- `Memory.learn` mirrors `ProofForge.Solana.Examples.Memory` and exercises
  Solana memory helper syntax.
- `Crypto.learn` mirrors `ProofForge.Solana.Examples.Crypto` and exercises
  SHA-256, Keccak-256, and BLAKE3 hash helper syntax.
- `Clock.learn`, `Rent.learn`, `EpochSchedule.learn`, `EpochRewards.learn`,
  and `LastRestartSlot.learn` mirror the corresponding Solana examples and
  exercise Learn sysvar/context syntax.

`Tests/LearnSource.lean` checks that these files lower to the same IR modules as
the macro-generated examples, and checks that the Solana target-extension form
renders the same manifest as the embedded source example. The next
implementation step is broadening the parser to Token-2022 and typed
account/program references that further reduce string-bearing declarations in
user-facing Learn source.
