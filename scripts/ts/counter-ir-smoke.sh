#!/usr/bin/env bash
set -euo pipefail

# Generate TypeScript source from the hand-written portable Counter IR and
# validate it with the TypeScript compiler.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${TS_OUT_DIR:-$ROOT/build/ts}"
TS_FILE="$OUT_DIR/Counter.ts"
TSC_BIN="${TSC:-tsc}"

mkdir -p "$OUT_DIR"

lake build proof-forge >/dev/null
"$ROOT/.lake/build/bin/proof-forge" emit --target wasm-cloudflare-workers --fixture counter --format ts -o "$TS_FILE"

# Minimal Cloudflare Workers type stubs so the generated module type-checks
# without requiring @cloudflare/workers-types to be installed globally.
cat > "$OUT_DIR/workers-types.d.ts" <<'EOF'
interface KVNamespace {
  get(key: string): Promise<string | null>;
  put(key: string, value: string): Promise<void>;
}
interface ExecutionContext {
  waitUntil(promise: Promise<any>): void;
  passThroughOnException(): void;
}
declare class Request {
  constructor(input: string | Request, init?: any);
  readonly url: string;
  readonly method: string;
}
declare class URL {
  constructor(url: string, base?: string);
  readonly pathname: string;
}
declare class Response {
  constructor(body?: string, init?: { status?: number });
}
interface ExportedHandler {
  fetch(request: Request, env: any, ctx: ExecutionContext): Promise<Response>;
}
EOF

cat > "$OUT_DIR/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["Counter.ts", "workers-types.d.ts"]
}
EOF

# Copy deployment templates next to the generated worker.
cp "$ROOT/Examples/Backend/CloudflareWorkers/Counter/wrangler.toml" "$OUT_DIR/wrangler.toml"
cp "$ROOT/Examples/Backend/CloudflareWorkers/Counter/package.json" "$OUT_DIR/package.json"

"$TSC_BIN" --project "$OUT_DIR" --noEmit

# Validate that wrangler can package the worker for deployment.
wrangler deploy --dry-run --config "$OUT_DIR/wrangler.toml"

echo "ts-counter-smoke: wrote $TS_FILE"
echo "ts-counter-smoke: TypeScript type-check passed"
echo "ts-counter-smoke: wrangler dry-run passed"
