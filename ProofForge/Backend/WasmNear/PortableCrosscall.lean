/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Portable crosscall → NEAR Promise materialization (Phase B.3 / D-050 Slice 3)

Authors write portable `crosscall.invoke` with address-literal indices into
`module.nearCrosscallStrings`. EmitWat materializes that as `promise_create`.

**Portable product path (authors):**
* `crosscall.invoke` / untyped invoke only
* `nearCrosscallStrings` host string pool (target metadata, not business logic)

**NEAR host-extension only (fixtures / advanced):**
* `nearPromiseThen`, `nearPromiseResultsCount`, `nearPromiseResultStatus`,
  `nearPromiseResultU64`, `nearCrosscallInvokePool`

These remain IR constructors for EmitWat coverage but classify as
`targetFamilyOnly .wasmHost` in `ProofForge.IR.Portability` and must not appear
in Shared portable examples.
-/
import ProofForge.IR.Contract
import ProofForge.IR.Portability

namespace ProofForge.Backend.WasmNear.PortableCrosscall

open ProofForge.IR
open ProofForge.IR.Portability

private def isPromiseExtensionFinding (f : PortabilityFinding) : Bool :=
  match f.class_ with
  | .targetFamilyOnly .wasmHost =>
      f.detail.startsWith "nearPromise" || f.detail.startsWith "nearCrosscallInvokePool"
  | _ => false

/-- True when the module uses NEAR-only Promise constructors (host extension). -/
def moduleUsesPromiseExtension (module : Module) : Bool :=
  (classifyModule module).any isPromiseExtensionFinding

/-- True when the module uses portable `crosscall.invoke` (family-shared)
without requiring Promise host-extension constructors. -/
def moduleUsesPortableInvoke (module : Module) : Bool :=
  let findings := classifyModule module
  findings.any (fun f => f.detail.startsWith "crosscall.invoke") &&
    !(findings.any isPromiseExtensionFinding)

def materializationNote (module : Module) : String :=
  if moduleUsesPromiseExtension module then
    "NEAR host-extension: promise_then / result decode present (not portable product path)"
  else if moduleUsesPortableInvoke module then
    "portable crosscall.invoke → promise_create (nearCrosscallStrings indices)"
  else if !module.nearCrosscallStrings.isEmpty then
    "nearCrosscallStrings present without portable invoke body"
  else
    "no portable NEAR crosscall sites"

end ProofForge.Backend.WasmNear.PortableCrosscall
