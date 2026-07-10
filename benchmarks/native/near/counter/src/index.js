// Native NEAR Counter — hand-written near-sdk-js reference for benchmark comparison.
// Mirrors ProofForge Counter: initialize → increment → get.
//
// Build (requires near-sdk-js):
//   cd benchmarks/native/near/counter && npm install && npm run build
//
// Behavior oracle: near-sandbox or offline-host. See benchmarks/README.md.

import { NearBindgen, call, view, initialize } from 'near-sdk-js';

@NearBindgen({})
class Counter {
  count = BigInt(0);

  @initialize({})
  initialize() {
    this.count = BigInt(0);
  }

  @call({})
  increment() {
    this.count = this.count + BigInt(1);
  }

  @view({})
  get() {
    return this.count.toString();
  }
}
