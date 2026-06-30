import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.IR

inductive ValueType where
  | unit
  | bool
  | u64
  deriving BEq, DecidableEq, Repr

def ValueType.name : ValueType → String
  | .unit => "Unit"
  | .bool => "Bool"
  | .u64 => "U64"

inductive StateKind where
  | scalar
  deriving BEq, DecidableEq, Repr

structure StateDecl where
  id : String
  kind : StateKind
  type : ValueType
  deriving Repr

inductive Literal where
  | u64 (value : Nat)
  | bool (value : Bool)
  deriving BEq, Repr

inductive ContextField where
  | userId
  | contractId
  | checkpointId
  deriving BEq, DecidableEq, Repr

def ContextField.name : ContextField → String
  | .userId => "userId"
  | .contractId => "contractId"
  | .checkpointId => "checkpointId"

def ContextField.capability : ContextField → ProofForge.Target.Capability
  | .userId => .callerSender
  | .contractId => .accountExplicit
  | .checkpointId => .envBlock

mutual
  inductive Expr where
    | literal (value : Literal)
    | local (name : String)
    | add (lhs rhs : Expr)
    | effect (effect : Effect)
    deriving Repr

  inductive Effect where
    | storageScalarRead (stateId : String)
    | storageScalarWrite (stateId : String) (value : Expr)
    | contextRead (field : ContextField)
    deriving Repr
end

inductive Statement where
  | letBind (name : String) (value : Expr)
  | effect (effect : Effect)
  | return (value : Expr)
  deriving Repr

structure Entrypoint where
  name : String
  selector? : Option String := none
  params : Array (String × ValueType) := #[]
  returns : ValueType := .unit
  body : Array Statement
  deriving Repr

structure Module where
  name : String
  state : Array StateDecl
  entrypoints : Array Entrypoint
  deriving Repr

def Effect.capability : Effect → ProofForge.Target.Capability
  | .storageScalarRead _ => .storageScalar
  | .storageScalarWrite _ _ => .storageScalar
  | .contextRead field => field.capability

mutual
  partial def Expr.capabilities : Expr → Array ProofForge.Target.Capability
    | .literal _ => #[]
    | .local _ => #[]
    | .add lhs rhs => lhs.capabilities ++ rhs.capabilities
    | .effect effect => #[effect.capability] ++ effect.capabilities

  partial def Effect.capabilities : Effect → Array ProofForge.Target.Capability
    | .storageScalarRead _ => #[]
    | .storageScalarWrite _ value => value.capabilities
    | .contextRead _ => #[]
end

def Statement.capabilities : Statement → Array ProofForge.Target.Capability
  | .letBind _ value => value.capabilities
  | Statement.effect eff => #[eff.capability] ++ eff.capabilities
  | .return value => value.capabilities

def Entrypoint.capabilities (entrypoint : Entrypoint) : Array ProofForge.Target.Capability :=
  entrypoint.body.foldl (fun acc stmt => acc ++ stmt.capabilities) #[]

def Module.capabilities (module : Module) : Array ProofForge.Target.Capability :=
  module.entrypoints.foldl (fun acc entrypoint => acc ++ entrypoint.capabilities) #[]

end ProofForge.IR
