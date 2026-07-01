/-! Allocator abstraction for the ProofForge IR.

The IR is target-agnostic; how composite values (arrays, structs, path
temporaries) are allocated in the target's address space is a *strategy* chosen
per-module, not a hardcoded runtime detail. Every backend (EmitWat, Psy, …)
reads `Module.allocator` and lowers the matching allocator helpers.

## Two families

* **No-free** (`bump`, `bumpReset`): `dealloc` is a no-op. These match the
  current IR, which has no explicit release/scope semantics — allocated
  temporaries are never freed, so any reuse-capable allocator would degrade to
  a slower bump (metadata overhead with nowhere to reclaim).
  - `bump`      — linear frontier, no reset. Cheapest; can accumulate across calls.
  - `bumpReset` — bump + reset the frontier to `heapBase` at each entrypoint
                  boundary. Zero-cost leak prevention for long-lived instances.

* **Reuse-capable** (`external`, `jemalloc`, `weeAlloc`, `mimalloc`): `alloc` +
  `dealloc` are paired. These require the IR to have release/scope semantics
  (a future addition) for `dealloc` to have call sites; without it they degrade
  to bump. The lowering is host-provided:
  - EmitWat (wasm) cannot embed a C allocator, so it imports `pf_alloc` +
    `pf_dealloc` and the host instantiates the chosen implementation. The NEAR
    runtime does NOT export these, so reuse-capable strategies are NOT
    chain-deployable — they target offline simulators / the Psy backend.
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
      by the harness; no specific library implied). -/
  | external
  /-- Reuse-capable: host should provide a jemalloc-backed implementation. -/
  | jemalloc
  /-- Reuse-capable: host should provide a wee_alloc-backed implementation. -/
  | weeAlloc
  /-- Reuse-capable: host should provide a mimalloc-backed implementation. -/
  | mimalloc
  deriving Repr, BEq

/-- Human-readable id for diagnostics / config output. -/
def AllocatorStrategy.id : AllocatorStrategy → String
  | .bump => "alloc.bump"
  | .bumpReset => "alloc.bump_reset"
  | .external => "alloc.external"
  | .jemalloc => "alloc.jemalloc"
  | .weeAlloc => "alloc.wee_alloc"
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
  | .external | .jemalloc | .weeAlloc | .mimalloc => true
  | _ => false

/-- True for no-free strategies: `dealloc` is a no-op and no host import is
    needed. These are chain-deployable. -/
def AllocatorConfig.isBumpLike : AllocatorConfig → Bool :=
  fun cfg => !cfg.requiresHost

end ProofForge.IR