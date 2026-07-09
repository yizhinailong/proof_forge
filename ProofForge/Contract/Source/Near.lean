/-
# NEAR host-extension entrypoint for `contract_source` (opt-in)

Import **this** module when a contract intentionally uses NEAR Promise
chaining / result decode beyond portable `remoteCall`:

```lean
import ProofForge.Contract.Source.Near

contract_source MyNearProgram do
  -- may use nearPromiseThen / nearPromiseResultU64 / nearCrosscallPool
```

Portable Shared examples must keep:

```lean
import ProofForge.Contract.Source
```

and use only `declareRemoteUnit` + `peerHandle` + `remoteCall` on the portable
path. Host string-pool registration is automatic. `just portable-default`
forbids importing this file from `Examples/Shared`.

Promise constructors remain IR constructors for EmitWat coverage (D-050 Slice 3
partial) but are **host-extension / fixture surface**, not portable authoring.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Source.Near

open ProofForge.Contract.Source
open ProofForge.Contract.Surface

export ProofForge.Contract.Surface (
  nearPromiseThen
  nearPromiseResultU64
  nearCrosscallPool
  nearAddressLit
  registerNearCrosscallString
  remoteCall
)

end ProofForge.Contract.Source.Near
