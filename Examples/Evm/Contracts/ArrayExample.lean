/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable ArrayExample for the unified EVM entry path.

Demonstrates local fixed-array literals, element access, and reductions
without the legacy Lean.Evm SDK.
-/
import ProofForge.Contract.Builder

namespace ArrayExample

open ProofForge.Contract.Builder
open ProofForge.IR

def sampleArray : Expr :=
  .arrayLit .u64 #[u64 10, u64 20, u64 30]

def spec : ProofForge.Contract.ContractSpec :=
  build "ArrayExample" do
    entryReturns "sizeOf3" .u64 do
      letBind "xs" (.fixedArray .u64 3) sampleArray
      ret (u64 3)

    entryReturns "getElem" .u64 do
      letBind "xs" (.fixedArray .u64 3) sampleArray
      ret (.arrayGet (.local "xs") (u64 1))

    entryReturns "sumOf3" .u64 do
      letBind "xs" (.fixedArray .u64 3) sampleArray
      ret (
        .add
          (.add (.arrayGet (.local "xs") (u64 0)) (.arrayGet (.local "xs") (u64 1)))
          (.arrayGet (.local "xs") (u64 2))
      )

def module : ProofForge.IR.Module :=
  spec.module

end ArrayExample
