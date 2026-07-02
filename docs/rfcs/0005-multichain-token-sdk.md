# RFC 0005: Multi-Chain Token SDK

Status: **Draft**  
Date: 2026-07-02

## Summary

ProofForge should expose a chain-neutral `TokenSpec` SDK for fungible tokens.
The selected target decides how that token intent is lowered:

- `evm` lowers to an ERC-20-compatible contract artifact.
- `solana-sbpf-asm` lowers to an SPL Token or Token-2022 mint/account/CPI
  plan, plus optional wrapper or hook programs when custom logic is needed.

This keeps the user-facing contract code target-neutral while preserving the
different execution models behind each chain.

## Background

ERC-20 is a smart-contract API standard: a token is implemented as a contract
with functions such as `totalSupply`, `balanceOf`, `transfer`, `approve`, and
`transferFrom`. See the official [EIP-20 specification][eip20].

Solana's standard fungible tokens are not normally implemented as one new
program per token. Solana represents tokens through the deployed SPL Token
program: users create/configure mint accounts, token accounts, and instructions
against the token program. Solana's current docs call these SPL Tokens and
describe Token Extensions / Token-2022 as optional mint/account extensions.
See [Solana Tokens][solana-tokens] and [Token Extensions][solana-extensions].

Therefore `SPL-20 contract` is not the right default model. The ProofForge
Solana token target should emit a token deployment/interaction plan, not a
per-token SPL contract, unless the user explicitly asks for custom program
logic.

## SDK Shape

The first implementation adds `ProofForge.Contract.Token.TokenSpec`:

```lean
{
  name := "Proof Token"
  symbol := "PRF"
  decimals := 9
  initialSupply? := some 1000000
  features := #[.mintable, .burnable]
}
```

`planForTarget` maps the same `TokenSpec` to target-specific plans:

| Target | Default standard | Artifact shape | Runtime model |
|---|---|---|---|
| `evm` | ERC-20 | `evm-erc20-contract` | Deploy per-token contract bytecode |
| `solana-sbpf-asm` | SPL Token | `solana-spl-token-plan` | Create mint/token accounts and call SPL Token by CPI/client instructions |
| `solana-sbpf-asm` + Token-2022 features | Token-2022 | `solana-token-2022-plan` | Create Token-2022 mint/account with extensions |

## Target Lowering Rules

### EVM

EVM lowering owns the token implementation:

1. Generate ERC-20 ABI and selectors.
2. Generate storage for balances, allowances, total supply, name/symbol, and
   feature-specific state.
3. Emit events (`Transfer`, `Approval`).
4. Produce bytecode, ABI/deploy manifest, and verification metadata.

EVM uses existing capabilities such as `storage.scalar`, `storage.map`,
`events.emit`, `caller.sender`, `control.conditional`, and
`assertions.check`.

### Solana

Solana lowering should not duplicate the SPL Token program. It should produce:

1. A mint creation plan.
2. Token account / associated token account instructions.
3. CPI helpers for `mint_to`, `transfer_checked`, `approve`, `burn`, and
   authority changes.
4. Optional Token-2022 extension initialization when features require it.
5. Optional generated wrapper/authority/transfer-hook program for custom
   policy.

Solana uses existing capabilities such as `account.explicit`, `crosscall.cpi`,
`storage.pda`, `events.emit`, `control.conditional`, and `assertions.check`.

## Feature Mapping

| Token feature | EVM ERC-20 | Solana SPL Token | Solana Token-2022 / wrapper |
|---|---|---|---|
| Basic transfer | Contract methods | SPL Token instructions | Token-2022 compatible |
| Mintable | Contract role logic | Mint authority | Mint authority |
| Burnable | Contract method | Burn instruction | Burn instruction |
| Capped supply | Contract storage guard | Wrapper/authority guard | Wrapper/authority guard |
| Permit | EIP-specific extension | Not native SPL Token | Custom wrapper or off-chain signing flow |
| Transfer fee | Contract logic | Not legacy SPL Token | Token-2022 transfer-fee extension |
| Non-transferable | Contract logic | Not legacy SPL Token | Token-2022 extension |
| Transfer hook | Contract hook pattern | Not legacy SPL Token | Token-2022 transfer hook program |

## Non-Goals

- Do not pretend Solana has an ERC-20-style per-token contract deployment model.
- Do not add `token.*` capabilities before at least two target families share
  the same lower-level semantic shape.
- Do not make custom Solana token programs the default, because they lose the
  standard SPL Token interoperability surface unless carefully wrapped.

## Implementation Plan

1. **Done:** add `TokenSpec`, `TokenFeature`, and `planForTarget` as a
   chain-neutral planning layer.
2. Add artifact metadata for token plans.
3. Add EVM ERC-20 source/Yul lowering and Foundry/Web3 tests.
4. Add Solana SPL Token plan rendering and Web3.js `@solana/spl-token`
   validation.
5. Add Token-2022 feature routing.
6. Add optional Solana wrapper/transfer-hook generation for custom policies.

[eip20]: https://eips.ethereum.org/EIPS/eip-20
[solana-tokens]: https://solana.com/docs/tokens
[solana-extensions]: https://solana.com/docs/tokens/extensions
