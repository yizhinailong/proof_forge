# Aleo Examples

This directory contains golden fixtures for the Aleo Leo sourcegen backend.

## Files

- `Counter.golden.leo` — expected output of
  `proof-forge emit --target aleo-leo --fixture counter --format leo` for the
  portable IR `Counter` module (`ProofForge.IR.Examples.Counter`).

## Updating the golden fixture

After changing the Aleo backend, regenerate the fixture through the target-first
CLI:

```bash
lake build
./.lake/build/bin/proof-forge emit --target aleo-leo --fixture counter --format leo -o build/aleo/Counter.leo
cp build/aleo/Counter.leo Examples/Backend/Aleo/Counter.golden.leo
```

Then review the diff before committing.
