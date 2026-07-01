/-! Allocator abstraction for the ProofForge IR.

The IR is target-agnostic; how composite values (arrays, structs, path
temporaries) are allocated in the target's address space is a mode chosen
per-module, not a hardcoded runtime detail. Every backend (EmitWat, Psy, …)
reads `Module.allocator` and lowers the matching allocator helpers.

## Strategy families

* **No-free deployment** (`bump`, `bumpReset`): `dealloc` is a no-op. These are
  useful when a module has no explicit `release` statements, because allocated
  temporaries are never freed and any reuse-capable allocator would degrade to
  a slower bump.
  - `bump`      — linear frontier, no reset. Cheapest; can accumulate across calls.
  - `bumpReset` — bump + reset the frontier to `heapBase` at each entrypoint
                  boundary. Zero-cost leak prevention for long-lived instances.

* **Chain deployment reuse** (`nearWeeModel`, `minimalMalloc`,
  `cosmWasmRegion`): the allocator is part of the final chain artifact. NEAR's
  Rust SDK path links `wee_alloc` into the final wasm; EmitWat's direct-WAT
  equivalent is generated wasm allocator code that returns linear-memory
  offsets and grows memory with `memory.grow`. `cosmWasmRegion` is the
  chain-specific allocate/deallocate export ABI used by CosmWasm adapters.
  Backends that support `Statement.release` lower it to the matching
  deallocator; unsupported backends reject release explicitly.

* **Offline experiments** (`hostBump`, `hostJemallocShape`,
  `hostMimallocShape`): `alloc` + `dealloc` are paired through an imported
  allocator ABI and are not chain-deployable on NEAR. These are for local
  simulation or wasm-link experiments only.
  - EmitWat (wasm) imports `pf_alloc` + `pf_dealloc`. `pf_alloc` must return an
    offset in the module's wasm linear memory, never a native host pointer. The
    offline host can manage that linear memory directly for simulation.
  - A real C allocator such as jemalloc must be compiled into wasm and linked
    into the same address space before it can be used by guest wasm.
  - Psy (C++) can link the real library (jemalloc / mimalloc / …) directly.

`AllocatorConfig.requiresHost` distinguishes offline imported allocators so
backends can decide import-vs-internal and chain-deployability in one place. -/

namespace ProofForge.IR

inductive ChainAllocator where
  /-- No-free: linear frontier, no reset. -/
  | bump
  /-- No-free: linear frontier, reset to `heapBase` at each entrypoint boundary. -/
  | bumpReset
  /-- NEAR deployment model: allocator lives in the final wasm artifact. In Rust
      sourcegen this maps to near-sdk's default `wee_alloc`; in direct WAT it
      lowers to ProofForge's wasm-internal allocator shape. -/
  | nearWeeModel
  /-- Wasm-internal first-fit allocator for direct WAT output. -/
  | minimalMalloc
  /-- CosmWasm deployment ABI: exported `allocate`/`deallocate` region allocator. -/
  | cosmWasmRegion
  deriving Repr, BEq

/-- Offline-only allocator experiments. These are not chain deployment
    strategies unless the allocator is linked into the final artifact. -/
inductive ExperimentAllocator where
  | hostBump
  | hostJemallocShape
  | hostMimallocShape
  deriving Repr, BEq

inductive AllocatorMode where
  | chainDeployment (allocator : ChainAllocator)
  | offlineExperiment (allocator : ExperimentAllocator)
  deriving Repr, BEq

def ChainAllocator.id : ChainAllocator → String
  | .bump => "alloc.bump"
  | .bumpReset => "alloc.bump_reset"
  | .nearWeeModel => "alloc.near_wee_model"
  | .minimalMalloc => "alloc.minimal_malloc"
  | .cosmWasmRegion => "alloc.cosmwasm_region"

def ExperimentAllocator.id : ExperimentAllocator → String
  | .hostBump => "alloc.offline.host_bump"
  | .hostJemallocShape => "alloc.offline.host_jemalloc_shape"
  | .hostMimallocShape => "alloc.offline.host_mimalloc_shape"

/-- Human-readable id for diagnostics / config output. -/
def AllocatorMode.id : AllocatorMode → String
  | .chainDeployment allocator => allocator.id
  | .offlineExperiment allocator => allocator.id

/-- Per-module allocator configuration. Backends read `mode` to emit the
    matching alloc/dealloc helpers and `heapBase` as the linear-memory base for
    the bump region (ignored by host-provided strategies). -/
structure AllocatorConfig where
  mode : AllocatorMode := .chainDeployment .bump
  heapBase : Nat := 60000
  deriving Repr

/-- Default configuration: a plain bump allocator at offset 60000. -/
def defaultAllocator : AllocatorConfig := {  }

/-- Backward-compatible shorthand for diagnostics and metadata. -/
def AllocatorConfig.id (cfg : AllocatorConfig) : String :=
  cfg.mode.id

/-- True for offline imported allocator experiments: the backend must supply
    alloc/dealloc via imports. These are not chain-deployable on NEAR. -/
def AllocatorConfig.requiresHost : AllocatorConfig → Bool :=
  fun cfg => match cfg.mode with
  | .offlineExperiment _ => true
  | .chainDeployment _ => false

/-- True for strategies whose allocator is emitted inside the wasm module and
    therefore need no host allocator import. These are chain-deployable on NEAR. -/
def AllocatorConfig.isWasmInternal : AllocatorConfig → Bool :=
  fun cfg => !cfg.requiresHost

def AllocatorConfig.chainAllocator? (cfg : AllocatorConfig) : Option ChainAllocator :=
  match cfg.mode with
  | .chainDeployment allocator => some allocator
  | .offlineExperiment _ => none

def AllocatorConfig.experimentAllocator? (cfg : AllocatorConfig) : Option ExperimentAllocator :=
  match cfg.mode with
  | .offlineExperiment allocator => some allocator
  | .chainDeployment _ => none

def AllocatorConfig.usesEntryReset (cfg : AllocatorConfig) : Bool :=
  cfg.chainAllocator? == some .bumpReset

def AllocatorConfig.usesMinimalMallocShape (cfg : AllocatorConfig) : Bool :=
  match cfg.chainAllocator? with
  | some .nearWeeModel | some .minimalMalloc => true
  | _ => false

def AllocatorConfig.isCosmWasmRegion (cfg : AllocatorConfig) : Bool :=
  cfg.chainAllocator? == some .cosmWasmRegion

def AllocatorConfig.isOfflineJemallocShape (cfg : AllocatorConfig) : Bool :=
  cfg.experimentAllocator? == some .hostJemallocShape

end ProofForge.IR
