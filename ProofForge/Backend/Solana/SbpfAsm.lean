import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract

/-!
# Solana sBPF Assembly Backend

Architecture: IR.Module → `Array AstNode` → sBPF assembly text (`.s`)

The AST layer mirrors the blueshift-gg/sbpf assembler's AST (`ASTNode`,
`Instruction`, `Register`, `Number`, `Opcode`).  The lowering produces
structured AST nodes; the printer renders them to text.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

namespace ProofForge.Backend.Solana.SbpfAsm

open ProofForge.IR

-- ============================================================================
-- Metadata
-- ============================================================================

def targetId : String := "solana-sbpf-asm"
def artifactKind : String := "solana-elf"
def irVersion : String := "portable-ir-v0"

-- ============================================================================
-- sBPF AST (mirrors blueshift-gg/sbpf assembler structures)
-- ============================================================================

inductive Reg where
  | r0 | r1 | r2 | r3 | r4 | r5 | r6 | r7 | r8 | r9 | r10
  deriving BEq, Repr, Inhabited

def Reg.idx : Reg → Nat
  | .r0 => 0  | .r1 => 1  | .r2 => 2  | .r3 => 3  | .r4 => 4
  | .r5 => 5  | .r6 => 6  | .r7 => 7  | .r8 => 8  | .r9 => 9
  | .r10 => 10

def Reg.render (r : Reg) : String := s!"r{r.idx}"

inductive Imm where
  | num (n : Nat)
  | sym (name : String)
  deriving BEq, Repr, Inhabited

inductive Opcode where
  | lddw | ldxb | ldxh | ldxw | ldxdw
  | stb  | sth  | stw  | stdw
  | stxb | stxh | stxw | stxdw
  | add64 | sub64 | mul64 | div64 | mod64 | or64 | and64
  | lsh64 | rsh64 | xor64 | mov64 | arsh64 | neg64
  | add32 | sub32 | mul32 | div32 | mod32 | or32 | and32
  | lsh32 | rsh32 | xor32 | mov32 | arsh32 | neg32
  | ja | jeq | jne | jgt | jge | jlt | jle
  | jsgt | jsge | jslt | jsle | jset
  | call | callx | exit
  deriving BEq, Repr, Inhabited

def Opcode.render : Opcode → String
  | .lddw => "lddw"     | .ldxb => "ldxb"     | .ldxh => "ldxh"     | .ldxw => "ldxw"     | .ldxdw => "ldxdw"
  | .stb  => "stb"      | .sth  => "sth"      | .stw  => "stw"      | .stdw => "stdw"
  | .stxb => "stxb"     | .stxh => "stxh"     | .stxw => "stxw"     | .stxdw => "stxdw"
  | .add64 => "add64"   | .sub64 => "sub64"   | .mul64 => "mul64"   | .div64 => "div64"
  | .mod64 => "mod64"   | .or64  => "or64"    | .and64 => "and64"   | .lsh64 => "lsh64"
  | .rsh64 => "rsh64"   | .xor64 => "xor64"   | .mov64 => "mov64"   | .arsh64 => "arsh64" | .neg64 => "neg64"
  | .add32 => "add32"   | .sub32 => "sub32"   | .mul32 => "mul32"   | .div32 => "div32"
  | .mod32 => "mod32"   | .or32  => "or32"    | .and32 => "and32"   | .lsh32 => "lsh32"
  | .rsh32 => "rsh32"   | .xor32 => "xor32"   | .mov32 => "mov32"   | .arsh32 => "arsh32" | .neg32 => "neg32"
  | .ja   => "ja"       | .jeq  => "jeq"      | .jne  => "jne"      | .jgt  => "jgt"
  | .jge  => "jge"      | .jlt  => "jlt"      | .jle  => "jle"      | .jsgt => "jsgt"
  | .jsge => "jsge"     | .jslt => "jslt"     | .jsle => "jsle"     | .jset => "jset"
  | .call => "call"     | .callx => "callx"   | .exit => "exit"

inductive MemOff where
  | num (n : Nat)
  | sym (name : String)
  deriving BEq, Repr, Inhabited

structure Inst where
  opcode : Opcode
  dst  : Option Reg := none
  src  : Option Reg := none
  off  : Option MemOff := none
  imm  : Option Imm := none
  deriving Repr, Inhabited

-- Helper to build Inst concisely
def inst (opcode : Opcode) (dst : Option Reg := none) (src : Option Reg := none)
         (off : Option MemOff := none) (imm : Option Imm := none) : Inst :=
  { opcode, dst, src, off, imm }

inductive AstNode where
  | globalDecl  (label : String)
  | equDecl     (name : String) (value : Nat)
  | label      (name : String)
  | instruction (inst : Inst)
  | comment    (text : String)
  | blankLine
  deriving Repr, Inhabited

-- ============================================================================
-- AST → text printer
-- ============================================================================

def numStr (n : Nat) : String := toString n

def Imm.render : Imm → String
  | .num n => numStr n
  | .sym s => s

def MemOff.render : MemOff → String
  | .num n => numStr n
  | .sym s => s

def Opcode.isCondJump : Opcode → Bool
  | .jeq | .jne | .jgt | .jge | .jlt | .jle
  | .jsgt | .jsge | .jslt | .jsle | .jset => true
  | _ => false

/-- ALU opcodes whose second operand is a register. -/
def Opcode.isRegOp : Opcode → Bool
  | .add64 | .sub64 | .mul64 | .div64 | .mod64 | .or64 | .and64
  | .lsh64 | .rsh64 | .xor64 | .arsh64
  | .add32 | .sub32 | .mul32 | .div32 | .mod32 | .or32 | .and32
  | .lsh32 | .rsh32 | .xor32 | .arsh32 => true
  | _ => false

/-- Load/store opcodes. -/
def Opcode.isLoad : Opcode → Bool
  | .ldxb | .ldxh | .ldxw | .ldxdw => true
  | _ => false

def Opcode.isStore : Opcode → Bool
  | .stb | .sth | .stw | .stdw => true
  | _ => false

def Opcode.isStoreReg : Opcode → Bool
  | .stxb | .stxh | .stxw | .stxdw => true
  | _ => false

def memSign (base : Reg) : String := if base == .r10 then "-" else "+"

/-- Render one instruction to an indented line. -/
def Inst.render (i : Inst) : String :=
  let op := i.opcode.render
  let dstStr (r : Reg) : String := r.render
  let body :=
    if i.opcode == .exit then ""
    else if i.opcode == .call then
      match i.imm with | some (.sym n) => s!" {n}" | _ => ""
    else if i.opcode == .callx then
      match i.dst with | some r => s!" {dstStr r}" | none => ""
    else if i.opcode == .ja then
      match i.off with | some o => s!" {o.render}" | none => ""
    else if i.opcode == .lddw then
      s!" {dstStr (i.dst.getD .r0)}, {i.imm.getD (.num 0) |>.render}"
    else if i.opcode.isLoad then
      let base := dstStr (i.src.getD .r1)
      let off := i.off.getD (.num 0) |>.render
      s!" {dstStr (i.dst.getD .r0)}, [{base}{memSign (i.src.getD .r1)}{off}]"
    else if i.opcode.isStore then
      let base := dstStr (i.dst.getD .r1)
      let off := i.off.getD (.num 0) |>.render
      let val := i.imm.getD (.num 0) |>.render
      s!" [{base}{memSign (i.dst.getD .r1)}{off}], {val}"
    else if i.opcode.isStoreReg then
      let base := dstStr (i.dst.getD .r1)
      let off := i.off.getD (.num 0) |>.render
      let val := dstStr (i.src.getD .r0)
      s!" [{base}{memSign (i.dst.getD .r1)}{off}], {val}"
    else if i.opcode.isCondJump then
      let arg2 : String := match i.imm with | some imm => imm.render | none => dstStr (i.src.getD .r0)
      let target : String := match i.off with | some o => o.render | none => "?"
      s!" {dstStr (i.dst.getD .r0)}, {arg2}, {target}"
    else if i.opcode.isRegOp then
      let arg2 : String := match i.imm with | some imm => imm.render | none => dstStr (i.src.getD .r0)
      s!" {dstStr (i.dst.getD .r0)}, {arg2}"
    else
      let arg : String := match i.imm with | some imm => imm.render | none => dstStr (i.src.getD .r0)
      s!" {dstStr (i.dst.getD .r0)}, {arg}"
  s!"  {op}{body}"

/-- Render one AST node to one or more lines. -/
def AstNode.render (node : AstNode) : Array String :=
  match node with
  | .globalDecl lbl  => #[ s!".globl {lbl}" ]
  | .equDecl name val => #[ s!".equ {name}, {numStr val}" ]
  | .label name      => #[ s!"{name}:" ]
  | .instruction i   => #[ i.render ]
  | .comment text    => #[ "  ; " ++ text ]
  | .blankLine       => #[""]

/-- Render a list of AST nodes to assembly text. -/
def renderNodes (nodes : Array AstNode) : String :=
  let lines := nodes.foldl (init := #[]) fun acc node => acc ++ node.render
  String.intercalate "\n" lines.toList ++ "\n"

-- ============================================================================
-- Error type
-- ============================================================================

structure LowerError where
  message : String
  deriving Repr, Inhabited

def LowerError.render (err : LowerError) : String := err.message

-- ============================================================================
-- Serialized input layout
-- ============================================================================

def ACCOUNT_HEADER_SIZE : Nat := 8
def PUBKEY_SIZE : Nat := 32
def U64_SIZE : Nat := 8
def MAX_PERMITTED_DATA_INCREASE : Nat := 10240

def alignTo8 (n : Nat) : Nat :=
  let r := n % 8
  if r == 0 then 0 else 8 - r

def computeSingleAccountLayout (dataSize : Nat) : Nat × Nat :=
  let numAccounts := U64_SIZE
  let dataStart := numAccounts + ACCOUNT_HEADER_SIZE + PUBKEY_SIZE + PUBKEY_SIZE + U64_SIZE + U64_SIZE
  let afterPadding := dataStart + dataSize + MAX_PERMITTED_DATA_INCREASE
  let align := alignTo8 afterPadding
  let rentEpochEnd := afterPadding + align + U64_SIZE
  let instrDataStart := rentEpochEnd + U64_SIZE
  (dataStart, instrDataStart)

def moduleDataSize (module : Module) : Nat := module.state.size * 8

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

def buildCtx (module : Module) : Except LowerError LowerCtx := do
  let dataSize := moduleDataSize module
  let (acctDataOff, _) := computeSingleAccountLayout dataSize
  let mut stateOffsets := #[]
  let mut fieldOff := 0
  for state in module.state do
    stateOffsets := stateOffsets.push (state.id, acctDataOff + fieldOff)
    fieldOff := fieldOff + 8
  return { stateFieldOffsets := stateOffsets, locals := #[], nextLocalOffset := 8, scratchOffset := 8 }

-- ============================================================================
-- IR expression → AST nodes (result in r2, r3 as scratch)
-- ============================================================================

/-- Produce an `Inst` with dst = r2 and the given fields. -/
def res (opcode : Opcode) (src : Option Reg := none) (off : Option MemOff := none) (imm : Option Imm := none) : Inst :=
  { opcode, dst := some .r2, src, off, imm }

/-- Combine already-lowered LHS/RHS nodes for a binary ALU op. -/
def lowerBinaryCombine (lhsNodes rhsNodes : Array AstNode) (op : Opcode) (scratchOffset : Nat) : Array AstNode :=
  lhsNodes ++ #[
    .instruction { opcode := .stxdw, dst := some .r10, off := some (.num scratchOffset), src := some .r2 }
  ] ++ rhsNodes ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num scratchOffset) },
    .instruction { opcode := op, dst := some .r2, src := some .r3 }
  ]

partial def lowerExpr (ctx : LowerCtx) (expr : IR.Expr) : Except LowerError (Array AstNode) :=
  match expr with
  | .literal (.u64 n) =>
    .ok #[ .instruction (res .mov64 (imm := some (.num n))) ]
  | .literal (.u32 n) =>
    .ok #[ .instruction (res .mov32 (imm := some (.num n))) ]
  | .literal (.bool true) =>
    .ok #[ .instruction (res .mov64 (imm := some (.num 1))) ]
  | .literal (.bool false) =>
    .ok #[ .instruction (res .mov64 (imm := some (.num 0))) ]
  | .literal _ => .error { message := "unsupported literal type in Phase 1" }
  | .local name =>
    match ctx.localOffset? name with
    | some off => .ok #[ .instruction (res .ldxdw (src := some .r10) (off := some (.num off))) ]
    | none => .error { message := s!"unknown local: {name}" }
  | .add lhs rhs  => do let ln ← lowerExpr ctx lhs; let rn ← lowerExpr ctx rhs; .ok (lowerBinaryCombine ln rn .add64 ctx.scratchOffset)
  | .sub lhs rhs  => do let ln ← lowerExpr ctx lhs; let rn ← lowerExpr ctx rhs; .ok (lowerBinaryCombine ln rn .sub64 ctx.scratchOffset)
  | .mul lhs rhs  => do let ln ← lowerExpr ctx lhs; let rn ← lowerExpr ctx rhs; .ok (lowerBinaryCombine ln rn .mul64 ctx.scratchOffset)
  | .div lhs rhs  => do let ln ← lowerExpr ctx lhs; let rn ← lowerExpr ctx rhs; .ok (lowerBinaryCombine ln rn .div64 ctx.scratchOffset)
  | .mod lhs rhs  => do let ln ← lowerExpr ctx lhs; let rn ← lowerExpr ctx rhs; .ok (lowerBinaryCombine ln rn .mod64 ctx.scratchOffset)
  | .effect (.storageScalarRead stateId) =>
    match ctx.stateAbsOff? stateId with
    | some absOff => .ok #[ .instruction (res .ldxdw (src := some .r1) (off := some (.num absOff))) ]
    | none => .error { message := s!"unknown state: {stateId}" }
  | .effect (.storagePathRead stateId path) =>
    if path.isEmpty then
      match ctx.stateAbsOff? stateId with
      | some absOff => .ok #[ .instruction (res .ldxdw (src := some .r1) (off := some (.num absOff))) ]
      | none => .error { message := s!"unknown state: {stateId}" }
    else .error { message := "storage path read with non-empty path not supported in Phase 1" }
  | _ => .error { message := "unsupported expression in Phase 1" }

-- ============================================================================
-- IR statement → AST nodes
-- ============================================================================

partial def lowerStmt (ctx : LowerCtx) (stmt : IR.Statement) : Except LowerError (Array AstNode × LowerCtx) :=
  match stmt with
  | .letBind name _ value => do
    let vn ← lowerExpr ctx value
    let ctx' := ctx.addLocal name
    let off := ctx.nextLocalOffset
    let ctx' := ctx.addLocal name
    .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx')
  | .letMutBind name _ value => do
    let vn ← lowerExpr ctx value
    let off := ctx.nextLocalOffset
    let ctx' := ctx.addLocal name
    .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx')
  | .assign target value =>
    match target with
    | .local name =>
      match ctx.localOffset? name with
      | some off => do
        let vn ← lowerExpr ctx value
        .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r10, off := some (.num off), src := some .r2 } ], ctx)
      | none => .error { message := s!"assign to unknown local: {name}" }
    | _ => .error { message := "assign to non-local not supported in Phase 1" }
  | .effect (.storageScalarWrite stateId value) => do
    match ctx.stateAbsOff? stateId with
    | some absOff => do
      let vn ← lowerExpr ctx value
      .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 } ], ctx)
    | none => .error { message := s!"unknown state: {stateId}" }
  | .effect (.storagePathWrite stateId path value) =>
    if path.isEmpty then
      match ctx.stateAbsOff? stateId with
      | some absOff => do
        let vn ← lowerExpr ctx value
        .ok (vn ++ #[ .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 } ], ctx)
      | none => .error { message := s!"unknown state: {stateId}" }
    else .error { message := "storage path write with non-empty path not supported in Phase 1" }
  | .effect (.storageScalarAssignOp stateId op value) => do
    match ctx.stateAbsOff? stateId with
    | some absOff => do
      let op : Opcode := match op with | .add => .add64 | .sub => .sub64 | .mul => .mul64 | .div => .div64 | .mod => .mod64 | _ => .add64
      let vn ← lowerExpr ctx value
      let sc := ctx.scratchOffset
      .ok (#[
        .instruction { opcode := .ldxdw, dst := some .r3, src := some .r1, off := some (.num absOff) },
        .instruction { opcode := .stxdw, dst := some .r10, off := some (.num sc), src := some .r3 }
      ] ++ vn ++ #[
        .instruction { opcode := .ldxdw, dst := some .r3, src := some .r10, off := some (.num sc) },
        .instruction { opcode := op, dst := some .r2, src := some .r3 },
        .instruction { opcode := .stxdw, dst := some .r1, off := some (.num absOff), src := some .r2 }
      ], ctx)
    | none => .error { message := s!"unknown state: {stateId}" }
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

partial def lowerEntrypoint (ctx : LowerCtx) (ep : IR.Entrypoint) : Except LowerError (Array AstNode) := do
  let mut nodes := #[
    .label s!"sol_{ep.name}",
    .blankLine
  ]
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
  .ok nodes

-- ============================================================================
-- Module → AST nodes
-- ============================================================================

partial def lowerModule (module : IR.Module) : Except LowerError (Array AstNode) := do
  let ctx ← buildCtx module
  let dataSize := moduleDataSize module
  let (_, instrDataOff) := computeSingleAccountLayout dataSize

  let mut nodes := #[
    .comment s!"ProofForge generated sBPF — {module.name} (Phase 1)",
    .comment "Target: solana-sbpf-asm (D-026)",
    .blankLine,
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

  for ep in module.entrypoints do
    nodes := nodes.push .blankLine
    let block ← lowerEntrypoint ctx ep
    nodes := nodes ++ block

  nodes := nodes ++ #[
    .blankLine,
    .label "assert_fail",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 2) },
    .instruction { opcode := .exit },
    .blankLine,
    .label "assert_eq_fail",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 3) },
    .instruction { opcode := .exit }
  ]
  .ok nodes

-- ============================================================================
-- Module rendering (IR → AST → text pipeline)
-- ============================================================================

def renderModule (module : IR.Module) : Except LowerError String := do
  let nodes ← lowerModule module
  .ok (renderNodes nodes)

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