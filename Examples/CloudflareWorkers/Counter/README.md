# ProofForge Counter on Cloudflare Workers

This example deploys the portable `Counter` IR fixture as a Cloudflare Worker
backed by a KV namespace.

## Generate

```bash
lake build
.lake/build/bin/proof-forge --emit-counter-ir-ts -o Examples/CloudflareWorkers/Counter/Counter.ts
```

Or use the smoke test script, which also type-checks and runs a wrangler dry-run:

```bash
bash scripts/ts/counter-ir-smoke.sh
```

## Deploy

1. Create a KV namespace in your Cloudflare account and replace the placeholder
   IDs in `wrangler.toml`.
2. Run `wrangler deploy` from this directory.

## Endpoints

- `POST /initialize` — reset the counter to zero.
- `POST /increment` — increment the counter.
- `GET /get` — read the current counter value.
