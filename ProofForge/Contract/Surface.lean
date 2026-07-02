import Lean
import ProofForge.Contract.Builder

namespace ProofForge.Contract.Surface

open ProofForge.IR

abbrev ModuleM := ProofForge.Contract.Builder.ModuleM
abbrev EntryM := ProofForge.Contract.Builder.EntryM

structure ScalarRef where
  id : String
  type : ValueType
  deriving BEq, Repr

structure BindingRef where
  id : String
  type : ValueType
  deriving BEq, Repr

structure MethodRef where
  name : String
  selector? : Option String := none
  params : Array BindingRef := #[]
  returns : ValueType := .unit
  deriving BEq, Repr

structure EventRef where
  name : String
  deriving BEq, Repr

structure EventField where
  name : String
  value : ProofForge.IR.Expr
  deriving Repr

def contract (name : String) (body : ModuleM Unit) : ContractSpec :=
  ProofForge.Contract.Builder.build name body

def slot (id : String) (type : ValueType) : ScalarRef :=
  { id, type }

def binding (id : String) (type : ValueType) : BindingRef :=
  { id, type }

def event (name : String) : EventRef :=
  { name }

def methodWithSelector (name selector : String) (params : Array BindingRef := #[])
    (returns : ValueType := .unit) : MethodRef :=
  { name, selector? := some selector, params, returns }

def method (name : String) (params : Array BindingRef := #[])
    (returns : ValueType := .unit) : MethodRef :=
  { name, selector? := none, params, returns }

private def identNameLit (name : Lean.TSyntax `ident) : Lean.TSyntax `term :=
  ⟨Lean.Syntax.mkStrLit name.getId.toString⟩

macro "state_ref " name:ident " : " type:term : command => do
  let nameLit := identNameLit name
  `(def $name : ScalarRef := slot $nameLit $type)

macro "binding_ref " name:ident " : " type:term : command => do
  let nameLit := identNameLit name
  `(def $name : BindingRef := binding $nameLit $type)

macro "event_ref " name:ident : command => do
  let nameLit := identNameLit name
  `(def $name : EventRef := event $nameLit)

macro "method_ref " name:ident " : " params:term : command => do
  let nameLit := identNameLit name
  `(def $name : MethodRef := method $nameLit $params)

macro "method_ref " name:ident " returns " "(" returns:term ")" " : " params:term : command => do
  let nameLit := identNameLit name
  `(def $name : MethodRef := method $nameLit $params $returns)

def scalar (ref : ScalarRef) : ModuleM Unit :=
  ProofForge.Contract.Builder.scalarState ref.id ref.type

def entry (method : MethodRef) (body : EntryM Unit) : ModuleM Unit :=
  ProofForge.Contract.Builder.entryFull
    method.name
    method.selector?
    method.returns
    (method.params.map fun param => (param.id, param.type))
    body

def bind (ref : BindingRef) (value : ProofForge.IR.Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.letBind ref.id ref.type value

def ref (binding : BindingRef) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.localVar binding.id

def read (slot : ScalarRef) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.storageScalarRead slot.id

def write (slot : ScalarRef) (value : ProofForge.IR.Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.effect
    (ProofForge.Contract.Builder.storageScalarWrite slot.id value)

def field (name : String) (value : ProofForge.IR.Expr) : EventField :=
  { name, value }

def fieldOf (binding : BindingRef) : EventField :=
  field binding.id (ref binding)

def fieldAs (slot : ScalarRef) (value : ProofForge.IR.Expr) : EventField :=
  field slot.id value

def emitNamed (name : String) (fields : Array EventField) : EntryM Unit :=
  ProofForge.Contract.Builder.effect
    (ProofForge.Contract.Builder.eventEmit name (fields.map fun field => (field.name, field.value)))

def emit (event : EventRef) (fields : Array EventField) : EntryM Unit :=
  emitNamed event.name fields

def ret (value : ProofForge.IR.Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.ret value

def checkpointId : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.contextRead .checkpointId

def u64 (value : Nat) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.u64 value

def add (lhs rhs : ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.add lhs rhs

def sub (lhs rhs : ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.sub lhs rhs

def mul (lhs rhs : ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.mul lhs rhs

def div (lhs rhs : ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  ProofForge.Contract.Builder.div lhs rhs

end ProofForge.Contract.Surface
