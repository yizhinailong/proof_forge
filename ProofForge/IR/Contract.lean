import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.IR

inductive ValueType where
  | unit
  | bool
  | u64
  | hash
  | fixedArray (element : ValueType) (length : Nat)
  deriving BEq, DecidableEq, Repr

def ValueType.name : ValueType → String
  | .unit => "Unit"
  | .bool => "Bool"
  | .u64 => "U64"
  | .hash => "Hash"
  | .fixedArray element length => s!"Array<{element.name},{length}>"

def ValueType.capabilities : ValueType → Array ProofForge.Target.Capability
  | .unit => #[]
  | .bool => #[]
  | .u64 => #[]
  | .hash => #[]
  | .fixedArray element _ => #[.dataFixedArray] ++ element.capabilities

inductive StateKind where
  | scalar
  | map (keyType : ValueType) (capacity : Nat)
  | array (length : Nat)
  deriving BEq, DecidableEq, Repr

structure StateDecl where
  id : String
  kind : StateKind
  type : ValueType
  deriving Repr

inductive Literal where
  | u64 (value : Nat)
  | bool (value : Bool)
  | hash4 (a b c d : Nat)
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
    | arrayLit (elementType : ValueType) (values : Array Expr)
    | arrayGet (array index : Expr)
    | add (lhs rhs : Expr)
    | hash (preimage : Expr)
    | hashTwoToOne (lhs rhs : Expr)
    | effect (effect : Effect)
    deriving Repr

  inductive Effect where
    | storageScalarRead (stateId : String)
    | storageScalarWrite (stateId : String) (value : Expr)
    | storageMapContains (stateId : String) (key : Expr)
    | storageMapGet (stateId : String) (key : Expr)
    | storageMapInsert (stateId : String) (key value : Expr)
    | storageMapSet (stateId : String) (key value : Expr)
    | storageArrayRead (stateId : String) (index : Expr)
    | storageArrayWrite (stateId : String) (index value : Expr)
    | contextRead (field : ContextField)
    deriving Repr
end

inductive Statement where
  | letBind (name : String) (type : ValueType) (value : Expr)
  | effect (effect : Effect)
  | assert (condition : Expr) (message : String)
  | assertEq (lhs rhs : Expr) (message : String)
  | boundedFor (indexName : String) (start stopExclusive : Nat) (body : Array Statement)
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
  | .storageMapContains _ _ => .storageMap
  | .storageMapGet _ _ => .storageMap
  | .storageMapInsert _ _ _ => .storageMap
  | .storageMapSet _ _ _ => .storageMap
  | .storageArrayRead _ _ => .storageArray
  | .storageArrayWrite _ _ _ => .storageArray
  | .contextRead field => field.capability

mutual
  partial def Expr.capabilities : Expr → Array ProofForge.Target.Capability
    | .literal _ => #[]
    | .local _ => #[]
    | .arrayLit elementType values =>
        elementType.capabilities ++ values.foldl (fun acc value => acc ++ value.capabilities) #[.dataFixedArray]
    | .arrayGet array index =>
        #[.dataFixedArray] ++ array.capabilities ++ index.capabilities
    | .add lhs rhs => lhs.capabilities ++ rhs.capabilities
    | .hash preimage => #[.cryptoHash] ++ preimage.capabilities
    | .hashTwoToOne lhs rhs => #[.cryptoHash] ++ lhs.capabilities ++ rhs.capabilities
    | .effect effect => #[effect.capability] ++ effect.capabilities

  partial def Effect.capabilities : Effect → Array ProofForge.Target.Capability
    | .storageScalarRead _ => #[]
    | .storageScalarWrite _ value => value.capabilities
    | .storageMapContains _ key => key.capabilities
    | .storageMapGet _ key => key.capabilities
    | .storageMapInsert _ key value => key.capabilities ++ value.capabilities
    | .storageMapSet _ key value => key.capabilities ++ value.capabilities
    | .storageArrayRead _ index => index.capabilities
    | .storageArrayWrite _ index value => index.capabilities ++ value.capabilities
    | .contextRead _ => #[]
end

def StateDecl.capabilities (state : StateDecl) : Array ProofForge.Target.Capability :=
  match state.kind with
  | .scalar => state.type.capabilities
  | .map keyType _ => #[.storageMap] ++ keyType.capabilities ++ state.type.capabilities
  | .array _ => #[.storageArray, .dataFixedArray] ++ state.type.capabilities

def Statement.capabilities : Statement → Array ProofForge.Target.Capability
  | .letBind _ type value => type.capabilities ++ value.capabilities
  | Statement.effect eff => #[eff.capability] ++ eff.capabilities
  | .assert condition _ => #[.assertions] ++ condition.capabilities
  | .assertEq lhs rhs _ => #[.assertions] ++ lhs.capabilities ++ rhs.capabilities
  | .boundedFor _ _ _ body =>
      #[.controlBoundedLoop] ++ body.foldl (fun acc stmt => acc ++ stmt.capabilities) #[]
  | .return value => value.capabilities

def Entrypoint.capabilities (entrypoint : Entrypoint) : Array ProofForge.Target.Capability :=
  let paramCaps := entrypoint.params.foldl (fun acc param => acc ++ param.snd.capabilities) #[]
  paramCaps ++ entrypoint.returns.capabilities ++
    entrypoint.body.foldl (fun acc stmt => acc ++ stmt.capabilities) #[]

def Module.capabilities (module : Module) : Array ProofForge.Target.Capability :=
  module.state.foldl (fun acc state => acc ++ state.capabilities) #[] ++
    module.entrypoints.foldl (fun acc entrypoint => acc ++ entrypoint.capabilities) #[]

end ProofForge.IR
