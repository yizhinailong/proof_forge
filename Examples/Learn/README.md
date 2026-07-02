# Learn Source Examples

These files are grammar seeds for the standalone Learn authoring layer.
`ProofForge.Contract.Learn` parses the current portable subset into a source AST
and lowers it into `ContractSpec` and portable IR. The product-facing entrypoint
is now the `.learn` file: `proof-forge --learn-sbpf input.learn` emits Solana
sBPF assembly, manifest, IDL, TypeScript client, and artifact metadata from the
source language without requiring a hand-written Lean `ContractSpec`.

They are intentionally not Lean files. The executable embedded equivalent still
lives in `ProofForge.Contract.Source` through the `contract_source` syntax:

Treat these `.learn` files as the product-facing contract syntax. The
string-heavy `ContractSpec`, Builder, and `ProofForge.Solana.Examples.*`
fixtures are expected-IR/reference fixtures for tests; they are not the surface
application developers should author by hand. The Learn parser may represent
identifiers as strings internally after parsing, but lowering now checks Solana
CPI/PDA/state/account references before those names reach compiler artifacts.
The portable ValueVault smoke deliberately routes `Examples/Learn/ValueVault.learn`
through the CLI so regressions in the source-language path are caught before
backend package generation is considered passing.
For CPI declarations, account operands must first be introduced with
`solana account ...`; writable and signer requirements are checked against that
declaration. Scalar instruction parameters and state values remain ordinary
Learn values.

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
