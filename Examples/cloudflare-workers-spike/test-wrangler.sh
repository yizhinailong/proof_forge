#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

wrangler dev --local --port 8787 > /tmp/wrangler-test.log 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT

for i in {1..30}; do
  if curl -s http://localhost:8787/count >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

echo "--- initialize ---"
curl -s -X POST http://localhost:8787/initialize
echo
echo "--- increment ---"
curl -s -X POST http://localhost:8787/increment
echo
echo "--- count ---"
curl -s http://localhost:8787/count
echo
