import ProofForge.Contract.Builder
import ProofForge.Contract.Spec
import ProofForge.IR.Contract
import ProofForge.Solana

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

inductive SolanaSeed where
  | literal (value : String)
  | account (name : String)
  deriving Repr

inductive SolanaSignerSeed where
  | pda (name : String)
  | bump (name : String)
  deriving Repr

inductive SolanaItem where
  | allocatorBump
  | account (name : String) (access : ProofForge.Solana.AccountAccess) (owner : String)
  | pda (name : String) (seeds : Array SolanaSeed) (bump account : String) (isSigner : Bool)
  | systemTransfer (name fromAccount toAccount lamportsSource : String)
  | systemCreateAccount (name payer newAccount lamportsSource spaceSource owner : String)
  | splTokenTransferChecked (name source mint destination authority amountSource : String)
      (decimals : Nat) (signerSeeds : Array SolanaSignerSeed)
  deriving Repr

inductive Stmt where
  | letBind (name : String) (type : ValueType) (value : Expr)
  | assign (target : String) (value : Expr)
  | emit (eventName : String) (fields : Array (String × Expr))
  | solanaDerivePda (name : String) (seeds : Array SolanaSeed) (bump account : String)
      (isSigner : Bool)
  | solanaInvokeSystemTransfer (name fromAccount toAccount lamportsSource : String)
  | solanaInvokeSystemCreateAccount (name payer newAccount lamportsSource spaceSource owner : String)
  | solanaInvokeSplTokenTransferChecked (name source mint destination authority amountSource : String)
      (decimals : Nat) (signerSeeds : Array SolanaSignerSeed)
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
  bindings : Array FieldDecl := #[]
  events : Array EventDecl
  solanaItems : Array SolanaItem := #[]
  methods : Array MethodDecl
  deriving Repr

private def isWhitespace (ch : Char) : Bool :=
  ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'

private def isIdentStart (ch : Char) : Bool :=
  ch == '_' || (ch.isAlphanum && !ch.isDigit)

private def isIdentContinue (ch : Char) : Bool :=
  ch == '_' || ch.isAlphanum

private def isSymbol (ch : Char) : Bool :=
  "{}[]():,+-*/=;".contains ch

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

private def consumeKeyword (keyword : String) : ParserM Bool := do
  match (← peek?) with
  | some (.ident value) =>
      if value == keyword then
        advance
        pure true
      else
        pure false
  | _ => pure false

private def expectNumber : ParserM Nat := do
  match (← peek?) with
  | some (.number value) =>
      advance
      pure value
  | _ => failAt "expected number"

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

private partial def parseIdentArgs : ParserM (Array String) := do
  expectSymbol "("
  if (← consumeSymbol ")") then
    pure #[]
  else
    let mut args := #[]
    args := args.push (← expectIdent)
    while (← consumeSymbol ",") do
      args := args.push (← expectIdent)
    expectSymbol ")"
    pure args

private def expectArgs (name : String) (args : Array String) (size : Nat) : ParserM Unit :=
  if args.size == size then
    pure ()
  else
    failAt s!"{name} expects {size} arguments, got {args.size}"

private def parseAccountAccess : ParserM ProofForge.Solana.AccountAccess := do
  let access ← expectIdent
  match access with
  | "readonly" => pure .readOnly
  | "writable" => pure .writable
  | other => failAt s!"unsupported Solana account access `{other}`"

private partial def parseSolanaSeeds : ParserM (Array SolanaSeed) := do
  expectSymbol "["
  if (← consumeSymbol "]") then
    pure #[]
  else
    let mut seeds := #[]
    let parseOne : ParserM SolanaSeed := do
      let kind ← expectIdent
      let value ← expectIdent
      match kind with
      | "literal" => pure (.literal value)
      | "account" => pure (.account value)
      | other => failAt s!"unsupported Solana PDA seed kind `{other}`"
    seeds := seeds.push (← parseOne)
    while (← consumeSymbol ",") do
      seeds := seeds.push (← parseOne)
    expectSymbol "]"
    pure seeds

private partial def parseSolanaSignerSeeds : ParserM (Array SolanaSignerSeed) := do
  expectSymbol "["
  if (← consumeSymbol "]") then
    pure #[]
  else
    let mut seeds := #[]
    let parseOne : ParserM SolanaSignerSeed := do
      let kind ← expectIdent
      let value ← expectIdent
      match kind with
      | "pda" => pure (.pda value)
      | "bump" => pure (.bump value)
      | other => failAt s!"unsupported Solana signer seed kind `{other}`"
    seeds := seeds.push (← parseOne)
    while (← consumeSymbol ",") do
      seeds := seeds.push (← parseOne)
    expectSymbol "]"
    pure seeds

private partial def parseDecimals : ParserM Nat := do
  expectKeyword "decimals"
  expectSymbol "("
  let value ← expectNumber
  expectSymbol ")"
  pure value

private partial def parseOptionalSignerSeeds : ParserM (Array SolanaSignerSeed) := do
  if (← consumeKeyword "signer_seeds") then
    parseSolanaSignerSeeds
  else
    pure #[]

private partial def parsePdaTail : ParserM (Array SolanaSeed × String × String × Bool) := do
  expectKeyword "seeds"
  let seeds ← parseSolanaSeeds
  expectKeyword "bump"
  let bump ← expectIdent
  expectKeyword "account"
  let account ← expectIdent
  let isSigner ← consumeKeyword "signer"
  pure (seeds, bump, account, isSigner)

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

private partial def parseSolanaCpiDecl (name instruction : String) : ParserM SolanaItem := do
  let args ← parseIdentArgs
  match instruction with
  | "system_transfer" =>
      expectArgs "system_transfer" args 3
      pure (.systemTransfer name args[0]! args[1]! args[2]!)
  | "system_create_account" =>
      expectArgs "system_create_account" args 4
      expectKeyword "owner"
      let owner ← expectIdent
      pure (.systemCreateAccount name args[0]! args[1]! args[2]! args[3]! owner)
  | "spl_token_transfer_checked" =>
      expectArgs "spl_token_transfer_checked" args 5
      let decimals ← parseDecimals
      let signerSeeds ← parseOptionalSignerSeeds
      pure (.splTokenTransferChecked name args[0]! args[1]! args[2]! args[3]! args[4]!
        decimals signerSeeds)
  | other => failAt s!"unsupported Solana CPI instruction `{other}`"

private partial def parseSolanaItem : ParserM SolanaItem := do
  expectKeyword "solana"
  let kind ← expectIdent
  match kind with
  | "allocator" =>
      expectKeyword "bump"
      pure .allocatorBump
  | "account" =>
      let name ← expectIdent
      let access ← parseAccountAccess
      let owner ←
        if (← consumeKeyword "owner") then
          expectIdent
        else
          pure "any"
      pure (.account name access owner)
  | "pda" =>
      let name ← expectIdent
      let (seeds, bump, account, isSigner) ← parsePdaTail
      pure (.pda name seeds bump account isSigner)
  | "cpi" =>
      let name ← expectIdent
      let instruction ← expectIdent
      parseSolanaCpiDecl name instruction
  | other => failAt s!"unsupported Solana item `{other}`"

private partial def parseSolanaStmt : ParserM Stmt := do
  expectKeyword "solana"
  let kind ← expectIdent
  match kind with
  | "derive" =>
      expectKeyword "pda"
      let name ← expectIdent
      let (seeds, bump, account, isSigner) ← parsePdaTail
      consumeOptionalSemicolon
      pure (.solanaDerivePda name seeds bump account isSigner)
  | "invoke" =>
      let name ← expectIdent
      let instruction ← expectIdent
      let args ← parseIdentArgs
      let stmt ←
        match instruction with
        | "system_transfer" =>
            expectArgs "system_transfer" args 3
            pure (.solanaInvokeSystemTransfer name args[0]! args[1]! args[2]!)
        | "system_create_account" =>
            expectArgs "system_create_account" args 4
            expectKeyword "owner"
            let owner ← expectIdent
            pure (.solanaInvokeSystemCreateAccount name args[0]! args[1]! args[2]! args[3]! owner)
        | "spl_token_transfer_checked" =>
            expectArgs "spl_token_transfer_checked" args 5
            let decimals ← parseDecimals
            let signerSeeds ← parseOptionalSignerSeeds
            pure (.solanaInvokeSplTokenTransferChecked name args[0]! args[1]! args[2]! args[3]!
              args[4]! decimals signerSeeds)
        | other => failAt s!"unsupported Solana invoke instruction `{other}`"
      consumeOptionalSemicolon
      pure stmt
  | other => failAt s!"unsupported Solana statement `{other}`"

private partial def parseStmt : ParserM Stmt := do
  match (← peek?) with
  | some (.ident "solana") =>
      parseSolanaStmt
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

private partial def parseItems (state bindings : Array FieldDecl) (events : Array EventDecl)
    (solanaItems : Array SolanaItem) (methods : Array MethodDecl) :
    ParserM (Array FieldDecl × Array FieldDecl × Array EventDecl × Array SolanaItem × Array MethodDecl) := do
  match (← peek?) with
  | some (.symbol "}") =>
      advance
      pure (state, bindings, events, solanaItems, methods)
  | some (.ident "state") =>
      advance
      let decl ← parseFieldDecl
      parseItems (state.push decl) bindings events solanaItems methods
  | some (.ident "binding") =>
      advance
      let decl ← parseFieldDecl
      parseItems state (bindings.push decl) events solanaItems methods
  | some (.ident "event") =>
      let event ← parseEvent
      parseItems state bindings (events.push event) solanaItems methods
  | some (.ident "solana") =>
      let item ← parseSolanaItem
      parseItems state bindings events (solanaItems.push item) methods
  | some (.ident "entry") =>
      let method ← parseMethod .entry
      parseItems state bindings events solanaItems (methods.push method)
  | some (.ident "query") =>
      let method ← parseMethod .query
      parseItems state bindings events solanaItems (methods.push method)
  | _ => failAt "expected contract item"

private partial def parseContractDecl : ParserM ContractDecl := do
  expectKeyword "contract"
  let name ← expectIdent
  expectSymbol "{"
  let (state, bindings, events, solanaItems, methods) ← parseItems #[] #[] #[] #[] #[]
  pure { name, state, bindings, events, solanaItems, methods }

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

private def lowerSolanaSeed : SolanaSeed → String
  | .literal value => ProofForge.Solana.literalSeed value
  | .account name => ProofForge.Solana.accountSeed name

private def lowerSolanaSeeds (seeds : Array SolanaSeed) : Array String :=
  seeds.map lowerSolanaSeed

private def lowerSolanaSignerSeed : SolanaSignerSeed → String
  | .pda name => name
  | .bump name => name

private def lowerSolanaSignerSeeds (seeds : Array SolanaSignerSeed) : Array String :=
  seeds.map lowerSolanaSignerSeed

private def lowerSolanaItem (item : SolanaItem) :
    Except String (ProofForge.Contract.Builder.ModuleM Unit) := do
  match item with
  | .allocatorBump =>
      pure ProofForge.Solana.bumpAllocator
  | .account name access owner =>
      pure (ProofForge.Solana.accountConstraint name access .none owner)
  | .pda name seeds bump account isSigner =>
      pure (ProofForge.Solana.pdaAccount name (lowerSolanaSeeds seeds)
        (bump? := some bump) (account? := some account) (isSigner := isSigner))
  | .systemTransfer name fromAccount toAccount lamportsSource =>
      pure (ProofForge.Solana.systemTransfer name fromAccount toAccount lamportsSource)
  | .systemCreateAccount name payer newAccount lamportsSource spaceSource owner =>
      pure (ProofForge.Solana.systemCreateAccount name payer newAccount lamportsSource spaceSource owner)
  | .splTokenTransferChecked name source mint destination authority amountSource decimals signerSeeds =>
      pure (ProofForge.Solana.splTokenTransferChecked name source mint destination authority amountSource
        decimals (signerSeeds := lowerSolanaSignerSeeds signerSeeds))

private def lowerStmtAction (stateNames : Array String)
    (state : ProofForge.Contract.Builder.EntryM Unit × LowerEnv) (stmt : Stmt) :
    Except String (ProofForge.Contract.Builder.EntryM Unit × LowerEnv) := do
  let (action, env) := state
  match stmt with
  | .letBind name type value =>
      let value ← lowerExpr env value
      let env := { env with locals := env.locals.push name }
      let stmtAction := ProofForge.Contract.Builder.letBind name type value
      .ok (action *> stmtAction, env)
  | .assign target value =>
      let value ← lowerExpr env value
      if containsName stateNames target then
        let stmtAction := ProofForge.Contract.Builder.effect
          (ProofForge.Contract.Builder.storageScalarWrite target value)
        .ok (action *> stmtAction, env)
      else if containsName env.locals target then
        let stmtAction := ProofForge.Contract.Builder.assign (.local target) value
        .ok (action *> stmtAction, env)
      else
        .error s!"cannot assign unknown Learn target `{target}`"
  | .emit eventName fields =>
      let mut lowered := #[]
      for field in fields do
        lowered := lowered.push (field.fst, (← lowerExpr env field.snd))
      let stmtAction := ProofForge.Contract.Builder.effect
        (ProofForge.Contract.Builder.eventEmit eventName lowered)
      .ok (action *> stmtAction, env)
  | .solanaDerivePda name seeds bump account isSigner =>
      let stmtAction := ProofForge.Solana.derivePda name (lowerSolanaSeeds seeds)
        (bump? := some bump) (account? := some account) (isSigner := isSigner)
      .ok (action *> stmtAction, env)
  | .solanaInvokeSystemTransfer name fromAccount toAccount lamportsSource =>
      let stmtAction := ProofForge.Solana.invokeSystemTransfer name fromAccount toAccount lamportsSource
      .ok (action *> stmtAction, env)
  | .solanaInvokeSystemCreateAccount name payer newAccount lamportsSource spaceSource owner =>
      let stmtAction := ProofForge.Solana.invokeSystemCreateAccount name payer newAccount
        lamportsSource spaceSource owner
      .ok (action *> stmtAction, env)
  | .solanaInvokeSplTokenTransferChecked name source mint destination authority amountSource decimals signerSeeds =>
      let stmtAction := ProofForge.Solana.invokeSplTokenTransferChecked name source mint destination authority
        amountSource decimals (signerSeeds := lowerSolanaSignerSeeds signerSeeds)
      .ok (action *> stmtAction, env)
  | .return value =>
      let value ← lowerExpr env value
      let stmtAction := ProofForge.Contract.Builder.ret value
      .ok (action *> stmtAction, env)

private def lowerMethodAction (stateNames bindingNames : Array String) (method : MethodDecl) :
    Except String (ProofForge.Contract.Builder.ModuleM Unit) := do
  let params := method.params.map (fun param => (param.name, param.type))
  let paramNames := method.params.map (fun param => param.name)
  let env : LowerEnv := { stateNames, locals := bindingNames ++ paramNames }
  let (bodyAction, _) ← method.body.foldlM (lowerStmtAction stateNames) (pure (), env)
  .ok (ProofForge.Contract.Builder.entryWithParams method.name params method.returns bodyAction)

def lowerContract (decl : ContractDecl) : Except String ContractSpec := do
  let stateNames := decl.state.map (fun item => item.name)
  let bindingNames := decl.bindings.map (fun item => item.name)
  let mut action : ProofForge.Contract.Builder.ModuleM Unit := pure ()
  for state in decl.state do
    action := action *> ProofForge.Contract.Builder.scalarState state.name state.type
  for item in decl.solanaItems do
    action := action *> (← lowerSolanaItem item)
  for method in decl.methods do
    action := action *> (← lowerMethodAction stateNames bindingNames method)
  .ok (ProofForge.Contract.Builder.build decl.name action)

def parseAndLower (source : String) : Except String ContractSpec := do
  lowerContract (← parseSource source)

def parseAndLowerFile (path : System.FilePath) : IO (Except String ContractSpec) := do
  pure <| parseAndLower (← IO.FS.readFile path)

end ProofForge.Contract.Learn
