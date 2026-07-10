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
    (yul.contains "if gt(__pf_packed_value, 255)")
    "checked packed assign_op fixture must reject values above the field mask"
  require
    ((yul.splitOn "if gt(__pf_packed_value, 255)").length >= 3)
    "checked packed direct writes and assign_op must each guard the destination field width"
  require
    (yul.contains "let __pf_packed_value := __pf_checked_add(255, 1)")
    "checked packed direct writes must evaluate the checked expression once before the width guard"

def main : IO UInt32 := do
  testLowOrderReadAndMaskedWrite
  testCheckedAssignOpRejectsNarrowOverflow
  testWrappingAssignOpTruncatesToFieldWidth
  testConstructorUsesLowOrderPacking
  testWrappingFixtureMasksBeforeNeighborBits
  IO.println "evm-packed-storage: ok"
  return 0

end ProofForge.Tests.EvmPackedStorage

def main : IO UInt32 :=
  ProofForge.Tests.EvmPackedStorage.main
