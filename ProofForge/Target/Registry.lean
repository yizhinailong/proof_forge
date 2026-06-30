import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.Target

inductive TargetFamily where
  | evm
  | wasmHost
  | solana
  | move
  | zkCircuitSourcegen
  deriving BEq, DecidableEq, Repr

def TargetFamily.id : TargetFamily → String
  | .evm => "evm"
  | .wasmHost => "wasm-host"
  | .solana => "solana"
  | .move => "move"
  | .zkCircuitSourcegen => "zk-circuit-sourcegen"

inductive ArtifactKind where
  | evmBytecode
  | yul
  | wasm
  | solanaElf
  | movePackage
  | psyCircuitJson
  deriving BEq, DecidableEq, Repr

def ArtifactKind.id : ArtifactKind → String
  | .evmBytecode => "evm-bytecode"
  | .yul => "yul"
  | .wasm => "wasm"
  | .solanaElf => "solana-elf"
  | .movePackage => "move-package"
  | .psyCircuitJson => "psy-circuit-json"

structure TargetProfile where
  id : String
  family : TargetFamily
  artifactKind : ArtifactKind
  capabilities : CapabilitySet
  requiredTools : Array String := #[]
  deriving Repr

def evm : TargetProfile := {
  id := "evm"
  family := .evm
  artifactKind := .evmBytecode
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash
  ]
  requiredTools := #["solc", "foundry"]
}

def wasmNear : TargetProfile := {
  id := "wasm-near"
  family := .wasmHost
  artifactKind := .wasm
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash
  ]
  requiredTools := #["zig"]
}

def wasmCosmWasm : TargetProfile := {
  id := "wasm-cosmwasm"
  family := .wasmHost
  artifactKind := .wasm
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash
  ]
  requiredTools := #["zig", "cosmwasm-check"]
}

def solanaSbpfLinker : TargetProfile := {
  id := "solana-sbpf-linker"
  family := .solana
  artifactKind := .solanaElf
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash,
    .accountExplicit,
    .storagePda,
    .crosscallCpi
  ]
  requiredTools := #["zig", "sbpf-linker"]
}

def solanaZigFork : TargetProfile := {
  id := "solana-zig-fork"
  family := .solana
  artifactKind := .solanaElf
  capabilities := solanaSbpfLinker.capabilities
  requiredTools := #["solana-zig"]
}

def moveAptos : TargetProfile := {
  id := "move-aptos"
  family := .move
  artifactKind := .movePackage
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash,
    .accountExplicit
  ]
  requiredTools := #["aptos"]
}

def moveSui : TargetProfile := {
  id := "move-sui"
  family := .move
  artifactKind := .movePackage
  capabilities := #[
    .storageScalar,
    .storageMap,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .cryptoHash,
    .accountExplicit
  ]
  requiredTools := #["sui"]
}

def psyDpn : TargetProfile := {
  id := "psy-dpn"
  family := .zkCircuitSourcegen
  artifactKind := .psyCircuitJson
  capabilities := #[
    .storageScalar,
    .storageMap,
    .storageArray,
    .callerSender,
    .valueNative,
    .eventsEmit,
    .crosscallInvoke,
    .envBlock,
    .controlBoundedLoop,
    .dataFixedArray,
    .dataStruct,
    .cryptoHash,
    .assertions,
    .accountExplicit,
    .zkCircuit,
    .zkProof
  ]
  requiredTools := #["dargo"]
}

def all : Array TargetProfile := #[
  evm,
  wasmNear,
  wasmCosmWasm,
  solanaSbpfLinker,
  solanaZigFork,
  moveAptos,
  moveSui,
  psyDpn
]

def find? (id : String) : Option TargetProfile :=
  all.find? (fun profile => profile.id == id)

def knownIds : Array String :=
  all.map (fun profile => profile.id)

def hasCapability (profile : TargetProfile) (capability : Capability) : Bool :=
  profile.capabilities.contains capability

end ProofForge.Target
