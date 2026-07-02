# Solana sBPF Examples

This directory contains self-contained examples for the canonical Solana route
`solana-sbpf-asm` (D-026): direct sBPF assembly codegen from the portable IR,
assembled and linked by the [blueshift-gg/sbpf](https://github.com/blueshift-gg/sbpf)
toolchain.

## `Counter.lean`

A minimal counter program in portable IR with three entrypoints:

- `initialize` — writes `0` to the single scalar `count` account field.
- `increment` — reads `count`, adds one, and writes it back.
- `get` — returns `count` through `sol_set_return_data`.

The example is compiled by the same backend fixture used by
`--emit-counter-ir-sbpf`. Running that command also writes a `manifest.toml`
sidecar describing the instruction tags and the single writable account owned
by the program.

```sh
lake env proof-forge --emit-counter-ir-sbpf \
  -o build/solana/Counter.s \
  --artifact-output build/solana/proof-forge-artifact.json
```

To build the Solana ELF (requires `sbpf` on `PATH`):

```sh
lake env proof-forge --solana-elf -o build/solana/Counter.so
```

The runtime half is exercised by `scripts/solana/counter-smoke.sh`, which
scaffolds an sbpf project from the emitted `.s`, builds the ELF, and runs the
Mollusk test harness.
