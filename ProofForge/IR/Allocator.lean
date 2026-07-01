/-! Allocator abstraction for the ProofForge IR.

The IR is target-agnostic; how composite values (arrays, structs, path
temporaries) are allocated in the target's linear address space is a *strategy*
chosen per-module, not a hardcoded runtime detail. Every backend (EmitWat,
Psy, …) reads `Module.allocator` and lowers the matching allocator helpers.

Strategies:
* `bump`      — linear bump pointer; no free, no reset. Cheapest (O(1)),
                safe for short-lived instances; can accumulate across calls.
* `bumpReset` — bump + reset the pointer to `heapBase` at each entrypoint
                boundary. Zero-cost leak prevention for long-lived instances.
* `external`  — the host provides `pf_alloc(n : i64) → i32` via import. Used
                by offline simulators / test harnesses (the NEAR runtime does
                not expose this, so `external` is not chain-deployable). -/

namespace ProofForge.IR

inductive AllocatorStrategy where
  | bump
  | bumpReset
  | external
  deriving Repr, BEq

/-- Per-module allocator configuration. Backends read `strategy` to emit the
    matching alloc helper(s) and `heapBase` as the linear-memory base for the
    bump region (ignored by `external`). -/
structure AllocatorConfig where
  strategy : AllocatorStrategy := .bump
  heapBase : Nat := 60000
  deriving Repr

/-- Default configuration: a plain bump allocator at offset 60000. -/
def defaultAllocator : AllocatorConfig := {  }

end ProofForge.IR