import ProofForge.Backend.Evm.ConstructorInit
import ProofForge.Backend.Evm.IR
import ProofForge.Compiler.Yul.Printer
import ProofForge.IR.Examples.EvmPackedStorageProbe

namespace ProofForge.Tests.EvmPackedStorage

open ProofForge.Backend.Evm.Plan
open ProofForge.Backend.Evm.ToYul
open Lean.Compiler.Yul

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def renderExpr (expr : Expr) : String :=
  Printer.printExpr expr

def renderStatement (stmt : Statement) : String :=
  Printer.printStatement 0 stmt

def requirePackedWrite
    (statements : Array Statement)
    (expectedShift expectedMask : Nat)
    (expectedValue : String)
    (message : String) : IO Unit := do
  require (statements.size == 1) s!"{message}: expected one sstore"
  let rendered := renderStatement statements[0]!
  require
    (rendered.contains s!"not(shl({expectedShift}, {expectedMask}))")
    s!"{message}: field-clear mask must use the low-order byte offset, got: {rendered}"
  require
    (rendered.contains s!"shl({expectedShift}, and({expectedValue}, {expectedMask}))")
    s!"{message}: packed value must be masked before shifting, got: {rendered}"

def testLowOrderReadAndMaskedWrite : IO Unit := do
  let readExpr := scalarStoragePackedReadExpr (.num 7) 1 1
  require
    (renderExpr readExpr == "and(shr(8, sload(7)), 255)")
    s!"packed reads must use Solidity low-order offsets, got: {renderExpr readExpr}"
  requirePackedWrite
    (scalarStorageWriteStatements (.num 7) (.id "value") 1 1)
    8
    255
    "value"
    "packed scalar write"

def testCheckedAssignOpRejectsNarrowOverflow : IO Unit := do
  let statements := scalarStorageAssignOpStatements true .add (.num 7) (.num 1) 1 1
  require (statements.size == 1) "checked packed assign_op must remain one scoped statement"
  let rendered := renderStatement statements[0]!
  require
    (rendered.contains "let __pf_packed_value := __pf_checked_add(and(shr(8, sload(7)), 255), 1)")
    s!"checked packed assign_op must evaluate its value exactly once in local scope, got: {rendered}"
  require
    (rendered.contains "if gt(__pf_packed_value, 255)")
    s!"checked packed assign_op must reject values above the field mask, got: {rendered}"
  require
    (rendered.contains "revert(0, 0)")
    s!"checked packed assign_op width guard must fail closed, got: {rendered}"
  require
    (rendered.contains "shl(8, and(__pf_packed_value, 255))")
    s!"checked packed assign_op must mask the guarded local before shifting, got: {rendered}"

def testWrappingAssignOpTruncatesToFieldWidth : IO Unit := do
  let statements := scalarStorageAssignOpStatements false .add (.num 7) (.num 1) 1 1
  requirePackedWrite
    statements
    8
    255
    "add(and(shr(8, sload(7)), 255), 1)"
    "wrapping packed assign_op"

def requirePackedWidthGuard
    (statements : Array Statement)
    (expectedValue expectedMask message : String) : IO Unit := do
  require (statements.size == 1) s!"{message}: expected one scoped statement"
  let rendered := renderStatement statements[0]!
  require
    (rendered.contains s!"let __pf_packed_value := {expectedValue}")
    s!"{message}: write value must be evaluated once, got: {rendered}"
  require
    (rendered.contains s!"if gt(__pf_packed_value, {expectedMask})")
    s!"{message}: checked write must guard destination width, got: {rendered}"

def testDirectWriteSemanticsAreExplicit : IO Unit := do
  let checkedTarget : ScalarStorageTargetPlan := {
    slot := .scalarSlot 7
    byteOffset := 1
    byteWidth := 1
    writeSemantics := .checked
  }
  let wrappingTarget : ScalarStorageTargetPlan := {
    checkedTarget with writeSemantics := .wrapping
  }
  let lowerExpr : ProofForge.IR.Expr → Except String Expr :=
    fun _ => .error "raw expression lowering is not expected"
  let lowerEffect : EffectPlan → Except String Expr :=
    fun _ => .error "nested effect lowering is not expected"
  let checkedLiteral ←
    match scalarStorageTargetEffectPlanStatements
        id lowerExpr lowerEffect
        (.storageScalarWriteTarget checkedTarget (.literalWord 256)) with
    | .ok statements => pure statements
    | .error err => throw <| IO.userError err
  requirePackedWidthGuard checkedLiteral "256" "255" "checked packed literal write"
  let checkedLocal ←
    match scalarStorageTargetEffectPlanStatements
        id lowerExpr lowerEffect
        (.storageScalarWriteTarget checkedTarget (.local "value")) with
    | .ok statements => pure statements
    | .error err => throw <| IO.userError err
  requirePackedWidthGuard checkedLocal "value" "255" "checked packed local write"
  let wrappingLiteral ←
    match scalarStorageTargetEffectPlanStatements
        id lowerExpr lowerEffect
        (.storageScalarWriteTarget wrappingTarget (.literalWord 256)) with
    | .ok statements => pure statements
    | .error err => throw <| IO.userError err
  let wrappingRendered := renderStatement wrappingLiteral[0]!
  require
    (!wrappingRendered.contains "if gt(")
    s!"wrapping packed write must not inject a checked guard, got: {wrappingRendered}"
  require
    (wrappingRendered.contains "shl(8, and(256, 255))")
    s!"wrapping packed write must deliberately truncate, got: {wrappingRendered}"

def testLowerCarriesDirectWriteSemantics : IO Unit := do
  let module := ProofForge.IR.Examples.EvmPackedStorageProbe.module
  let requireMode
      (effect : ProofForge.IR.Effect)
      (env : ProofForge.Backend.Evm.Validate.TypeEnv)
      (expected : ScalarStorageWriteSemantics)
      (label : String) : IO Unit := do
    match ProofForge.Backend.Evm.Lower.buildEffectPlan module env effect with
    | .ok (.storageScalarWriteTarget target _) =>
        require (target.writeSemantics == expected)
          s!"{label}: wrong planned write semantics"
    | .ok _ => throw <| IO.userError s!"{label}: expected planned scalar target"
    | .error err => throw <| IO.userError s!"{label}: {err.message}"
  requireMode
    (.storageScalarWrite "counter" (.literal (.u8 1)))
    #[]
    .checked
    "checked literal"
  requireMode
    (.storageScalarWrite "counter" (.local "candidate"))
    #[{ name := "candidate", type := .u8, isMutable := false }]
    .checked
    "checked local"
  requireMode
    (.storageScalarWrite "counter"
      (.add (.literal (.u8 255)) (.literal (.u8 1)) false))
    #[]
    .wrapping
    "explicit wrapping expression"

def requireAbiUpperBoundGuard
    (type : ProofForge.IR.ValueType)
    (expectedLimit label : String) : IO Unit := do
  let some statement := abiWordValidationStatement? (.id "value") type
    | throw <| IO.userError s!"{label}: missing ABI upper-bound guard"
  let rendered := renderStatement statement
  require
    (rendered.contains s!"gt(value, {expectedLimit})")
    s!"{label}: wrong ABI upper-bound guard, got: {rendered}"

def testNarrowAbiWordGuards : IO Unit := do
  requireAbiUpperBoundGuard .u8 "255" "u8"
  requireAbiUpperBoundGuard .u32 "4294967295" "u32"
  requireAbiUpperBoundGuard .u64 "18446744073709551615" "u64"
  requireAbiUpperBoundGuard .u128 "340282366920938463463374607431768211455" "u128"
  requireAbiUpperBoundGuard .address
    "1461501637330902918203684832716283019655932542975"
    "address"
  requireAbiUpperBoundGuard .bool "1" "bool"

def testAbiWordOverridesDriveCanonicalGuards : IO Unit := do
  let entrypoint : ProofForge.IR.Entrypoint := {
    name := "abi_overrides"
    params := #[
      ("recipient", .u64),
      ("interface_id", .u64),
      ("plain", .u64)
    ]
    paramAbiWords := #[some "address", some "bytes4", none]
    body := #[]
  }
  let module : ProofForge.IR.Module := {
    name := "AbiOverrideProbe"
    state := #[]
    entrypoints := #[entrypoint]
  }
  let plans ← match ProofForge.Backend.Evm.Lower.entrypointParamPlans module entrypoint with
    | .ok plans => pure plans
    | .error err => throw <| IO.userError err.message
  require (plans.size == 3) "ABI override probe must lower all parameters"
  require (plans[0]!.abiWord? == some "address")
    "address ABI override must survive the EVM plan boundary"
  require (plans[1]!.abiWord? == some "bytes4")
    "bytes4 ABI override must survive the EVM plan boundary"
  require (plans[2]!.abiWord?.isNone)
    "plain U64 parameter must remain override-free"
  let rendered := String.intercalate "\n"
    ((abiParamHeadValidationStatements plans).toList.map renderStatement)
  require
    (rendered.contains "gt(calldataload(4), 1461501637330902918203684832716283019655932542975)")
    s!"address override must use the 160-bit canonical guard, got: {rendered}"
  require
    (rendered.contains
      "and(calldataload(36), 26959946667150639794667015087019630673637144422540572481103610249215)")
    s!"bytes4 override must reject non-zero right padding, got: {rendered}"
  require
    (rendered.contains "gt(calldataload(68), 18446744073709551615)")
    s!"plain U64 parameters must retain their 64-bit guard, got: {rendered}"

def testConstructorUsesLowOrderPacking : IO Unit := do
  let state : StorageStatePlan := {
    id := "counter"
    slot := 3
    span := 0
    kind := .scalar
    type := .u8
    byteOffset := 1
    byteWidth := 1
  }
  let rendered := ProofForge.Backend.Evm.ConstructorInit.storePackedU64 state "value"
  require
    (rendered.contains "not(shl(8, 255))")
    s!"constructor packed clear mask must use the low-order byte offset, got: {rendered}"
  require
    (rendered.contains "shl(8, and(value, 255))")
    s!"constructor packed value must use the low-order byte offset, got: {rendered}"

def testWrappingFixtureMasksBeforeNeighborBits : IO Unit := do
  let module := ProofForge.IR.Examples.EvmPackedStorageProbe.module
  require
    (module.entrypoints.any (fun entrypoint => entrypoint.name == "packed_assign_op_wraps"))
    "packed storage fixture must expose the wrapping-width regression entrypoint"
  let yul ←
    match ProofForge.Backend.Evm.IR.renderModule module with
    | .ok yul => pure yul
    | .error err => throw <| IO.userError s!"packed storage fixture render failed: {err.render}"
  require
    (yul.contains "and(add(255, 1), 255)")
    "wrapping packed expression fixture must truncate before shifting into its shared slot"
  require
    (yul.contains "f_EvmPackedStorageProbe_packed_assign_op_overflow_reverts")
    "packed storage fixture must expose the checked-width overflow regression entrypoint"
  require
    (yul.contains "f_EvmPackedStorageProbe_packed_checked_write_overflow_reverts")
    "packed storage fixture must expose the checked direct-write overflow regression entrypoint"
  require
    (yul.contains "f_EvmPackedStorageProbe_packed_checked_literal_write_overflow_reverts")
    "packed storage fixture must expose the checked literal-write regression entrypoint"
  require
    (yul.contains "f_EvmPackedStorageProbe_packed_checked_local_write_overflow_reverts")
    "packed storage fixture must expose the checked local-write regression entrypoint"
  require
    (yul.contains "f_EvmPackedStorageProbe_packed_checked_write_param")
    "packed storage fixture must expose the narrow calldata regression entrypoint"
  require
    (yul.contains "if gt(__pf_packed_value, 255)")
    "checked packed assign_op fixture must reject values above the field mask"
  require
    ((yul.splitOn "if gt(__pf_packed_value, 255)").length >= 3)
    "checked packed direct writes and assign_op must each guard the destination field width"
  require
    (yul.contains "let __pf_packed_value := __pf_checked_add(255, 1)")
    "checked packed direct writes must evaluate the checked expression once before the width guard"
  require
    (yul.contains "let __pf_packed_value := 256")
    "checked packed literal writes must guard values without arithmetic"
  require
    (yul.contains "let __pf_packed_value := candidate")
    "checked packed local writes must guard values without arithmetic"
  require
    (yul.contains "if gt(calldataload(4), 255)")
    "u8 entrypoint calldata must reject non-canonical words"

def main : IO UInt32 := do
  testLowOrderReadAndMaskedWrite
  testCheckedAssignOpRejectsNarrowOverflow
  testWrappingAssignOpTruncatesToFieldWidth
  testDirectWriteSemanticsAreExplicit
  testLowerCarriesDirectWriteSemantics
  testNarrowAbiWordGuards
  testAbiWordOverridesDriveCanonicalGuards
  testConstructorUsesLowOrderPacking
  testWrappingFixtureMasksBeforeNeighborBits
  IO.println "evm-packed-storage: ok"
  return 0

end ProofForge.Tests.EvmPackedStorage

def main : IO UInt32 :=
  ProofForge.Tests.EvmPackedStorage.main
