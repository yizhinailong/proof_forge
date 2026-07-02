/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana sBPF Package Printer

Turns a lowered Solana module into the file set expected by the `sbpf`
toolchain. The core assembly still flows through `IR -> AstNode -> .s`; this
module owns the deployment-package text files around that assembly.
-/

import ProofForge.IR.Contract
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.SbpfAsm

namespace ProofForge.Backend.Solana.Package

open ProofForge.IR

structure PackageFile where
  path : String
  contents : String
  deriving Repr, Inhabited

structure RenderedPackage where
  projectName : String
  asmPath : String
  manifestPath : String
  cargoTomlPath : String
  libRsPath : String
  files : Array PackageFile
  deriving Repr, Inhabited

def asmPath (projectName : String) : String :=
  s!"src/{projectName}/{projectName}.s"

def manifestPath : String := "manifest.toml"
def cargoTomlPath : String := "Cargo.toml"
def libRsPath : String := "src/lib.rs"

def renderCargoToml (projectName : String) : String :=
  String.intercalate "\n" [
    "[package]",
    s!"name = \"{projectName}\"",
    "version = \"0.1.0\"",
    "edition = \"2021\"",
    ""
  ]

/-- Render the sbpf project file set for a module. -/
def renderPackage (projectName : String) (module : Module) : Except SbpfAsm.LowerError RenderedPackage := do
  let nodes ← SbpfAsm.lowerModule module
  let asm := ProofForge.Backend.Solana.Asm.renderNodes nodes
  let manifest := Manifest.renderManifest module ++ "\n"
  let asmFile := asmPath projectName
  let files := #[
    { path := asmFile, contents := asm },
    { path := manifestPath, contents := manifest },
    { path := cargoTomlPath, contents := renderCargoToml projectName },
    { path := libRsPath, contents := "" }
  ]
  .ok {
    projectName,
    asmPath := asmFile,
    manifestPath,
    cargoTomlPath,
    libRsPath,
    files
  }

end ProofForge.Backend.Solana.Package
