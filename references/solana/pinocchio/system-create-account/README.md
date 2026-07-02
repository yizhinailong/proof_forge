# Pinocchio System Create Account Reference

This fixture is the third Rust/Pinocchio equivalence reference for the
ProofForge Solana SDK beta line. It mirrors
`ProofForge.Solana.Examples.SystemCreateAccountCpi`:

- instruction `create`
- tag byte `0`
- instruction data layout: `u8 tag`, little-endian `u64 lamports`, and
  little-endian `u64 space`
- accounts: `last_created_lamports`, `payer`, `new_account`, `system_program`
- CPI: System Program `CreateAccount { from: payer, to: new_account,
  lamports, space, owner: program_id }`
- observable state writes: `last_created_lamports = lamports` and
  `last_created_space = space`

The default validation gate compares the checked-in reference manifest and
source constants against the ProofForge-generated artifact. It deliberately
avoids downloading Rust crates by default. To experiment with the native
Pinocchio build path, run:

```sh
PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1 \
  scripts/solana/pinocchio-system-create-account-equivalence.sh
```

Primary references:

- Pinocchio entrypoint, `no_allocator!`, and `cpi` feature docs:
  https://docs.rs/pinocchio/latest/pinocchio/
- Pinocchio System `CreateAccount` instruction docs:
  https://docs.rs/pinocchio-system/latest/pinocchio_system/instructions/struct.CreateAccount.html
- Solana System `create_account` instruction docs:
  https://docs.rs/solana-system-interface/latest/solana_system_interface/instruction/fn.create_account.html
