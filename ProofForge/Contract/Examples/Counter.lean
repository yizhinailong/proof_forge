import ProofForge.Contract.Builder

namespace ProofForge.Contract.Examples.Counter

open ProofForge.Contract.Builder

def spec : ContractSpec :=
  build "Counter" do
    scalarState "count" .u64

    entrySelector "initialize" "8129fc1c" do
      effect (storageScalarWrite "count" (u64 0))

    entrySelector "increment" "d09de08a" do
      letBind "n" .u64 (storageScalarRead "count")
      effect (storageScalarWrite "count" (add (localVar "n") (u64 1)))

    entrySelectorReturns "get" "6d4ce63c" .u64 do
      ret (storageScalarRead "count")

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Contract.Examples.Counter
