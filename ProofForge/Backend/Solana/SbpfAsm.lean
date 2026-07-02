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
import ProofForge.Target.Check
import ProofForge.Target.Registry
import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.StateLayout
import ProofForge.Backend.Solana.Manifest

namespace ProofForge.Backend.Solana.SbpfAsm

open ProofForge.IR
open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.StateLayout
open ProofForge.Backend.Solana.Manifest

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

/-- Wrap a target capability error as an sBPF lowering error so the
unsupported-capability diagnostic flows through `renderModule`. -/
def capabilityError (err : ProofForge.Target.CapabilityError) : LowerError := {
  message := err.render
}

/-- Reject IR modules whose portable capabilities are not in the
`solana-sbpf-asm` target profile (V-GATE-SOLANA-05). For Solana this mainly
rules out the generic `.crosscallInvoke` (Solana uses `.crosscallCpi`,
D-027) and the ZK capabilities. -/
def validateCapabilities (module : IR.Module) : Except LowerError Unit := do
  match ProofForge.Target.requireCapabilities ProofForge.Target.solanaSbpfAsm module.capabilities with
  | .ok () => .ok ()
  | .error err => .error (capabilityError err)

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
  deriving Inhabited

def LowerCtx.localOffset? (ctx : LowerCtx) (name : String) : Option Nat :=
  ctx.locals.find? (fun slot => slot.name == name) |>.map fun slot => slot.offset

def LowerCtx.addLocal (ctx : LowerCtx) (name : String) : LowerCtx :=
  let offset := ctx.nextLocalOffset
  { ctx with
    locals := ctx.locals.push { name, offset }
    nextLocalOffset := offset + 8
    scratchOffset := offset + 16 }

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
  { ctx with locals := #[], nextLocalOffset := 8, scratchOffset := 8 }

def buildCtx (module : Module) : Except LowerError LowerCtx := do
  let offsets := buildStateOffsets module
  return { stateFieldOffsets := offsets.map (fun f => (f.id, f.absOff)), locals := #[], nextLocalOffset := 8, scratchOffset := 8, nextLabel := 0 }

-- ============================================================================
-- IR expression → AST nodes (result in r2, r3 as scratch)
-- ============================================================================

/-- Produce an `Inst` with dst = r2 and the given fields. -/
def res (opcode : Opcode) (src : Option Reg := none) (off : Option MemOff := none) (imm : Option Imm := none) : Inst :=
  { opcode, dst := some .r2, src, off, imm }

/-- Combine already-lowered LHS/RHS nodes for a binary ALU op.
The result lands in r2. LHS is stashed to the scratch slot, RHS is evaluated
into r2, then LHS is reloaded into r3 and `op r2, r3` is applied. -/
def lowerBinaryCombine (lhsNodes rhsNodes : Array AstNode) (op : Opcode) (scratchOffset : Nat) : Array AstNode :=
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratchOffset) },
    .instruction { opcode := op, dst := some .r2, src := some .r3 }
  ]

/-- Combine already-lowered LHS/RHS nodes for an unsigned comparison that
returns a boolean 0/1 in r2 (and leaves the boolean in r4 before the final
mov). `condJmp` is `jeq/jne/jlt/jle/jgt/jge`; it jumps to `trueLabel` when
the comparison holds. -/
def lowerCmpCombine (lhsNodes rhsNodes : Array AstNode) (condJmp : Opcode) (trueLabel endLabel : String) (scratchOffset : Nat) : Array AstNode :=
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratchOffset) },
    .instruction { opcode := .mov64, dst := some .r4, imm := some (.num 0) },
    .instruction { opcode := condJmp, dst := some .r3, src := some .r2, off := some (.sym trueLabel) },
    .instruction { opcode := .ja, off := some (.sym endLabel) },
    .label trueLabel,
    .instruction { opcode := .mov64, dst := some .r4, imm := some (.num 1) },
    .label endLabel,
    .instruction { opcode := .mov64, dst := some .r2, src := some .r4 }
  ]

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
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .add64 ctx.scratchOffset, ctx)
  | .sub lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .sub64 ctx.scratchOffset, ctx)
  | .mul lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .mul64 ctx.scratchOffset, ctx)
  | .div lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .div64 ctx.scratchOffset, ctx)
  | .mod lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .mod64 ctx.scratchOffset, ctx)
  | .boolAnd lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .and64 ctx.scratchOffset, ctx)
  | .boolOr lhs rhs => do
    let (ln, ctx) ← lowerExpr ctx lhs
    let (rn, ctx) ← lowerExpr ctx rhs
    .ok (lowerBinaryCombine ln rn .or64 ctx.scratchOffset, ctx)
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
    let (rn, ctx) ← lowerExpr ctx rhs
    let (trueLabel, ctx) := ctx.freshLabel
    let (endLabel, ctx) := ctx.freshLabel
    .ok (lowerCmpCombine ln rn condJmp trueLabel endLabel ctx.scratchOffset, ctx)

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
      let aluOp : Opcode := match opA with | .add => .add64 | .sub => .sub64 | .mul => .mul64 | .div => .div64 | .mod => .mod64 | _ => .add64
      let sc := ctx.scratchOffset
      let (vn, ctx') ← lowerExpr ctx value
      .ok (#[
        .instruction { opcode := .ldxdw, dst := some .r3, src := some .r1, off := some (.num absOff) },
        .instruction { opcode := .stxdw, dst := some .r10, off := some (.num sc), src := some .r3 }
      ] ++ vn ++ #[
        .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num sc) },
        .instruction { opcode := aluOp, dst := some .r2, src := some .r3 },
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
    let sc := ctx.scratchOffset
    let (ln, ctx') ← lowerExpr ctx lhs
    let (rn, ctx') ← lowerExpr ctx' rhs
    .ok (ln ++ #[
      .comment "control.assert_eq",
      .instruction { opcode := .stxdw, dst := some .r10, off := some (.num sc), src := some .r2 }
    ] ++ rn ++ #[
      .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num sc) },
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
  | .return value =>
    match value with
    | .effect (.storageScalarRead stateId) =>
      match ctx.stateAbsOff? stateId with
      | some absOff => .ok (#[
        .instruction { opcode := .ldxdw, dst := some .r2, src := some .r1, off := some (.num absOff) },
        .instruction { opcode := .mov64, dst := some .r3, src := some .r10 },
        .instruction { opcode := .sub64, dst := some .r3, imm := some (.num 8) },
        .instruction { opcode := .stxdw, dst := some .r3, off := some (.num 0), src := some .r2 },
        .instruction { opcode := .mov64, dst := some .r1, src := some .r3 },
        .instruction { opcode := .mov64, dst := some .r2, imm := some (.num 8) },
        .instruction { opcode := .call, imm := some (.sym "sol_set_return_data") },
        .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
        .instruction { opcode := .exit }
      ], ctx)
      | none => .error { message := s!"unknown state: {stateId}" }
    | .literal (.u64 n) => .ok (#[
      .instruction { opcode := .mov64, dst := some .r3, src := some .r10 },
      .instruction { opcode := .sub64, dst := some .r3, imm := some (.num 8) },
      .instruction { opcode := .mov64, dst := some .r2, imm := some (.num n) },
      .instruction { opcode := .stxdw, dst := some .r3, off := some (.num 0), src := some .r2 },
      .instruction { opcode := .mov64, dst := some .r1, src := some .r3 },
      .instruction { opcode := .mov64, dst := some .r2, imm := some (.num 8) },
      .instruction { opcode := .call, imm := some (.sym "sol_set_return_data") },
      .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
      .instruction { opcode := .exit }
    ], ctx)
    | .local name =>
      match ctx.localOffset? name with
      | some off => .ok (#[
        .instruction { opcode := .ldxdw, dst := some .r2, src := some .r10, off := some (.num off) },
        .instruction { opcode := .mov64, dst := some .r3, src := some .r10 },
        .instruction { opcode := .sub64, dst := some .r3, imm := some (.num 8) },
        .instruction { opcode := .stxdw, dst := some .r3, off := some (.num 0), src := some .r2 },
        .instruction { opcode := .mov64, dst := some .r1, src := some .r3 },
        .instruction { opcode := .mov64, dst := some .r2, imm := some (.num 8) },
        .instruction { opcode := .call, imm := some (.sym "sol_set_return_data") },
        .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
        .instruction { opcode := .exit }
      ], ctx)
      | none => .error { message := s!"unknown local: {name}" }
    | _ => .error { message := "unsupported return in Phase 1" }
  | _ => .error { message := "unsupported statement in Phase 1" }

-- ============================================================================
-- Entrypoint lowering
-- ============================================================================

def entrypointHasReturn (ep : IR.Entrypoint) : Bool :=
  ep.body.any fun stmt => match stmt with | .return _ => true | _ => false

/-- Phase 1 default account-validation prologue.
Every entrypoint expects a single account at index 0 that is writable and
owned by the program (signer=false is recorded in the manifest but not
enforced at runtime). The owner check computes the program_id address from
the dynamic instruction_data_len so it remains correct even as the
discriminant payload grows. -/
def lowerAccountValidation (instrDataOff : Nat) : Array AstNode :=
  let instrDataLenOff := instrDataOff - 8
  #[
  .comment "account.validation: writable=true",
  .instruction { opcode := .ldxb, dst := some .r2, src := some .r1, off := some (.num 10) },
  .instruction { opcode := .jeq, dst := some .r2, imm := some (.num 0), off := some (.sym "error_not_writable") },
  .comment "account.validation: owner=program",
  .instruction { opcode := .mov64, dst := some .r4, src := some .r1 },
  .instruction { opcode := .add64, dst := some .r4, imm := some (.num instrDataLenOff) },
  .instruction { opcode := .ldxdw, dst := some .r2, src := some .r4, off := some (.num 0) },
  .instruction { opcode := .add64, dst := some .r4, imm := some (.num 8) },
  .instruction { opcode := .add64, dst := some .r4, src := some .r2 },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num 48) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 0) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num 56) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 8) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num 64) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 16) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") },
  .instruction { opcode := .ldxdw, dst := some .r5, src := some .r1, off := some (.num 72) },
  .instruction { opcode := .ldxdw, dst := some .r6, src := some .r4, off := some (.num 24) },
  .instruction { opcode := .jne, dst := some .r5, src := some .r6, off := some (.sym "error_owner") }
]

partial def lowerEntrypoint (ctx : LowerCtx) (instrDataOff : Nat) (ep : IR.Entrypoint) : Except LowerError (LowerCtx × Array AstNode) := do
  let mut nodes := #[
    .label s!"sol_{ep.name}",
    .blankLine
  ]
  nodes := nodes ++ lowerAccountValidation instrDataOff
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

partial def lowerModule (module : IR.Module) : Except LowerError (Array AstNode) := do
  validateCapabilities module
  let ctx ← buildCtx module
  let dataSize := moduleDataSize module
  let (_, instrDataOff) := computeSingleAccountLayout dataSize

  let mut nodes := #[
    .comment s!"ProofForge generated sBPF — {module.name} (Phase 1)",
    .comment "Target: solana-sbpf-asm (D-026)",
    .blankLine,
    .equDecl "INSTRUCTION_DATA_LEN" (instrDataOff - 8),
    .equDecl "INSTRUCTION_DATA" instrDataOff
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
    let (ctx', block) ← lowerEntrypoint epCtx instrDataOff ep
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

-- ============================================================================
-- Module rendering (IR → AST → text pipeline)
-- ============================================================================

def renderModule (module : IR.Module) : Except LowerError String := do
  let nodes ← lowerModule module
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