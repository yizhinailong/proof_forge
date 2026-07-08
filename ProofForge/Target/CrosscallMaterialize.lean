/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Crosscall materialization (portable intent → native form)

Authors never write CPI metas, Promise chains, or STATICCALL opcodes in the
portable path. They express **business** cross-contract intent
(`crosscall.invoke` capability / portable IR crosscall nodes). Each target
materializes that intent into its native call model:

| Target family | Native form of portable `crosscall.invoke` |
|---|---|
| EVM | CALL (typed variants may map to STATICCALL/DELEGATECALL only via extension) |
| Solana | CPI frame (`crosscall.cpi` + account metas synthesized by plan) |
| Wasm-NEAR | host cross-contract call / Promise (async) |
| Wasm-CosmWasm | WasmMsg / submessage |
| Wasm-Cloudflare | HTTP/service binding call (off-chain reinterpretation) |
| Move Aptos/Sui | entry function call / object call (spike-level) |
| Psy / Aleo | circuit / transition call (restricted; often reject full async) |

This module is the product vocabulary for that mapping. Full async Promise /
CPI packing remains in backends; here we expose an auditable, target-keyed
report so operators see how portable crosscall is realized.
-/
import ProofForge.IR.Contract
import ProofForge.Target.Registry
import ProofForge.Target.Capability

namespace ProofForge.Target.CrosscallMaterialize

open ProofForge.IR
open ProofForge.Target

/-- Native realization of portable cross-contract intent. -/
inductive NativeForm where
  | evmCall
  | solanaCpi
  | nearPromise
  | cosmWasmMsg
  | workersBinding
  | moveCall
  | zkCircuitCall
  | unsupported
  deriving BEq, DecidableEq, Repr

def NativeForm.id : NativeForm → String
  | .evmCall => "evm-call"
  | .solanaCpi => "solana-cpi"
  | .nearPromise => "near-promise"
  | .cosmWasmMsg => "cosmwasm-msg"
  | .workersBinding => "workers-binding"
  | .moveCall => "move-call"
  | .zkCircuitCall => "zk-circuit-call"
  | .unsupported => "unsupported"

def NativeForm.describe : NativeForm → String
  | .evmCall => "EVM CALL (portable crosscall.invoke)"
  | .solanaCpi => "Solana CPI (crosscall.cpi + synthesized account metas)"
  | .nearPromise => "NEAR Promise / host cross-contract call"
  | .cosmWasmMsg => "CosmWasm WasmMsg / submessage"
  | .workersBinding => "Cloudflare Workers service binding / fetch"
  | .moveCall => "Move entry/object call (sourcegen)"
  | .zkCircuitCall => "ZK circuit/transition call (restricted subset)"
  | .unsupported => "target does not materialize portable crosscall yet"

structure Report where
  targetId : String
  nativeForm : NativeForm
  capabilityId : String
  asyncSupport : String
  note : String
  deriving Repr

private def jsonStr (s : String) : String := "\"" ++ s ++ "\""

def Report.json (r : Report) : String :=
  "{" ++
  "\"targetId\":" ++ jsonStr r.targetId ++ "," ++
  "\"nativeForm\":" ++ jsonStr r.nativeForm.id ++ "," ++
  "\"capabilityId\":" ++ jsonStr r.capabilityId ++ "," ++
  "\"asyncSupport\":" ++ jsonStr r.asyncSupport ++ "," ++
  "\"note\":" ++ jsonStr r.note ++
  "}"

/-- Map a registry profile to the native crosscall form for portable intent. -/
def forProfile (profile : TargetProfile) : Report :=
  let form :=
    match profile.id with
    | "evm" => NativeForm.evmCall
    | "solana-sbpf-asm" => NativeForm.solanaCpi
    | "wasm-near" => NativeForm.nearPromise
    | "wasm-cosmwasm" => NativeForm.cosmWasmMsg
    | "wasm-cloudflare-workers" => NativeForm.workersBinding
    | "move-aptos" | "move-sui" => NativeForm.moveCall
    | "psy-dpn" | "aleo-leo" => NativeForm.zkCircuitCall
    | _ =>
        match profile.family with
        | .evm => NativeForm.evmCall
        | .solana => NativeForm.solanaCpi
        | .wasmHost =>
            match profile.hostBridge? with
            | some .near => NativeForm.nearPromise
            | some .cosmWasm => NativeForm.cosmWasmMsg
            | some .soroban => NativeForm.nearPromise
            | none => NativeForm.workersBinding
        | .move => NativeForm.moveCall
        | .zkCircuitSourcegen => NativeForm.zkCircuitCall
  let capabilityId :=
    match form with
    | .solanaCpi => Capability.crosscallCpi.id
    | .nearPromise => Capability.nearPromise.id
    | .unsupported => "crosscall.unsupported"
    | _ => Capability.crosscallInvoke.id
  let asyncSupport :=
    match form with
    | .nearPromise => "async-promise"
    | .cosmWasmMsg => "submessage-async"
    | .solanaCpi => "sync-cpi"
    | .evmCall => "sync-call"
    | .workersBinding => "async-fetch"
    | .moveCall => "sync-entry-call"
    | .zkCircuitCall => "circuit-static"
    | .unsupported => "none"
  let note :=
    match form with
    | .evmCall =>
        "Portable crosscall.invoke → EVM CALL; STATICCALL/DELEGATECALL/create remain EVM extensions"
    | .solanaCpi =>
        "Portable crosscall.invoke → Solana CPI materialization (method+args as ix data; callee_program account by index; Source.Solana CPI still for hand-tuned layouts)"
    | .nearPromise =>
        "Portable crosscall.invoke → NEAR promise_create (nearCrosscallStrings string pool for account/method names)"
    | .cosmWasmMsg =>
        "Portable crosscall.invoke → CosmWasm WasmMsg/submessage via host adapter (spike coverage)"
    | .workersBinding =>
        "Portable crosscall.invoke reinterpreted as Workers binding/fetch (off-chain host)"
    | .moveCall =>
        "Portable crosscall.invoke → Move package call shape (spike; limited coverage)"
    | .zkCircuitCall =>
        "Portable crosscall restricted in ZK lanes; Psy accepts untyped U64 crosscall, typed/create rejected"
    | .unsupported =>
        "No portable crosscall materialization for this target"
  { targetId := profile.id
    nativeForm := form
    capabilityId := capabilityId
    asyncSupport := asyncSupport
    note := note }

def reportsForAllImplemented : Array Report :=
  all.map forProfile

/-- Whether the module IR uses any portable crosscall-shaped expression. -/
partial def moduleUsesPortableCrosscall (module : Module) : Bool :=
  module.entrypoints.any fun ep =>
    ep.body.any stmtUses
where
  exprUses : Expr → Bool
    | .crosscallInvoke .. | .crosscallInvokeTyped .. | .crosscallInvokeValueTyped ..
    | .crosscallInvokeStaticTyped .. | .crosscallInvokeDelegateTyped ..
    | .crosscallCreate .. | .crosscallCreate2 ..
    | .nearCrosscallInvokePool .. | .nearPromiseThen .. => true
    | .effect e => effectUses e
    | .add a b _ | .sub a b _ | .mul a b _ | .div a b | .mod a b | .pow a b
    | .bitAnd a b | .bitOr a b | .bitXor a b | .shiftLeft a b | .shiftRight a b
    | .eq a b | .ne a b | .lt a b | .le a b | .gt a b | .ge a b
    | .boolAnd a b | .boolOr a b | .hashTwoToOne a b => exprUses a || exprUses b
    | .cast a _ | .boolNot a | .hash a | .memoryArrayLength a | .field a _
    | .nearPromiseResultStatus a | .nearPromiseResultU64 a => exprUses a
    | .arrayLit _ xs => xs.any exprUses
    | .structLit _ fs => fs.any (fun f => exprUses f.snd)
    | .arrayGet a i | .memoryArrayGet a i => exprUses a || exprUses i
    | .memoryArrayNew _ len => exprUses len
    | .hashValue a b c d => exprUses a || exprUses b || exprUses c || exprUses d
    | .literal _ | .local _ | .nativeValue | .nearPromiseResultsCount => false
  effectUses : Effect → Bool
    | .storageScalarWrite _ v | .storageScalarAssignOp _ _ v
    | .storageStructFieldWrite _ _ v | .storageDynamicArrayPush _ v => exprUses v
    | .storageMapContains _ k | .storageMapGet _ k | .storageArrayRead _ k => exprUses k
    | .storageMapInsert _ k v | .storageMapSet _ k v | .storageArrayWrite _ k v
    | .storageArrayStructFieldWrite _ k _ v => exprUses k || exprUses v
    | .memoryArraySet a i v => exprUses a || exprUses i || exprUses v
    | .storagePathRead _ path => path.any pathUses
    | .storagePathWrite _ path v | .storagePathAssignOp _ path _ v =>
        path.any pathUses || exprUses v
    | .eventEmit _ fs => fs.any (fun f => exprUses f.snd)
    | .eventEmitIndexed _ indexed data =>
        indexed.any (fun f => exprUses f.snd) || data.any (fun f => exprUses f.snd)
    | .storageScalarRead _ | .storageStructFieldRead _ _ | .storageDynamicArrayPop _
    | .storageArrayStructFieldRead _ _ _ | .contextRead _ => false
  pathUses : StoragePathSegment → Bool
    | .field _ => false
    | .index i | .mapKey i => exprUses i
  stmtUses : Statement → Bool
    | .letBind _ _ v | .letMutBind _ _ v | .return v => exprUses v
    | .assign a b | .assignOp a _ b | .assertEq a b _ _ => exprUses a || exprUses b
    | .effect e => effectUses e
    | .assert c _ _ => exprUses c
    | .ifElse c t e => exprUses c || t.any stmtUses || e.any stmtUses
    | .boundedFor _ _ _ body => body.any stmtUses
    | .whileLoop c body => exprUses c || body.any stmtUses
    | .revert _ | .revertWithError _ | .release _ => false

end ProofForge.Target.CrosscallMaterialize
