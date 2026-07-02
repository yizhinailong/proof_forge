# Aleo Examples

This directory contains golden fixtures for the Aleo Leo sourcegen backend.

## Files

- `Counter.golden.leo` — expected output of `proof-forge --emit-counter-ir-leo`
  for the portable IR `Counter` module (`ProofForge.IR.Examples.Counter`).

## Updating the golden fixture

After changing the Aleo backend, regenerate the fixture:

```bash
lake build
./.lake/build/bin/proof-forge --emit-counter-ir-leo -o build/aleo/Counter.leo
cp build/aleo/Counter.leo Examples/Aleo/Counter.golden.leo
```

Then review the diff before committing.
