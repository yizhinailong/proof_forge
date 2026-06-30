# Move Family Targets

Sui and Aptos are not Wasm or EVM-style runtime targets. ProofForge should not
try to compile the full Lean runtime into Move. The practical first route is
source generation from a restricted portable contract IR.

## Common Move Strategy

```text
Lean portable contract
  -> Lean checks and proofs
  -> Move-compatible portable IR subset
  -> generated Move package
  -> target CLI build/test
```

The generated package should be readable and verifier-friendly. Source
generation is also easier to review than direct bytecode generation.

## Shared Restrictions

Allowed in the first Move-compatible IR:

- booleans
- unsigned integers
- addresses
- byte vectors
- structs with concrete fields
- simple enums lowered to tags
- first-order functions
- explicit entrypoints
- explicit abort codes
- target capabilities for events, resources, and objects

Disallowed at first:

- higher-order runtime functions
- arbitrary Lean closures
- arbitrary recursion
- Lean heap objects
- raw IO
- dynamic reflection
- target syscalls not represented as capabilities

Proofs remain in Lean. The generated Move code only contains executable
runtime logic.

## Sui

Sui uses an object-centric model. Persistent state maps to objects with `UID`.

Example generated object:

```move
public struct Counter has key {
    id: UID,
    value: u64,
}
```

Mapping:

| Portable concept | Sui mapping |
|---|---|
| Contract state | object with `UID` |
| Entry method | `public entry fun` |
| Caller | `TxContext.sender(ctx)` |
| Native assets | `Coin<T>` |
| Events | `sui::event::emit` |
| Maps | table or dynamic fields |
| Deployment | Move package publish |

First package layout:

```text
build/sui/counter/
  Move.toml
  sources/counter.move
  tests/counter_tests.move
```

First POC:

- `Counter` object.
- `init(ctx: &mut TxContext)`.
- `increment(counter: &mut Counter)`.
- `value(counter: &Counter): u64`.
- Move unit tests.

Main design risk: Sui object ownership is not a storage implementation detail.
It changes method signatures and call flows, so it must be represented in the
portable IR or target manifest.

## Aptos

Aptos is closer to account-scoped resources.

Example generated resource:

```move
struct Counter has key {
    value: u64,
}
```

Mapping:

| Portable concept | Aptos mapping |
|---|---|
| Contract state | account resource with `key` |
| Entry method | `public entry fun` |
| Caller | `&signer` |
| Native assets | Aptos Coin or fungible asset APIs |
| Events | framework event APIs |
| Maps | table resources |
| Deployment | Move package publish |

First package layout:

```text
build/aptos/counter/
  Move.toml
  sources/counter.move
  tests/counter_tests.move
```

First POC:

- `init(account: &signer)`.
- `increment(account: &signer) acquires Counter`.
- `value(addr: address): u64 acquires Counter`.
- Move unit tests.

Main design risk: Aptos needs correct abilities and `acquires` clauses.
Codegen must understand resource access, not patch strings after the fact.

## Portable IR Requirements For Move

The IR must encode:

- which structs are persistent resources or objects
- ownership mode
- entrypoint mutability
- abort codes
- access paths
- event definitions
- ability requirements
- target-specific package address/module names

Move backend should fail early when IR asks for unsupported behavior.

Examples:

```text
error: move-sui cannot lower implicit contract storage `balances`
hint: declare a Sui object or dynamic field mapping

error: move-aptos resource `Counter` is mutated but entrypoint has no signer
hint: add signer/account capability to the entrypoint
```

## Sui vs Aptos First

Aptos is probably easier for the first generated package because account
resources are closer to a traditional storage cell. Sui is strategically more
important for testing the abstraction because its object model is further from
EVM.

Suggested sequence:

1. Aptos counter resource POC.
2. Sui counter object POC.
3. Compare the IR deltas.
4. Promote the cleaner path to the first experimental Move target.

## Open Questions

- Should Move package generation be implemented in Lean, Zig, or a small
  standalone generator?
- Should generated Move expose public view functions, entry functions, or both?
- How should generic assets map to `Coin<T>` on Sui and Aptos?
- How much of Move's ability system should be modeled in the portable IR?
- Should source generation preserve comments back to Lean definitions?
