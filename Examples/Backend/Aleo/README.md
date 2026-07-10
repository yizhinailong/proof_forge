# Aleo Examples

This directory contains golden fixtures for the Aleo Leo sourcegen backend.

## Files

- `PureMath.golden.leo` — executable pure-fragment output for
  `proof-forge emit --target aleo-leo --fixture pure-math --format leo`.

The full portable Counter intentionally has no Leo golden: Leo 4.0.2 cannot
surface its mapping-backed `get() -> U64` result from `final`, so the backend
fails closed instead of emitting an ABI-incompatible `get() -> Final`.

## Updating the golden fixture

After changing the Aleo backend, regenerate the fixture through the target-first
CLI:

```bash
lake build
./.lake/build/bin/proof-forge emit --target aleo-leo --fixture pure-math --format leo -o build/aleo/PureMath.leo
cp build/aleo/PureMath.leo Examples/Backend/Aleo/PureMath.golden.leo
```

Then review the diff before committing.
