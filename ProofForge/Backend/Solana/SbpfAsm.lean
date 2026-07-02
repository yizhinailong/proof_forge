/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana sBPF Assembly Backend

Architecture: IR.Module → `Array AstNode` → sBPF assembly text (`.s`)

The AST/printer lives in `ProofForge.Backend.Solana.Asm`, account layout in
`StateLayout`, manifest generation in `Manifest`, syscalls in `Syscalls`, and
register bookkeeping in `Register`. This file owns the IR → AST lowering.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

import ProofForge.IR.Contract
import ProofForge.Target.Adapter
import ProofForge.Target.Registry
import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.Extension
import ProofForge.Backend.Solana.StateLayout
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.Register

namespace ProofForge.Backend.Solana.SbpfAsm

open ProofForge.IR
open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.Extension
open ProofForge.Backend.Solana.StateLayout
open ProofForge.Backend.Solana.Manifest
open ProofForge.Backend.Solana.Register

-- ============================================================================
-- Metadata
-- ============================================================================

def targetId : String := "solana-sbpf-asm"
def artifactKind : String := "solana-elf"
def irVersion : String := "portable-ir-v0"

-- ============================================================================
-- Error type
-- ============================================================================

structure LowerError where
  message : String
  deriving Repr, Inhabited

def LowerError.render (err : LowerError) : String := err.message

def diagnosticError (err : ProofForge.Target.Diagnostic) : LowerError := {
  message := err.render
}

/-- Reject IR modules whose portable capabilities are not in the
`solana-sbpf-asm` target profile (V-GATE-SOLANA-05). For Solana this mainly
rules out the generic `.crosscallInvoke` (Solana uses `.crosscallCpi`,
D-027) and the ZK capabilities. -/
def validateCapabilities (module : IR.Module) : Except LowerError Unit := do
  match ProofForge.Target.resolveModule ProofForge.Target.solanaSbpfAsm module with
  | .ok _ => .ok ()
  | .error err => .error (diagnosticError err)

-- ============================================================================
-- Lowering context
-- ============================================================================

structure LocalSlot where
  name : String
  offset : Nat
  deriving Inhabited

structure LowerCtx where
  stateFieldOffsets : Array (String × Nat)
  locals : Array LocalSlot
  nextLocalOffset : Nat
  scratchOffset : Nat
  nextLabel : Nat
  allocator : Allocator
  deriving Inhabited

def LowerCtx.localOffset? (ctx : LowerCtx) (name : String) : Option Nat :=
  ctx.locals.find? (fun slot => slot.name == name) |>.map fun slot => slot.offset

def LowerCtx.addLocal (ctx : LowerCtx) (name : String) : LowerCtx :=
  let offset := ctx.nextLocalOffset
  let scratchOffset := max ctx.scratchOffset (offset + 16)
  { ctx with
    locals := ctx.locals.push { name, offset }
    nextLocalOffset := offset + 8
    scratchOffset := scratchOffset }

/-- Reserve a stack word for a temporary value. The allocation is monotonic
within an entrypoint so nested expression lowering cannot overwrite an outer
temporary that is still live while lowering the RHS. -/
def LowerCtx.allocScratch (ctx : LowerCtx) : Nat × LowerCtx :=
  let offset := ctx.scratchOffset
  (offset, { ctx with scratchOffset := offset + 8 })

/-- Allocate a temporary location. Prefer a register, then fall back to a stack
slot assigned by `allocScratch` so spill slots stay disjoint from locals. -/
def LowerCtx.allocLoc (ctx : LowerCtx) : Loc × LowerCtx :=
  let (reg?, allocator) := ctx.allocator.allocReg?
  match reg? with
  | some r => (.reg r, { ctx with allocator })
  | none =>
      let ctx := { ctx with allocator }
      let (offset, ctx) := ctx.allocScratch
      (.spill offset, ctx)

def LowerCtx.freeLoc (ctx : LowerCtx) (loc : Loc) : LowerCtx :=
  { ctx with allocator := ctx.allocator.free loc }

def LowerCtx.stateAbsOff? (ctx : LowerCtx) (id : String) : Option Nat :=
  ctx.stateFieldOffsets.find? (fun p => p.fst == id) |>.map fun p => p.snd

/-- Mint a fresh local label name and a context with the label counter bumped.
Used by nested control flow and boolean expressions so labels stay unique
across an entire module lowering. -/
def LowerCtx.freshLabel (ctx : LowerCtx) : String × LowerCtx :=
  (s!"sol_lbl_{ctx.nextLabel}", { ctx with nextLabel := ctx.nextLabel + 1 })

/-- Reset local allocation state so each entrypoint gets its own scratch/local
frame. The label counter and state-field offsets are preserved by the caller. -/
def LowerCtx.resetLocals (ctx : LowerCtx) : LowerCtx :=
  { ctx with locals := #[], nextLocalOffset := 8, scratchOffset := 8, allocator := Allocator.new }

def buildCtx (module : Module) (stateDataOff : Nat) : Except LowerError LowerCtx := do
  let offsets := buildStateOffsetsAtBase module stateDataOff
  return { stateFieldOffsets := offsets.map (fun f => (f.id, f.absOff)), locals := #[], nextLocalOffset := 8, scratchOffset := 8, nextLabel := 0, allocator := Allocator.new }

def accountDataSize (module : Module) (account : AccountEntry) : Nat :=
  if account.index == 0 then moduleDataSize module else 0

def accountDataSizes (module : Module) (accounts : Array AccountEntry) : Array Nat :=
  accounts.map (accountDataSize module)

-- ============================================================================
-- IR expression → AST nodes (result in r2, r3 as scratch)
-- ============================================================================

/-- Produce an `Inst` with dst = r2 and the given fields. -/
def res (opcode : Opcode) (src : Option Reg := none) (off : Option MemOff := none) (imm : Option Imm := none) : Inst :=
  { opcode, dst := some .r2, src, off, imm }

/-- Combine already-lowered LHS/RHS nodes for a commutative binary ALU op.
The result lands in r2. LHS is stashed to the scratch slot, RHS is evaluated
into r2, then LHS is reloaded into r3 and `op r2, r3` is applied. Order does
not matter for commutative ops. -/
def lowerBinaryCombine (lhsNodes rhsNodes : Array AstNode) (op : Opcode) (scratchOffset : Nat) : Array AstNode :=
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratchOffset) },
    .instruction { opcode := op, dst := some .r2, src := some .r3 }
  ]

/-- Combine already-lowered LHS/RHS nodes for a non-commutative binary ALU op.
The result lands in r2 in `lhs op rhs` order. LHS is stashed, RHS is evaluated,
then RHS is moved to r3, LHS is reloaded into r2, and `op r2, r3` is applied. -/
def lowerOrderedBinaryCombine (lhsNodes rhsNodes : Array AstNode) (op : Opcode) (scratchOffset : Nat) : Array AstNode :=
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .mov64, dst := some .r3, src := some .r2 },
    .instruction { opcode := .ldxdw, dst := some .r2, src := some .r10, off := some (.num scratchOffset) },
    .instruction { opcode := op, dst := some .r2, src := some .r3 }
  ]

/-- Combine already-lowered LHS/RHS nodes for an unsigned comparison that
returns a boolean 0/1 in r2. `condJmp` is `jeq/jne/jlt/jle/jgt/jge`; it jumps
to `trueLabel` when the comparison holds. The boolean temp is allocated from
the register pool (or spilled to the stack); the LHS is stashed at the caller's
scratch offset. -/
def lowerCmpCombine (lhsNodes rhsNodes : Array AstNode) (condJmp : Opcode) (trueLabel endLabel : String) (scratchOffset : Nat) (boolLoc : Loc) : Array AstNode :=
  let boolSet (v : Nat) : Array AstNode := match boolLoc with
    | .reg r => #[ .instruction { opcode := .mov64, dst := some r, imm := some (.num v) } ]
    | .spill off => #[ .instruction { opcode := .stdw, dst := some .r10, off := some (.num off), imm := some (.num v) } ]
  let boolMovToR2 : Array AstNode := match boolLoc with
    | .reg r =>
        if r == .r2 then #[]
        else #[ .instruction { opcode := .mov64, dst := some .r2, src := some r } ]
    | .spill off => #[ .instruction { opcode := .ldxdw, dst := some .r2, src := some .r10, off := some (.num off) } ]
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratchOffset) }
  ] ++ boolSet 0 ++ #[
    .instruction { opcode := condJmp, dst := some .r3, src := some .r2, off := some (.sym trueLabel) },
    .instruction { opcode := .ja, off := some (.sym endLabel) },
    .label trueLabel
  ] ++ boolSet 1 ++ #[
    .label endLabel
  ] ++ boolMovToR2

def assignOpcode : AssignOp → Opcode
  | .add => .add64
  | .sub => .sub64
  | .mul => .mul64
  | .div => .div64
  | .mod => .mod64
  | .bitAnd => .and64
  | .bitOr => .or64
  | .bitXor => .xor64
  | .shiftLeft => .lsh64
  | .shiftRight => .rsh64

/-- `lowerExpr` lowers an IR expr into AST nodes that compute the value in r2
and thread the lowering context so nested comparisons can mint fresh labels. -/
partial def lowerExpr (ctx : LowerCtx) (expr : IR.Expr) : Except LowerError (Array AstNode × LowerCtx) :=
  match expr with
  | .literal (.u64 n) =>
    .ok (#[ .instruction (res .mov64 (imm := some (.num n))) ], ctx)
  | .literal (.u32 n) =>
    .ok (#[ .instruction (res .mov32 (imm := some (.num n))) ], ctx)
  | .literal (.bool true) =>
    .ok (#[ .instruction (res .mov64 (imm := some (.num 1))) ], ctx)
  | .literal (.bool false) =>
    .ok (#[ .instruction (res .mov64 (imm := some (.num 0))) ], ctx)
  | .literal _ => .error { message := "unsupported literal type in Phase 1" }
  | .local name =>
    match ctx.localOffset? name with
    | some off => .ok (#[ .instruction (res .ldxdw (src := some .r10) (off := some (.num off))) ], ctx)
    | none => .error { message := s!"unknown local: {name}" }
  | .add lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .add64 scratch, ctx)
  | .sub lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerOrderedBinaryCombine ln rn .sub64 scratch, ctx)
  | .mul lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .mul64 scratch, ctx)
  | .div lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerOrderedBinaryCombine ln rn .div64 scratch, ctx)
  | .mod lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerOrderedBinaryCombine ln rn .mod64 scratch, ctx)
  | .boolAnd lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .and64 scratch, ctx)
  | .boolOr lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .or64 scratch, ctx)
  | .boolNot value => do
    -- value is a strict 0/1 boolean: bitwise NOT via xor with 1.
    let (vn, ctx) ← lowerExpr ctx value
    .ok (vn ++ #[ .instruction { opcode := .xor64, dst := some .r2, imm := some (.num 1) } ], ctx)
  | .eq lhs rhs => lowerCmp ctx lhs rhs .jeq
  | .ne lhs rhs => lowerCmp ctx lhs rhs .jne
  | .lt lhs rhs => lowerCmp ctx lhs rhs .jlt
  | .le lhs rhs => lowerCmp ctx lhs rhs .jle
  | .gt lhs rhs => lowerCmp ctx lhs rhs .jgt
  | .ge lhs rhs => lowerCmp ctx lhs rhs .jge
  | .effect (.storageScalarRead stateId) =>
    match ctx.stateAbsOff? stateId with
    | some absOff => .ok (#[ .instruction (res .ldxdw (src := some .r1) (off := some (.num absOff))) ], ctx)
    | none => .error { message := s!"unknown state: {stateId}" }
  | .effect (.storagePathRead stateId path) =>
    if path.isEmpty then
      match ctx.stateAbsOff? stateId with
      | some absOff => .ok (#[ .instruction (res .ldxdw (src := some .r1) (off := some (.num absOff))) ], ctx)
      | none => .error { message := s!"unknown state: {stateId}" }
    else .error { message := "storage path read with non-empty path not supported in Phase 1" }
  | _ => .error { message := "unsupported expression in Phase 1" }
where
  lowerCmp (ctx : LowerCtx) (lhs rhs : IR.Expr) (condJmp : Opcode) : Except LowerError (Array AstNode × LowerCtx) := do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (scratch, ctx) := ctx.allocScratch
    let (rn, ctx) ← lowerExpr ctx rhs
    let (trueLabel, ctx) := ctx.freshLabel
    let (endLabel, ctx) := ctx.freshLabel
    let (boolLoc, ctx) := ctx.allocLoc
    let nodes := lowerCmpCombine ln rn condJmp trueLabel endLabel scratch boolLoc
    let ctx := ctx.freeLoc boolLoc
    .ok (nodes, ctx)

-- ============================================================================
-- IR statement → AST nodes
-- ============================================================================

partial def lowerStmt (ctx : LowerCtx) (stmt : IR.Statement) : Except LowerError (Array AstNode × LowerCtx) :=
  match stmt with
  | .letBind name _ value => do
    let (vn, ctx) ← lowerExpr ctx value
    let off := ctx.nextLocalOffset
    let ctx' := ctx.addLocal name
    .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx')
  | .letMutBind name _ value => do
    let (vn, ctx) ← lowerExpr ctx value
    let off := ctx.nextLocalOffset
    let ctx' := ctx.addLocal name
    .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx')
  | .assign target value =>
    match target with
    | .local name =>
      match ctx.localOffset? name with
      | some off => do
        let (vn, ctx') ← lowerExpr ctx value
        .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx')
      | none => .error { message := s!"assign to unknown local: {name}" }
    | _ => .error { message := "assign to non-local not supported in Phase 1" }
  | .assignOp target opA value =>
    match target with
    | .local name =>
      match ctx.localOffset? name with
      | some localOff => do
        let (scratch, ctx) := ctx.allocScratch
        let (vn, ctx') ← lowerExpr ctx value
        .ok (#[
          .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num localOff) },
          .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratch), src := some .r3 }
        ] ++ vn ++ #[
          .instruction { opcode := .mov64, dst := some .r3, src := some .r2 },
          .instruction { opcode := .ldxdw, dst := some .r2, src := some .r10, off := some (.num scratch) },
          .instruction { opcode := assignOpcode opA, dst := some .r2, src := some .r3 },
          .instruction { opcode := .stxdw, dst := some .r10, off := some (.num localOff), src := some .r2 }
        ], ctx')
      | none => .error { message := s!"assignOp to unknown local: {name}" }
    | _ => .error { message := "assignOp to non-local not supported in Phase 1" }
  | .effect (.storageScalarWrite stateId value) => do
    match ctx.stateAbsOff? stateId with
    | some absOff => do
      let (vn, ctx') ← lowerExpr ctx value
      .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 } ], ctx')
    | none => .error { message := s!"unknown state: {stateId}" }
  | .effect (.storagePathWrite stateId path value) =>
    if path.isEmpty then
      match ctx.stateAbsOff? stateId with
      | some absOff => do
        let (vn, ctx') ← lowerExpr ctx value
        .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 } ], ctx')
      | none => .error { message := s!"unknown state: {stateId}" }
    else .error { message := "storage path write with non-empty path not supported in Phase 1" }
  | .effect (.storageScalarAssignOp stateId opA value) => do
    match ctx.stateAbsOff? stateId with
    | some absOff => do
      let (scratch, ctx) := ctx.allocScratch
      let (vn, ctx') ← lowerExpr ctx value
      .ok (#[
        .instruction { opcode := .ldxdw, dst := some .r3, src := some .r1, off := some (.num absOff) },
        .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratch), src := some .r3 }
      ] ++ vn ++ #[
        .instruction { opcode := .mov64, dst := some .r3, src := some .r2 },
        .instruction { opcode := .ldxdw, dst := some .r2, src := some .r10, off := some (.num scratch) },
        .instruction { opcode := assignOpcode opA, dst := some .r2, src := some .r3 },
        .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 }
      ], ctx')
    | none => .error { message := s!"unknown state: {stateId}" }
  | .assert cond _ => do
    let (cn, ctx') ← lowerExpr ctx cond
    .ok (cn ++ #[
      .comment "control.assert",
      .instruction { opcode := .jeq, dst := some .r2, imm := some (.num 0), off := some (.sym "assert_fail") }
    ], ctx')
  | .assertEq lhs rhs _ => do
    let (ln, ctx') ← lowerExpr ctx lhs
    let (scratch, ctx') := ctx'.allocScratch
    let (rn, ctx') ← lowerExpr ctx' rhs
    .ok (ln ++ #[
      .comment "control.assert_eq",
      .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratch), src := some .r2 }
    ] ++ rn ++ #[
      .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratch) },
      .instruction { opcode := .jne, dst := some .r3, src := some .r2, off := some (.sym "assert_eq_fail") }
    ], ctx')
  | .ifElse cond thenBody elseBody => do
    let (cn, ctx) ← lowerExpr ctx cond
    let (elseLabel, ctx) := ctx.freshLabel
    let (endLabel, ctx) := ctx.freshLabel
    let mut nodes : Array AstNode := cn ++ #[
      .comment "control.conditional",
      .instruction { opcode := .jeq, dst := some .r2, imm := some (.num 0), off := some (.sym elseLabel) }
    ]
    let mut ctx := ctx
    for stmt in thenBody do
      let (sn, ctx') ← lowerStmt ctx stmt
      nodes := nodes.append sn
      ctx := ctx'
    nodes := nodes.push (.instruction { opcode := .ja, off := some (.sym endLabel) })
    nodes := nodes.push (.label elseLabel)
    for stmt in elseBody do
      let (sn, ctx') ← lowerStmt ctx stmt
      nodes := nodes.append sn
      ctx := ctx'
    nodes := nodes.push (.label endLabel)
    .ok (nodes, ctx)
  | .return value => do
    let (vn, ctx') ← lowerExpr ctx value
    .ok (vn ++ #[
      .instruction { opcode := .mov64, dst := some .r3, src := some .r10 },
      .instruction { opcode := .sub64, dst := some .r3, imm := some (.num 8) },
      .instruction { opcode := .stxdw, dst := some .r3, off := some (.num 0), src := some .r2 },
      .instruction { opcode := .mov64, dst := some .r1, src := some .r3 },
      .instruction { opcode := .mov64, dst := some .r2, imm := some (.num 8) },
      .instruction { opcode := .call, imm := some (.sym "sol_set_return_data") },
      .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
      .instruction { opcode := .exit }
    ], ctx')
  | _ => .error { message := "unsupported statement in Phase 1" }

-- ============================================================================
-- Entrypoint lowering
-- ============================================================================

def entrypointHasReturn (ep : IR.Entrypoint) : Bool :=
  ep.body.any fun stmt => match stmt with | .return _ => true | _ => false

def lowerProgramOwnerValidation (instrDataLenOff ownerOff : Nat) : Array AstNode := #[
  .instruction { opcode := .mov64, dst := some .r4, src := some .r1 },
  .instruction { opcode := .add64, dst := some .r4, imm := some (.num instrDataLenOff) },
  .instruction { opcode := .ldxdw, dst := some .r2, src := some .r4, off := some (.num 0) },
  .instruction { opcode := .add64, dst := some .r4, imm := some (.num 8) },
  .instruction { opcode := .add64, dst := some .r4, src := some .r2 },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num ownerOff) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 0) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num (ownerOff + 8)) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 8) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num (ownerOff + 16)) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 16) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num (ownerOff + 24)) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 24) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") }
]

def lowerAccountValidationFor (instrDataLenOff : Nat) (account : AccountEntry)
    (layout : AccountInputLayout) : Array AstNode :=
  let signerCheck :=
    if account.signer then
      #[
        .comment s!"account.validation[{account.index}:{account.name}]: signer=true",
        .instruction { opcode := .ldxb, dst := some .r2, src := some .r1, off := some (.num layout.signerOff) },
        .instruction { opcode := .jeq, dst := some .r2, imm := some (.num 0), off := some (.sym "error_signer") }
      ]
    else
      #[]
  let writableCheck :=
    if account.writable then
      #[
        .comment s!"account.validation[{account.index}:{account.name}]: writable=true",
        .instruction { opcode := .ldxb, dst := some .r2, src := some .r1, off := some (.num layout.writableOff) },
        .instruction { opcode := .jeq, dst := some .r2, imm := some (.num 0), off := some (.sym "error_not_writable") }
      ]
    else
      #[]
  let ownerCheck :=
    if account.owner == "program" then
      #[.comment s!"account.validation[{account.index}:{account.name}]: owner=program"] ++
        lowerProgramOwnerValidation instrDataLenOff layout.ownerOff
    else
      #[]
  signerCheck ++ writableCheck ++ ownerCheck

/-- Account-validation prologue for the generated fixed account schema. The
owner check computes the program_id address from the dynamic instruction data
length so it remains correct even as the discriminant payload grows. -/
def lowerAccountValidation (instrDataLenOff : Nat) :
    List AccountEntry -> List AccountInputLayout -> Array AstNode
  | [], _ => #[]
  | _, [] => #[]
  | account :: accounts, layout :: layouts =>
      lowerAccountValidationFor instrDataLenOff account layout ++
      lowerAccountValidation instrDataLenOff accounts layouts

def lowerAccountValidations (instrDataLenOff : Nat) (accounts : Array AccountEntry)
    (layouts : Array AccountInputLayout) : Array AstNode :=
  #[
    .comment "account.validation: generated account schema"
  ] ++ lowerAccountValidation instrDataLenOff accounts.toList layouts.toList

partial def lowerEntrypoint (ctx : LowerCtx) (instrDataLenOff : Nat)
    (accounts : Array AccountEntry) (accountLayouts : Array AccountInputLayout)
    (extensions : ProgramExtensions) (ep : IR.Entrypoint) :
    Except LowerError (LowerCtx × Array AstNode) := do
  let mut nodes := #[
    .label s!"sol_{ep.name}",
    .blankLine
  ]
  nodes := nodes ++ lowerAccountValidations instrDataLenOff accounts accountLayouts
  nodes := nodes ++ lowerEntrypointActions extensions ep.name
  let mut ctx := ctx
  for stmt in ep.body do
    let (sn, ctx') ← lowerStmt ctx stmt
    nodes := nodes ++ sn
    ctx := ctx'
  if !entrypointHasReturn ep then
    nodes := nodes ++ #[
      .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
      .instruction { opcode := .exit }
    ]
  .ok (ctx, nodes)

-- ============================================================================
-- Module → AST nodes
-- ============================================================================

structure ModuleInputSchema where
  accounts : Array AccountEntry
  inputLayout : InputLayout
  deriving Inhabited

def buildModuleInputSchema (module : IR.Module) (extensions : ProgramExtensions) :
    ModuleInputSchema :=
  let instructions := buildInstructionsWithExtensions module extensions
  let accounts :=
    match instructions[0]? with
    | some instruction => instruction.accounts
    | none => buildDefaultAccounts module
  let inputLayout := computeInputLayout (accountDataSizes module accounts)
  { accounts, inputLayout }

def buildCpiAccountBindings (accounts : Array AccountEntry)
    (layouts : Array AccountInputLayout) : Array CpiAccountBinding := Id.run do
  let mut bindings := #[]
  let mut idx := 0
  for account in accounts do
    match layouts[idx]? with
    | some layout =>
        bindings := bindings.push { name := account.name, layout }
    | none =>
        pure ()
    idx := idx + 1
  return bindings

partial def lowerModuleCore (module : IR.Module) (extensions : ProgramExtensions) :
    Except LowerError (Array AstNode) := do
  validateCapabilities module
  let schema := buildModuleInputSchema module extensions
  let accounts := schema.accounts
  let inputLayout := schema.inputLayout
  let stateDataOff ←
    match inputLayout.accounts[0]? with
    | some accountLayout => .ok accountLayout.dataStart
    | none => .error { message := "Solana account schema must contain at least one state account" }
  let ctx ← buildCtx module stateDataOff

  let mut nodes := #[
    .comment s!"ProofForge generated sBPF — {module.name} (Phase 1)",
    .comment "Target: solana-sbpf-asm (D-026)",
    .blankLine,
    .equDecl "INSTRUCTION_DATA_LEN" inputLayout.instructionDataLenOff,
    .equDecl "INSTRUCTION_DATA" inputLayout.instructionDataOff
  ]
  for (stateId, absOff) in ctx.stateFieldOffsets do
    nodes := nodes.push (.equDecl (stateId.toUpper ++ "_DATA") absOff)

  nodes := nodes ++ #[
    .blankLine,
    .globalDecl "entrypoint",
    .blankLine,
    .label "entrypoint",
    .instruction { opcode := .ldxb, dst := some .r2, src := some .r1, off := some (.sym "INSTRUCTION_DATA") }
  ]
  let mut idx := 0
  for ep in module.entrypoints do
    nodes := nodes.push (.instruction {
      opcode := .jeq, dst := some .r2, imm := some (.num idx), off := some (.sym s!"sol_{ep.name}")
    })
    idx := idx + 1
  nodes := nodes ++ #[
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 1) },
    .instruction { opcode := .exit }
  ]

  let mut ctx := ctx
  for ep in module.entrypoints do
    nodes := nodes.push .blankLine
    let epCtx := ctx.resetLocals
    let (ctx', block) ←
      lowerEntrypoint epCtx inputLayout.instructionDataLenOff accounts inputLayout.accounts extensions ep
    ctx := { ctx with nextLabel := ctx'.nextLabel }
    nodes := nodes ++ block

  nodes := nodes ++ #[
    .blankLine,
    .label "assert_fail",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 2) },
    .instruction { opcode := .exit },
    .blankLine,
    .label "assert_eq_fail",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 3) },
    .instruction { opcode := .exit },
    .blankLine,
    .label "error_not_writable",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 4) },
    .instruction { opcode := .exit },
    .blankLine,
    .label "error_signer",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 5) },
    .instruction { opcode := .exit },
    .blankLine,
    .label "error_owner",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 6) },
    .instruction { opcode := .exit }
  ]
  .ok nodes

partial def lowerModule (module : IR.Module) : Except LowerError (Array AstNode) :=
  lowerModuleCore module {}

-- ============================================================================
-- Module rendering (IR → AST → text pipeline)
-- ============================================================================

def renderModule (module : IR.Module) : Except LowerError String := do
  let nodes ← lowerModule module
  .ok (Asm.renderNodes nodes)

def lowerModuleWithPlan (module : IR.Module) (plan : ProofForge.Target.CapabilityPlan) :
    Except LowerError (Array AstNode) := do
  let extensions := ProgramExtensions.fromPlan plan
  let schema := buildModuleInputSchema module extensions
  let accountBindings := buildCpiAccountBindings schema.accounts schema.inputLayout.accounts
  let nodes ← lowerModuleCore module extensions
  .ok (nodes ++
    ProofForge.Backend.Solana.Extension.lowerProgramExtensionsWithAccountBindings
      accountBindings extensions)

def renderModuleWithPlan (module : IR.Module) (plan : ProofForge.Target.CapabilityPlan) :
    Except LowerError String := do
  let nodes ← lowerModuleWithPlan module plan
  .ok (Asm.renderNodes nodes)

-- ============================================================================
-- Phase 0: canned entrypoint
-- ============================================================================

def renderCannedEntrypoint : Except LowerError String :=
  .ok (String.intercalate "\n" #[
    "; ProofForge generated sBPF entrypoint (Phase 0 spike)",
    "; Target: solana-sbpf-asm (D-026)",
    "; This canned entrypoint returns success (r0 = 0) without parsing accounts.",
    "",
    ".globl entrypoint",
    "",
    "entrypoint:",
    "  mov64 r0, 0",
    "  exit",
    ""
  ].toList)

end ProofForge.Backend.Solana.SbpfAsm
