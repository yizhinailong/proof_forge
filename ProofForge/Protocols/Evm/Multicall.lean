/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer B — EVM Multicall3 external client

CALL wrappers for a deployed Multicall3, backed by **`Evm.AbiEncode`** for
`Call[]` / `Call3[]` argument layouts (not hand-rolled offsets).

Selectors (canonical Multicall3):
- `aggregate((address,bytes)[])` → `0x252dba42`
- `tryAggregate(bool,(address,bytes)[])` → `0xbce38bd7`
- `aggregate3((address,bool,bytes)[])` → `0x82ad56cb`

## Two surfaces

1. **Layout planning** (complete for static Call arrays):
   `encodeAggregate` / `encodeAggregate3` → `AbiEncode.Plan`
2. **Portable remote** (scalar-bounded smoke path):
   `aggregate` still uses `remoteCall` with scalar words for handle wiring;
   full flat calldata inject into Yul is a follow-on (Plan → mstore).
-/
import ProofForge.Contract.Surface
import ProofForge.Backend.Evm.AbiEncode

namespace ProofForge.Protocols.Evm.Multicall

open ProofForge.Contract.Surface
open ProofForge.Backend.Evm.AbiEncode

def catalogId : String := "protocols.evm.multicall"

def selectorAggregate : Nat := 0x252dba42
def selectorTryAggregate : Nat := 0xbce38bd7
def selectorAggregate3 : Nat := 0x82ad56cb

structure Multicall where
  target : ProofForge.IR.Expr
  deriving Repr

def declareMulticall (peerId : String) : ModuleM Multicall := do
  let tIdx ← ProofForge.Contract.Builder.ensureCrosscallString peerId
  pure { target := peerHandle tIdx }

/-- Build inner call data = selector ‖ static arg words. -/
def innerCallData (selector : Nat) (argWords : Array Nat := #[]) : Array Nat :=
  callDataFromSelectorArgs selector argWords

/-- One Multicall `Call`. -/
def mkCall (target : Nat) (data : Array Nat) : Call :=
  { target := target, data := data }

/-- One Multicall3 `Call3`. -/
def mkCall3 (target : Nat) (allowFailure : Bool) (data : Array Nat) : Call3 :=
  { target := target, allowFailure := allowFailure, data := data }

/-- ABI plan for `aggregate` args (uses JsonEncode-analogue `AbiEncode`). -/
def encodeAggregate (calls : Array Call) : Plan :=
  encodeAggregateArgs calls

/-- ABI plan for `aggregate3` args. -/
def encodeAggregate3 (calls : Array Call3) : Plan :=
  encodeAggregate3Args calls

/-- Portable scalar CALL (handle wiring / smoke). Prefer `encodeAggregate` for
real Call[] layouts. -/
def aggregate (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorAggregate) args

def tryAggregate (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorTryAggregate) args

def aggregate3 (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorAggregate3) args

end ProofForge.Protocols.Evm.Multicall
