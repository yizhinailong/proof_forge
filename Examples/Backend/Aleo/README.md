# Aleo backend fixtures

| File | Role |
|------|------|
| `Counter.golden.leo` | Road 1 Leo sourcegen golden |
| `Counter.golden.aleo` | Z2 Aleo Instructions golden (`leo build` of Counter.leo) |
| `PureMath.golden.leo` | Pure-math Leo fixture |

Regenerate `.aleo` golden:

```sh
mkdir -p build/aleo/z2-counter-golden/src
cp Examples/Backend/Aleo/Counter.golden.leo build/aleo/z2-counter-golden/src/main.leo
printf '{"program":"counter.aleo","version":"0.1.0","description":"","license":"Apache-2.0"}\n' \
  > build/aleo/z2-counter-golden/program.json
(cd build/aleo/z2-counter-golden && leo build)
cp build/aleo/z2-counter-golden/build/main.aleo Examples/Backend/Aleo/Counter.golden.aleo
```

Gate: `just aleo-aleo-goldens` / `just aleo-instructions-direct`
