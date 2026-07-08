/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Portable crosscall → Solana CPI materialization (Phase B.3)

Authors write portable `crosscall.invoke` (target program id / method / args as
u64-shaped values). Solana does not expose that as EVM CALL; it materializes as
CPI-shaped execution:

* Instruction data: little-endian method tag (u64) followed by packed u64 args
* Program account: runtime account index = `target` (must be an executable
  program account in the transaction account list)
* Result: first 8 bytes of `sol_get_return_data` if present, else 0

Account list auto-extension (module-level schema): when portable crosscall is
detected, the materializer ensures a placeholder `callee_program` executable
account is available for CPI program-id lookup by index (authors still do not
write `cpi` DSL — the runtime passes the callee as an extra account).
-/
import ProofForge.IR.Contract
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.Extension.Types

namespace ProofForge.Backend.Solana.PortableCrosscall

open ProofForge.IR
open ProofForge.Backend.Solana.Manifest
open ProofForge.Backend.Solana.Extension

structure PortableCrosscallSite where
  entrypoint : String
  argCount : Nat
  deriving Repr

partial def collectFromExpr (entrypoint : String) (acc : Array PortableCrosscallSite) :
    Expr → Array PortableCrosscallSite
  | .crosscallInvoke _ _ args
  | .crosscallInvokeTyped _ _ args _
  | .crosscallInvokeValueTyped _ _ _ args _ =>
      acc.push { entrypoint, argCount := args.size }
  | .crosscallInvokeStaticTyped .. | .crosscallInvokeDelegateTyped ..
  | .crosscallCreate .. | .crosscallCreate2 .. => acc
  | .nearCrosscallInvokePool .. | .nearPromiseThen .. => acc
  | .effect e => collectFromEffect entrypoint acc e
  | .add a b _ | .sub a b _ | .mul a b _ | .div a b | .mod a b | .pow a b
  | .bitAnd a b | .bitOr a b | .bitXor a b | .shiftLeft a b | .shiftRight a b
  | .eq a b | .ne a b | .lt a b | .le a b | .gt a b | .ge a b
  | .boolAnd a b | .boolOr a b | .hashTwoToOne a b =>
      collectFromExpr entrypoint (collectFromExpr entrypoint acc a) b
  | .cast a _ | .boolNot a | .hash a | .memoryArrayLength a | .field a _
  | .nearPromiseResultStatus a | .nearPromiseResultU64 a =>
      collectFromExpr entrypoint acc a
  | .arrayLit _ xs => xs.foldl (fun a e => collectFromExpr entrypoint a e) acc
  | .structLit _ fs => fs.foldl (fun a f => collectFromExpr entrypoint a f.snd) acc
  | .arrayGet a i | .memoryArrayGet a i =>
      collectFromExpr entrypoint (collectFromExpr entrypoint acc a) i
  | .memoryArrayNew _ len => collectFromExpr entrypoint acc len
  | .hashValue a b c d =>
      collectFromExpr entrypoint
        (collectFromExpr entrypoint
          (collectFromExpr entrypoint (collectFromExpr entrypoint acc a) b) c) d
  | .literal _ | .local _ | .nativeValue | .nearPromiseResultsCount => acc
where
  collectFromEffect (entrypoint : String) (acc : Array PortableCrosscallSite) :
      Effect → Array PortableCrosscallSite
    | .storageScalarWrite _ v | .storageScalarAssignOp _ _ v
    | .storageStructFieldWrite _ _ v | .storageDynamicArrayPush _ v =>
        collectFromExpr entrypoint acc v
    | .storageMapContains _ k | .storageMapGet _ k | .storageArrayRead _ k =>
        collectFromExpr entrypoint acc k
    | .storageMapInsert _ k v | .storageMapSet _ k v | .storageArrayWrite _ k v
    | .storageArrayStructFieldWrite _ k _ v =>
        collectFromExpr entrypoint (collectFromExpr entrypoint acc k) v
    | .memoryArraySet a i v =>
        collectFromExpr entrypoint
          (collectFromExpr entrypoint (collectFromExpr entrypoint acc a) i) v
    | .storagePathRead _ path => path.foldl (fun a s => collectFromPath entrypoint a s) acc
    | .storagePathWrite _ path v | .storagePathAssignOp _ path _ v =>
        collectFromExpr entrypoint (path.foldl (fun a s => collectFromPath entrypoint a s) acc) v
    | .eventEmit _ fs => fs.foldl (fun a f => collectFromExpr entrypoint a f.snd) acc
    | .eventEmitIndexed _ ix data =>
        data.foldl (fun a f => collectFromExpr entrypoint a f.snd)
          (ix.foldl (fun a f => collectFromExpr entrypoint a f.snd) acc)
    | .storageScalarRead _ | .storageStructFieldRead _ _ | .storageDynamicArrayPop _
    | .storageArrayStructFieldRead _ _ _ | .contextRead _ => acc
  collectFromPath (entrypoint : String) (acc : Array PortableCrosscallSite) :
      StoragePathSegment → Array PortableCrosscallSite
    | .field _ => acc
    | .index i | .mapKey i => collectFromExpr entrypoint acc i

partial def collectFromStmt (entrypoint : String) (acc : Array PortableCrosscallSite) :
    Statement → Array PortableCrosscallSite
  | .letBind _ _ v | .letMutBind _ _ v | .return v => collectFromExpr entrypoint acc v
  | .assign a b | .assignOp a _ b | .assertEq a b _ _ =>
      collectFromExpr entrypoint (collectFromExpr entrypoint acc a) b
  | .effect e => collectFromExpr entrypoint acc (.effect e)
  | .assert c _ _ => collectFromExpr entrypoint acc c
  | .ifElse c t e =>
      e.foldl (collectFromStmt entrypoint)
        (t.foldl (collectFromStmt entrypoint) (collectFromExpr entrypoint acc c))
  | .boundedFor _ _ _ body => body.foldl (collectFromStmt entrypoint) acc
  | .whileLoop c body =>
      body.foldl (collectFromStmt entrypoint) (collectFromExpr entrypoint acc c)
  | .revert _ | .revertWithError _ | .release _ => acc

def collectSites (module : Module) : Array PortableCrosscallSite :=
  module.entrypoints.foldl
    (fun acc ep => ep.body.foldl (collectFromStmt ep.name) acc)
    #[]

def moduleHasPortableCrosscall (module : Module) : Bool :=
  !(collectSites module).isEmpty

/-- Ensure a `callee_program` executable account exists when portable crosscall
is used so CPI program-id can be resolved by account index. -/
def ensureCalleeProgramAccount (module : Module) (accounts : Array AccountEntry) :
    Array AccountEntry :=
  if !moduleHasPortableCrosscall module then
    accounts
  else if accounts.any (fun a => a.name == "callee_program") then
    accounts
  else
    pushAccount accounts {
      name := "callee_program"
      index := 0
      signer := false
      writable := false
      owner := "executable"
    }

def materializationNote (module : Module) : String :=
  let sites := collectSites module
  if sites.isEmpty then
    "no portable crosscall sites"
  else
    s!"portable crosscall.invoke ×{sites.size} → Solana CPI materialization (method u64 + args as ix data; program account by index)"

end ProofForge.Backend.Solana.PortableCrosscall
