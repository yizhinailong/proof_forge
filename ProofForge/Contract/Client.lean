import ProofForge.Contract.Spec.Json
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

def errorCatalogJson (spec : ContractSpec) : String :=
  ProofForge.Contract.Spec.Json.jsonArray
    (ProofForge.Contract.Spec.Json.errorCatalog spec.module |>.map
      ProofForge.Contract.Spec.Json.errorCatalogEntryJson)

def errorCatalogueTs (spec : ContractSpec) : String :=
  String.intercalate "\n" [
    "export const ERRORS = " ++ errorCatalogJson spec ++ " as const;",
    "export type ProofForgeError = (typeof ERRORS)[number];",
    "",
    "export function errorByAssertionId(assertionId: number): ProofForgeError | undefined {",
    "  return ERRORS.find((item) => item.assertionId === assertionId);",
    "}"
  ]

def evmErrorHelpersTs (spec : ContractSpec) : String :=
  String.intercalate "\n" [
    errorCatalogueTs spec,
    "",
    "export function decodeProofForgeRevert(error: unknown): ProofForgeError | undefined {",
    "  const candidate = error as { data?: unknown; error?: { data?: unknown } };",
    "  const data = typeof candidate?.data === \"string\"",
    "    ? candidate.data",
    "    : typeof candidate?.error?.data === \"string\"",
    "      ? candidate.error.data",
    "      : undefined;",
    "  if (!data) return undefined;",
    "  try {",
    "    const [assertionId, userCode] = ethers.AbiCoder.defaultAbiCoder().decode([\"uint32\", \"string\"], data) as [bigint, string];",
    "    const id = Number(assertionId);",
    "    return ERRORS.find((item) => item.assertionId === id && (!item.userCode || item.userCode === userCode)) ?? errorByAssertionId(id);",
    "  } catch {",
    "    return undefined;",
    "  }",
    "}"
  ]

def nearErrorHelpersTs (spec : ContractSpec) : String :=
  String.intercalate "\n" [
    errorCatalogueTs spec,
    "",
    "export function parseProofForgePanic(message: string): ProofForgeError | undefined {",
    "  const match = /PF:(\\d+):([^\\s]+)/.exec(message);",
    "  if (!match) return undefined;",
    "  const assertionId = Number(match[1]);",
    "  const userCode = match[2];",
    "  return ERRORS.find((item) => item.assertionId === assertionId && (!item.userCode || item.userCode === userCode)) ?? errorByAssertionId(assertionId);",
    "}"
  ]

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
    evmErrorHelpersTs spec,
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
    nearErrorHelpersTs spec,
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
