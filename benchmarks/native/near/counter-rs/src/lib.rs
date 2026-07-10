// Native NEAR Counter — hand-written near-sdk-rs reference for benchmark comparison.
// Mirrors ProofForge Counter: initialize → increment → get.
//
// Build (requires near-sdk-rs + wasm32-unknown-unknown target):
//   cargo build --manifest-path benchmarks/native/near/counter-rs/Cargo.toml \
//     --target wasm32-unknown-unknown --release
//
// Behavior oracle: near-sandbox or offline-host. See benchmarks/README.md.

use near_sdk::near;

#[near(contract_state)]
#[derive(Default)]
pub struct Counter {
    count: u64,
}

#[near]
impl Counter {
    pub fn initialize(&mut self) {
        self.count = 0;
    }

    pub fn increment(&mut self) {
        self.count += 1;
    }

    pub fn get(&self) -> u64 {
        self.count
    }
}
