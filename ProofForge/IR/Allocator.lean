/-! Allocator abstraction for the ProofForge IR.

The IR is target-agnostic; how composite values (arrays, structs, path
temporaries) are allocated in the target's address space is a *strategy* chosen
per-module, not a hardcoded runtime detail. Every backend (EmitWat, Psy, …)
reads `Module.allocator` and lowers the matching allocator helpers.

## Strategy families

* **No-free** (`bump`, `bumpReset`): `dealloc` is a no-op. These match the
  current IR, which has no explicit release/scope semantics — allocated
  temporaries are never freed, so any reuse-capable allocator would degrade to
  a slower bump (metadata overhead with nowhere to reclaim).
  - `bump`      — linear frontier, no reset. Cheapest; can accumulate across calls.
  - `bumpReset` — bump + reset the frontier to `heapBase` at each entrypoint
                  boundary. Zero-cost leak prevention for long-lived instances.

* **Wasm-internal reuse** (`minimalMalloc`): EmitWat generates allocator code
  inside the wasm module, matching the NEAR/Rust model where the allocator runs
  in wasm linear memory and grows memory with `memory.grow`. This is not the
  Rust `wee_alloc` crate; it is ProofForge's direct-WAT allocator with the same
  placement model. `dealloc` can reuse blocks once the IR grows release/scope
  semantics.

* **Imported reuse** (`external`, `jemalloc`, `mimalloc`): `alloc` + `dealloc`
  are paired through an allocator ABI. These require the IR to have
  release/scope semantics (a future addition) for `dealloc` to have call sites;
  without it they degrade to bump. The lowering uses an allocator ABI:
  - EmitWat (wasm) imports `pf_alloc` + `pf_dealloc`. `pf_alloc` must return an
    offset in the module's wasm linear memory, never a native host pointer. The
    offline host can manage that linear memory directly for simulation, but a
    real C allocator such as jemalloc must be compiled into wasm and linked into
    the same address space. The NEAR runtime does NOT export these imports, so
    imported reuse strategies are NOT chain-deployable there.
  - Psy (C++) can link the real library (jemalloc / mimalloc / …) directly.
  - A chain-only backend must reject these (or fall back to an internal
    free-list once the IR has free semantics).

`AllocatorConfig.requiresHost` distinguishes the host-provided strategies so
backends can decide import-vs-internal and chain-deployability in one place. -/

namespace ProofForge.IR

inductive AllocatorStrategy where
  /-- No-free: linear frontier, no reset. -/
  | bump
  /-- No-free: linear frontier, reset to `heapBase` at each entrypoint boundary. -/
  | bumpReset
  /-- Reuse-capable: generic host-provided alloc+dealloc (implementation chosen
      by an offline harness; `alloc` returns a wasm linear-memory offset). -/
  | external
  /-- Reuse-capable: intended for a wasm-linked jemalloc implementation. Until
      that exists, offline hosts may simulate the ABI with a linear-memory bump
      allocator. -/
  | jemalloc
  /-- Wasm-internal first-fit allocator for direct WAT output. This follows the
      same placement model as NEAR's Rust/wee_alloc setup: allocator code lives
      in the wasm module and returns linear-memory offsets. -/
  | minimalMalloc
  /-- Reuse-capable: host should provide a mimalloc-backed implementation. -/
  | mimalloc
  deriving Repr, BEq

/-- Human-readable id for diagnostics / config output. -/
def AllocatorStrategy.id : AllocatorStrategy → String
  | .bump => "alloc.bump"
  | .bumpReset => "alloc.bump_reset"
  | .external => "alloc.external"
  | .jemalloc => "alloc.jemalloc"
  | .minimalMalloc => "alloc.minimal_malloc"
  | .mimalloc => "alloc.mimalloc"

/-- Per-module allocator configuration. Backends read `strategy` to emit the
    matching alloc/dealloc helpers and `heapBase` as the linear-memory base for
    the bump region (ignored by host-provided strategies). -/
structure AllocatorConfig where
  strategy : AllocatorStrategy := .bump
  heapBase : Nat := 60000
  deriving Repr

/-- Default configuration: a plain bump allocator at offset 60000. -/
def defaultAllocator : AllocatorConfig := {  }

/-- True for host-provided (reuse-capable) strategies: the backend must supply
    alloc/dealloc via import (EmitWat) or linking (Psy), and the result is not
    chain-deployable on NEAR. -/
def AllocatorConfig.requiresHost : AllocatorConfig → Bool :=
  fun cfg => match cfg.strategy with
  | .external | .jemalloc | .mimalloc => true
  | _ => false

/-- True for strategies whose allocator is emitted inside the wasm module and
    therefore need no host allocator import. These are chain-deployable on NEAR. -/
def AllocatorConfig.isWasmInternal : AllocatorConfig → Bool :=
  fun cfg => !cfg.requiresHost

end ProofForge.IR
