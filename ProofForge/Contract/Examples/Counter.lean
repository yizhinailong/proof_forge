import ProofForge.Contract.Surface

namespace ProofForge.Contract.Examples.Counter

open ProofForge.Contract.Surface

namespace State

state_decl count : .u64

end State

namespace Local

binding_decl n : .u64

end Local

namespace Method

method_decl «initialize» : #[]
method_decl increment : #[]
method_return_decl get : .u64 := #[]

end Method

def spec : ContractSpec :=
  contract_decl Counter do
    scalar State.count

    entry Method.«initialize» do
      write State.count (u64 0)

    entry Method.increment do
      bind Local.n (read State.count)
      write State.count (add (ref Local.n) (u64 1))

    entry Method.get do
      ret (read State.count)

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Contract.Examples.Counter
