import ProofForge.Compiler.TS.AST
import ProofForge.Compiler.TS.Printer

namespace ProofForge.Tests.TsPrinter

open ProofForge.Compiler.TS

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireIn (haystack : String) (needle : String) : IO Unit :=
  if (haystack.splitOn needle).length > 1 then
    pure ()
  else
    throw <| IO.userError s!"expected output to contain: {needle}\nactual output:\n{haystack}"

def main : IO UInt32 := do
  -- Parenthesize binary/coalesce bases when used as member/call/new targets.
  let addOne := Expr.call0 (.member (.binary .add (.ident "n") (.bigint 1)) "toString")
  let source := Printer.render { items := #[TopLevel.fn false "addOne" #[] (some .string) #[.return addOne]] }
  requireIn source "function addOne(): string {"
  requireIn source "return (n + 1n).toString();"

  -- Await bases are also parenthesized.
  let awaitMember := Expr.call0 (.member (.await (.ident "p")) "toString")
  let awaitSource := Printer.render { items := #[TopLevel.fn false "awaitMember" #[] (some .string) #[.return awaitMember]] }
  requireIn awaitSource "return (await p).toString();"

  -- Inline if-statements keep the opening brace on the same line.
  let cond := .binary .eq (.ident "x") (.num 1)
  let ifStmt := Stmt.ifStmt cond #[.return (.str "yes")] none
  let ifSource := Printer.render { items := #[TopLevel.fn false "test" #[] (some .string) #[ifStmt]] }
  requireIn ifSource "if (x === 1) {"

  -- Export default renders correctly.
  let mod := { items := #[TopLevel.exportDefault (.objectLit #[("fetch", .ident "fetch")])] : Module }
  requireIn (Printer.render mod) "export default {\n  fetch: fetch,\n};"

  IO.println "ts-printer: ok"
  return 0

end ProofForge.Tests.TsPrinter

def main : IO UInt32 :=
  ProofForge.Tests.TsPrinter.main
