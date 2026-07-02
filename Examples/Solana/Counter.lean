/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

A minimal Solana counter program expressed directly in the portable IR.
This is the self-contained Phase 1 example for the `solana-sbpf-asm` route:
there is no Solana-specific surface syntax yet, so the example builds the
`ProofForge.IR.Contract.Module` that the sBPF backend lowers to `.s`.

Compile to sBPF assembly:
  lake env proof-forge --emit-counter-ir-sbpf \
    -o build/solana/Counter.s \
    --artifact-output build/solana/proof-forge-artifact.json

The command above emits the same shape as this example because the backend's
Phase 1 fixture mirrors this module. A `manifest.toml` is written alongside
the `.s` describing the instruction dispatch and the single writable account.

Build the Solana ELF (requires `sbpf` on PATH):
  lake env proof-forge --solana-elf -o build/solana/Counter.so
-/

import ProofForge.IR.Contract

namespace Examples.Solana.Counter

open ProofForge.IR

def stateCount : StateDecl := {
  id := "count"
  kind := .scalar
  type := .u64
}

def initializeEntrypoint : Entrypoint := {
  name := "initialize"
  selector? := some "8129fc1c"
  returns := .unit
  body := #[
    .effect (.storageScalarWrite "count" (.literal (.u64 0)))
  ]
}

def incrementEntrypoint : Entrypoint := {
  name := "increment"
  selector? := some "d09de08a"
  returns := .unit
  body := #[
    .letBind "n" .u64 (.effect (.storageScalarRead "count")),
    .effect (.storageScalarWrite "count" (.add (.local "n") (.literal (.u64 1))))
  ]
}

def getEntrypoint : Entrypoint := {
  name := "get"
  selector? := some "6d4ce63c"
  returns := .u64
  body := #[
    .return (.effect (.storageScalarRead "count"))
  ]
}

def module : Module := {
  name := "Counter"
  state := #[stateCount]
  entrypoints := #[initializeEntrypoint, incrementEntrypoint, getEntrypoint]
}

end Examples.Solana.Counter