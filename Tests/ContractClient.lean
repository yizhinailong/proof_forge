import ProofForge.Contract.Client
import ProofForge.Contract.Spec
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.ErrorRefProbe

namespace ProofForge.Tests.ContractClient

open ProofForge.Contract

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def errorRefSpec : ContractSpec :=
  ContractSpec.fromIR ProofForge.IR.Examples.ErrorRefProbe.module

def counterSpec : ContractSpec :=
  ContractSpec.fromIR ProofForge.IR.Examples.Counter.module

def testEvmWrapperErrors : IO Unit := do
  let wrapper := ProofForge.Contract.Client.renderEvmAbiWrapper errorRefSpec
  require (contains wrapper "export const ERRORS = [{\"assertionId\": 1")
    "EVM wrapper missing embedded ProofForge error catalogue"
  require (contains wrapper "\"userCode\": \"Counter::Overflow\"")
    "EVM wrapper missing Counter::Overflow error"
  require (contains wrapper "decodeProofForgeRevert")
    "EVM wrapper missing revert decoder"
  require (contains wrapper "ethers.AbiCoder.defaultAbiCoder().decode([\"uint32\", \"string\"], data)")
    "EVM wrapper missing ProofForge revert ABI decode"
  require (contains wrapper "errorByAssertionId")
    "EVM wrapper missing assertion-id lookup helper"

def testNearWrapperErrors : IO Unit := do
  let wrapper := ProofForge.Contract.Client.renderNearWrapper errorRefSpec
  require (contains wrapper "export const ERRORS = [{\"assertionId\": 1")
    "NEAR wrapper missing embedded ProofForge error catalogue"
  require (contains wrapper "\"userCode\": \"Counter::ExactMatch\"")
    "NEAR wrapper missing Counter::ExactMatch error"
  require (contains wrapper "parseProofForgePanic")
    "NEAR wrapper missing panic parser"
  require (contains wrapper "PF:(\\d+):([^\\s]+)")
    "NEAR wrapper missing ProofForge panic prefix parser"

def testCounterWrapperEmptyErrors : IO Unit := do
  let evmWrapper := ProofForge.Contract.Client.renderEvmAbiWrapper counterSpec
  let nearWrapper := ProofForge.Contract.Client.renderNearWrapper counterSpec
  require (contains evmWrapper "export const ERRORS = [] as const;")
    "EVM Counter wrapper should expose an empty errors catalogue"
  require (contains nearWrapper "export const ERRORS = [] as const;")
    "NEAR Counter wrapper should expose an empty errors catalogue"

def main : IO UInt32 := do
  testEvmWrapperErrors
  testNearWrapperErrors
  testCounterWrapperEmptyErrors
  IO.println "contract-client: ok"
  return 0

end ProofForge.Tests.ContractClient

def main : IO UInt32 :=
  ProofForge.Tests.ContractClient.main
