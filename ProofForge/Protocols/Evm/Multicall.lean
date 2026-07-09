/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer B — EVM Multicall3 external client

Thin CALL wrappers for a deployed Multicall3 (MakerDAO-style aggregate).
Not a full ABI encoder for nested Call3 structs — **scalar-bounded** helpers
only; complex aggregate packing remains host/materialize work.

Selectors (canonical Multicall3):
- `aggregate((address,bytes)[])` → `0x252dba42`
- `tryAggregate(bool,(address,bytes)[])` → `0xbce38bd7`
- `aggregate3((address,bool,bytes)[])` → `0x82ad56cb`
-/
import ProofForge.Contract.Surface

namespace ProofForge.Protocols.Evm.Multicall

open ProofForge.Contract.Surface

def catalogId : String := "protocols.evm.multicall"

/-- `aggregate((address,bytes)[])` -/
def selectorAggregate : Nat := 0x252dba42
/-- `tryAggregate(bool,(address,bytes)[])` -/
def selectorTryAggregate : Nat := 0xbce38bd7
/-- `aggregate3((address,bool,bytes)[])` -/
def selectorAggregate3 : Nat := 0x82ad56cb

structure Multicall where
  target : ProofForge.IR.Expr
  deriving Repr

def declareMulticall (peerId : String) : ModuleM Multicall := do
  let tIdx ← ProofForge.Contract.Builder.ensureCrosscallString peerId
  pure { target := peerHandle tIdx }

/-- CALL Multicall3.aggregate — `args` are portable scalar words only (honest bound).
Full nested Call[] ABI is **not** claimed; use for smoke / handle wiring. -/
def aggregate (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorAggregate) args

def tryAggregate (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorTryAggregate) args

def aggregate3 (m : Multicall) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCall m.target (u64 selectorAggregate3) args

end ProofForge.Protocols.Evm.Multicall
