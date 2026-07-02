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
  selector : String
  params : Array BindingRef := #[]
  returns : ValueType := .unit
  deriving BEq, Repr

structure EventField where
  name : String
  value : Expr
  deriving Repr

def contract (name : String) (body : ModuleM Unit) : ContractSpec :=
  ProofForge.Contract.Builder.build name body

def slot (id : String) (type : ValueType) : ScalarRef :=
  { id, type }

def binding (id : String) (type : ValueType) : BindingRef :=
  { id, type }

def method (name selector : String) (params : Array BindingRef := #[])
    (returns : ValueType := .unit) : MethodRef :=
  { name, selector, params, returns }

def scalar (ref : ScalarRef) : ModuleM Unit :=
  ProofForge.Contract.Builder.scalarState ref.id ref.type

def entry (method : MethodRef) (body : EntryM Unit) : ModuleM Unit :=
  ProofForge.Contract.Builder.entryFull
    method.name
    (some method.selector)
    method.returns
    (method.params.map fun param => (param.id, param.type))
    body

def bind (ref : BindingRef) (value : Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.letBind ref.id ref.type value

def ref (binding : BindingRef) : Expr :=
  ProofForge.Contract.Builder.localVar binding.id

def read (slot : ScalarRef) : Expr :=
  ProofForge.Contract.Builder.storageScalarRead slot.id

def write (slot : ScalarRef) (value : Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.effect
    (ProofForge.Contract.Builder.storageScalarWrite slot.id value)

def field (name : String) (value : Expr) : EventField :=
  { name, value }

def fieldOf (binding : BindingRef) : EventField :=
  field binding.id (ref binding)

def fieldAs (slot : ScalarRef) (value : Expr) : EventField :=
  field slot.id value

def emit (name : String) (fields : Array EventField) : EntryM Unit :=
  ProofForge.Contract.Builder.effect
    (ProofForge.Contract.Builder.eventEmit name (fields.map fun field => (field.name, field.value)))

def ret (value : Expr) : EntryM Unit :=
  ProofForge.Contract.Builder.ret value

def checkpointId : Expr :=
  ProofForge.Contract.Builder.contextRead .checkpointId

def u64 (value : Nat) : Expr :=
  ProofForge.Contract.Builder.u64 value

def add (lhs rhs : Expr) : Expr :=
  ProofForge.Contract.Builder.add lhs rhs

def sub (lhs rhs : Expr) : Expr :=
  ProofForge.Contract.Builder.sub lhs rhs

def mul (lhs rhs : Expr) : Expr :=
  ProofForge.Contract.Builder.mul lhs rhs

def div (lhs rhs : Expr) : Expr :=
  ProofForge.Contract.Builder.div lhs rhs

end ProofForge.Contract.Surface
