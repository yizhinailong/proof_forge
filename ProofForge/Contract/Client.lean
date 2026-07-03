import ProofForge.Contract.Spec
import ProofForge.IR.Contract

namespace ProofForge.Contract.Client

open ProofForge.IR

def evmAbiWrapperPath : String := "proof-forge-evm-abi.ts"

def nearWrapperPath : String := "proof-forge-near.ts"

def solanaClientPath : String := "proof-forge-client.ts"

def solanaIdlPath : String := "proof-forge-idl.json"

def typeToTs : ValueType → String
  | .u32 => "number"
  | .u64 => "bigint"
  | .bool => "boolean"
  | .hash => "string"
  | .unit => "void"
  | .fixedArray _ _ => "any[]"
  | .structType _ => "Record<string, any>"

def solidityAbiType : ValueType → String
  | .u32 => "uint32"
  | .u64 => "uint64"
  | .bool => "bool"
  | .hash => "bytes32"
  | .unit => ""
  | .fixedArray _ _ => "bytes"
  | .structType _ => "bytes"

def abiInputJson (param : String × ValueType) : String :=
  "{\"name\":\"" ++ param.fst ++ "\",\"type\":\"" ++ solidityAbiType param.snd ++ "\"}"

def abiEntryJson (entrypoint : Entrypoint) : String :=
  let inputs := String.intercalate "," (entrypoint.params.map abiInputJson).toList
  let stateMutability := if entrypoint.returns == .unit then "nonpayable" else "view"
  "{\"name\":\"" ++ entrypoint.name ++ "\",\"type\":\"function\",\"inputs\":[" ++ inputs ++ "],\"outputs\":[],\"stateMutability\":\"" ++ stateMutability ++ "\"}"

def abiJson (module : Module) : String :=
  "[" ++ String.intercalate "," (module.entrypoints.map abiEntryJson).toList ++ "]"

def evmEntrypointWrapper (entrypoint : Entrypoint) : String :=
  let params := String.intercalate ", " (entrypoint.params.map fun p => p.fst ++ ": " ++ typeToTs p.snd).toList
  let argsArray := "[" ++ String.intercalate ", " (entrypoint.params.map fun p => p.fst).toList ++ "]"
  let method := if entrypoint.returns == .unit then "sendTransaction" else "call"
  "\nexport async function " ++ entrypoint.name ++ "(" ++ params ++ "): Promise<void> {\n" ++
  "  const data = iface.encodeFunctionData(\"" ++ entrypoint.name ++ "\", " ++ argsArray ++ ");\n" ++
  "  const tx = await contract." ++ method ++ "(data);\n" ++
  "  await tx.wait();\n" ++
  "}\n"

def renderEvmAbiWrapper (spec : ContractSpec) : String :=
  let entrypointLines := String.intercalate "" (spec.module.entrypoints.map evmEntrypointWrapper).toList
  String.intercalate "\n" [
    "/* ProofForge generated EVM ABI wrapper. */",
    "/* eslint-disable @typescript-eslint/no-explicit-any */",
    "import { ethers } from \"ethers\";",
    "",
    "export const ABI = " ++ abiJson spec.module ++ " as const;",
    "",
    "let contract: ethers.Contract;",
    "let iface: ethers.Interface;",
    "",
    "export function connect(address: string, runner: ethers.ContractRunner) {",
    "  iface = new ethers.Interface(ABI);",
    "  contract = new ethers.Contract(address, ABI, runner);",
    "  return contract;",
    "}",
    entrypointLines
  ]

def nearEntrypointWrapper (entrypoint : Entrypoint) : String :=
  let params := String.intercalate ", " (entrypoint.params.map fun p => p.fst ++ ": " ++ typeToTs p.snd).toList
  let argsObj := "{" ++ String.intercalate ", " (entrypoint.params.map fun p => "\"" ++ p.fst ++ "\": " ++ p.fst).toList ++ "}"
  "\nexport async function " ++ entrypoint.name ++ "(" ++ params ++ "): Promise<void> {\n" ++
  "  await account.functionCall({ contractId, methodName: \"" ++ entrypoint.name ++ "\", args: " ++ argsObj ++ " });\n" ++
  "}\n"

def renderNearWrapper (spec : ContractSpec) : String :=
  let entrypointLines := String.intercalate "" (spec.module.entrypoints.map nearEntrypointWrapper).toList
  String.intercalate "\n" [
    "/* ProofForge generated NEAR wrapper. */",
    "/* eslint-disable @typescript-eslint/no-explicit-any */",
    "import { Account } from \"near-api-js\";",
    "",
    "let contractId: string;",
    "let account: Account;",
    "",
    "export function connect(id: string, signer: Account) {",
    "  contractId = id;",
    "  account = signer;",
    "}",
    entrypointLines
  ]

end ProofForge.Contract.Client
