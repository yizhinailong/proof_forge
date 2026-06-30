import Lake
open Lake DSL

package «proof-forge» where
  version := v!"0.1.0"

lean_lib ProofForge where
  roots := #[
    `ProofForge,
    `ProofForge.Evm,
    `ProofForge.Psy,
    `ProofForge.Target,
    `ProofForge.IR,
    `ProofForge.Backend,
    `ProofForge.Compiler.Yul.AST,
    `ProofForge.Compiler.Yul.Printer,
    `ProofForge.Compiler.LCNF.EmitYul
  ]

@[default_target]
lean_exe «proof-forge» where
  root := `ProofForge.Cli
  supportInterpreter := true
