import ProofForge.Contract.Spec
import ProofForge.IR.Contract

namespace ProofForge.Contract.Learn

open ProofForge.IR

inductive Token where
  | ident (value : String)
  | number (value : Nat)
  | symbol (value : String)
  deriving Repr

inductive BinaryOp where
  | add
  | sub
  | mul
  | div
  deriving Repr

inductive Expr where
  | number (value : Nat)
  | name (value : String)
  | call0 (name : String)
  | binary (op : BinaryOp) (lhs rhs : Expr)
  deriving Repr

structure FieldDecl where
  name : String
  type : ValueType
  deriving Repr

abbrev ParamDecl := FieldDecl

inductive Stmt where
  | letBind (name : String) (type : ValueType) (value : Expr)
  | assign (target : String) (value : Expr)
  | emit (eventName : String) (fields : Array (String × Expr))
  | return (value : Expr)
  deriving Repr

inductive MethodKind where
  | entry
  | query
  deriving Repr

structure MethodDecl where
  kind : MethodKind
  name : String
  params : Array ParamDecl
  returns : ValueType
  body : Array Stmt
  deriving Repr

structure EventDecl where
  name : String
  fields : Array FieldDecl
  deriving Repr

structure ContractDecl where
  name : String
  state : Array FieldDecl
  events : Array EventDecl
  methods : Array MethodDecl
  deriving Repr

private def isWhitespace (ch : Char) : Bool :=
  ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'

private def isIdentStart (ch : Char) : Bool :=
  ch == '_' || (ch.isAlphanum && !ch.isDigit)

private def isIdentContinue (ch : Char) : Bool :=
  ch == '_' || ch.isAlphanum

private def isSymbol (ch : Char) : Bool :=
  "{}():,+-*/=;".contains ch

private partial def takeWhile (pred : Char → Bool) (chars : List Char)
    (acc : List Char) : String × List Char :=
  match chars with
  | [] => (String.ofList acc.reverse, [])
  | ch :: rest =>
      if pred ch then
        takeWhile pred rest (ch :: acc)
      else
        (String.ofList acc.reverse, chars)

private partial def lexChars (chars : List Char) (tokens : Array Token) :
    Except String (Array Token) :=
  match chars with
  | [] => .ok tokens
  | ch :: rest =>
      if isWhitespace ch then
        lexChars rest tokens
      else if ch == '/' && rest.head? == some '/' then
        let (_, tail) := takeWhile (fun c => c != '\n') rest []
        lexChars tail tokens
      else if isIdentStart ch then
        let (text, tail) := takeWhile isIdentContinue rest [ch]
        lexChars tail (tokens.push (.ident text))
      else if ch.isDigit then
        let (text, tail) := takeWhile (fun c => c.isDigit) rest [ch]
        match text.toNat? with
        | some value => lexChars tail (tokens.push (.number value))
        | none => .error s!"invalid numeric literal `{text}`"
      else if isSymbol ch then
        lexChars rest (tokens.push (.symbol (String.singleton ch)))
      else
        .error s!"unexpected character `{ch}`"

def lex (source : String) : Except String (Array Token) :=
  lexChars source.toList #[]

structure ParserState where
  tokens : Array Token
  pos : Nat := 0
  deriving Repr

abbrev ParserM := StateT ParserState (Except String)

private def failAt {α : Type} (message : String) : ParserM α := do
  let state ← get
  throw s!"{message} at token {state.pos}"

private def peek? : ParserM (Option Token) := do
  let state ← get
  pure state.tokens[state.pos]?

private def advance : ParserM Unit := do
  modify fun state => { state with pos := state.pos + 1 }

private def consumeSymbol (symbol : String) : ParserM Bool := do
  match (← peek?) with
  | some (.symbol value) =>
      if value == symbol then
        advance
        pure true
      else
        pure false
  | _ => pure false

private def expectSymbol (symbol : String) : ParserM Unit := do
  if (← consumeSymbol symbol) then
    pure ()
  else
    failAt s!"expected symbol `{symbol}`"

private def expectIdent : ParserM String := do
  match (← peek?) with
  | some (.ident value) =>
      advance
      pure value
  | _ => failAt "expected identifier"

private def expectKeyword (keyword : String) : ParserM Unit := do
  let value ← expectIdent
  if value == keyword then
    pure ()
  else
    failAt s!"expected keyword `{keyword}`, got `{value}`"

private def parseType : ParserM ValueType := do
  let value ← expectIdent
  match value with
  | "u64" => pure .u64
  | "u32" => pure .u32
  | "bool" => pure .bool
  | "unit" => pure .unit
  | other => failAt s!"unsupported Learn type `{other}`"

private def parseFieldDecl : ParserM FieldDecl := do
  let name ← expectIdent
  expectSymbol ":"
  let type ← parseType
  pure { name, type }

private partial def parseFieldDecls : ParserM (Array FieldDecl) := do
  if (← consumeSymbol ")") then
    pure #[]
  else
    let mut fields := #[]
    fields := fields.push (← parseFieldDecl)
    while (← consumeSymbol ",") do
      fields := fields.push (← parseFieldDecl)
    expectSymbol ")"
    pure fields

private partial def parseParams : ParserM (Array ParamDecl) := do
  expectSymbol "("
  parseFieldDecls

mutual
private partial def parseExpr : ParserM Expr :=
  parseAddSub

private partial def parseAddSub : ParserM Expr := do
  let mut lhs ← parseMulDiv
  let mut done := false
  repeat
    if (← consumeSymbol "+") then
      lhs := .binary .add lhs (← parseMulDiv)
    else if (← consumeSymbol "-") then
      lhs := .binary .sub lhs (← parseMulDiv)
    else
      done := true
    if done then
      break
  pure lhs

private partial def parseMulDiv : ParserM Expr := do
  let mut lhs ← parseAtom
  let mut done := false
  repeat
    if (← consumeSymbol "*") then
      lhs := .binary .mul lhs (← parseAtom)
    else if (← consumeSymbol "/") then
      lhs := .binary .div lhs (← parseAtom)
    else
      done := true
    if done then
      break
  pure lhs

private partial def parseAtom : ParserM Expr := do
  match (← peek?) with
  | some (.number value) =>
      advance
      pure (.number value)
  | some (.ident value) =>
      advance
      if (← consumeSymbol "(") then
        expectSymbol ")"
        pure (.call0 value)
      else
        pure (.name value)
  | some (.symbol "(") =>
      advance
      let value ← parseExpr
      expectSymbol ")"
      pure value
  | _ => failAt "expected expression"
end

private partial def parseEmitFields : ParserM (Array (String × Expr)) := do
  if (← consumeSymbol ")") then
    pure #[]
  else
    let mut fields := #[]
    let name ← expectIdent
    expectSymbol ":"
    fields := fields.push (name, (← parseExpr))
    while (← consumeSymbol ",") do
      let name ← expectIdent
      expectSymbol ":"
      fields := fields.push (name, (← parseExpr))
    expectSymbol ")"
    pure fields

private def consumeOptionalSemicolon : ParserM Unit := do
  discard <| consumeSymbol ";"

private partial def parseStmt : ParserM Stmt := do
  match (← peek?) with
  | some (.ident "let") =>
      advance
      let name ← expectIdent
      expectSymbol ":"
      let type ← parseType
      expectSymbol "="
      let value ← parseExpr
      consumeOptionalSemicolon
      pure (.letBind name type value)
  | some (.ident "emit") =>
      advance
      let eventName ← expectIdent
      expectSymbol "("
      let fields ← parseEmitFields
      consumeOptionalSemicolon
      pure (.emit eventName fields)
  | some (.ident "return") =>
      advance
      let value ← parseExpr
      consumeOptionalSemicolon
      pure (.return value)
  | some (.ident target) =>
      advance
      expectSymbol "="
      let value ← parseExpr
      consumeOptionalSemicolon
      pure (.assign target value)
  | _ => failAt "expected statement"

private partial def parseStmtBlock : ParserM (Array Stmt) := do
  expectSymbol "{"
  let mut body := #[]
  while !(← consumeSymbol "}") do
    body := body.push (← parseStmt)
  pure body

private partial def parseEvent : ParserM EventDecl := do
  expectKeyword "event"
  let name ← expectIdent
  expectSymbol "("
  let fields ← parseFieldDecls
  pure { name, fields }

private partial def parseMethod (kind : MethodKind) : ParserM MethodDecl := do
  match kind with
  | .entry => expectKeyword "entry"
  | .query => expectKeyword "query"
  let name ← expectIdent
  let params ← parseParams
  let returns ←
    match kind with
    | .entry => pure .unit
    | .query =>
        expectSymbol ":"
        parseType
  let body ← parseStmtBlock
  pure { kind, name, params, returns, body }

private partial def parseItems (state : Array FieldDecl) (events : Array EventDecl)
    (methods : Array MethodDecl) : ParserM (Array FieldDecl × Array EventDecl × Array MethodDecl) := do
  match (← peek?) with
  | some (.symbol "}") =>
      advance
      pure (state, events, methods)
  | some (.ident "state") =>
      advance
      let decl ← parseFieldDecl
      parseItems (state.push decl) events methods
  | some (.ident "event") =>
      let event ← parseEvent
      parseItems state (events.push event) methods
  | some (.ident "entry") =>
      let method ← parseMethod .entry
      parseItems state events (methods.push method)
  | some (.ident "query") =>
      let method ← parseMethod .query
      parseItems state events (methods.push method)
  | _ => failAt "expected contract item"

private partial def parseContractDecl : ParserM ContractDecl := do
  expectKeyword "contract"
  let name ← expectIdent
  expectSymbol "{"
  let (state, events, methods) ← parseItems #[] #[] #[]
  pure { name, state, events, methods }

def parseTokens (tokens : Array Token) : Except String ContractDecl := do
  let (decl, state) ← parseContractDecl.run { tokens }
  if state.pos == state.tokens.size then
    pure decl
  else
    .error s!"unexpected trailing token at {state.pos}"

def parseSource (source : String) : Except String ContractDecl := do
  parseTokens (← lex source)

def parseFile (path : System.FilePath) : IO (Except String ContractDecl) := do
  pure <| parseSource (← IO.FS.readFile path)

private def containsName (names : Array String) (name : String) : Bool :=
  names.any (fun candidate => candidate == name)

private structure LowerEnv where
  stateNames : Array String
  locals : Array String
  deriving Repr

private def lowerExpr (env : LowerEnv) : Expr → Except String ProofForge.IR.Expr
  | .number value => .ok (.literal (.u64 value))
  | .name value =>
      if containsName env.stateNames value then
        .ok (.effect (.storageScalarRead value))
      else if containsName env.locals value then
        .ok (.local value)
      else
        .error s!"unknown Learn name `{value}`"
  | .call0 "checkpoint_id" => .ok (.effect (.contextRead .checkpointId))
  | .call0 other => .error s!"unsupported Learn zero-argument call `{other}`"
  | .binary op lhs rhs => do
      let lhs ← lowerExpr env lhs
      let rhs ← lowerExpr env rhs
      match op with
      | .add => .ok (.add lhs rhs)
      | .sub => .ok (.sub lhs rhs)
      | .mul => .ok (.mul lhs rhs)
      | .div => .ok (.div lhs rhs)

private def lowerStmt (stateNames : Array String)
    (state : Array Statement × LowerEnv) (stmt : Stmt) :
    Except String (Array Statement × LowerEnv) := do
  let (body, env) := state
  match stmt with
  | .letBind name type value =>
      let value ← lowerExpr env value
      let env := { env with locals := env.locals.push name }
      .ok (body.push (.letBind name type value), env)
  | .assign target value =>
      let value ← lowerExpr env value
      if containsName stateNames target then
        .ok (body.push (.effect (.storageScalarWrite target value)), env)
      else if containsName env.locals target then
        .ok (body.push (.assign (.local target) value), env)
      else
        .error s!"cannot assign unknown Learn target `{target}`"
  | .emit eventName fields =>
      let mut lowered := #[]
      for field in fields do
        lowered := lowered.push (field.fst, (← lowerExpr env field.snd))
      .ok (body.push (.effect (.eventEmit eventName lowered)), env)
  | .return value =>
      let value ← lowerExpr env value
      .ok (body.push (.return value), env)

private def lowerMethod (stateNames : Array String) (method : MethodDecl) :
    Except String Entrypoint := do
  let params := method.params.map (fun param => (param.name, param.type))
  let paramNames := method.params.map (fun param => param.name)
  let env : LowerEnv := { stateNames, locals := paramNames }
  let (body, _) ← method.body.foldlM (lowerStmt stateNames) (#[], env)
  .ok {
    name := method.name
    selector? := none
    params := params
    returns := method.returns
    body := body
  }

def lowerContract (decl : ContractDecl) : Except String ContractSpec := do
  let stateNames := decl.state.map (fun item => item.name)
  let state := decl.state.map (fun item => {
    id := item.name
    kind := StateKind.scalar
    type := item.type
  })
  let mut entrypoints := #[]
  for method in decl.methods do
    entrypoints := entrypoints.push (← lowerMethod stateNames method)
  let module : ProofForge.IR.Module := {
    name := decl.name
    state := state
    entrypoints := entrypoints
  }
  .ok (ContractSpec.fromIR module)

def parseAndLower (source : String) : Except String ContractSpec := do
  lowerContract (← parseSource source)

def parseAndLowerFile (path : System.FilePath) : IO (Except String ContractSpec) := do
  pure <| parseAndLower (← IO.FS.readFile path)

end ProofForge.Contract.Learn
