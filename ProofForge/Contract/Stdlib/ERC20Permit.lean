/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer C — EIP-2612 ERC20Permit mixin (EVM)

`nonces`, `DOMAIN_SEPARATOR`, signature staging, and `permit`.

**Host gate:** `crypto.ecrecover` (EVM-only). Solana/NEAR reject at preflight.

## API shape

`contract_source` entry arity is capped; signature components are staged:

```lean
setPermitSig(v, r, s);
permit(holder, spender, value, deadline);
```

DOMAIN_SEPARATOR is set via `initDomain(sep)` (author supplies EIP-712 domain hash).
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.ERC20Permit

open ProofForge.Contract.Source

def noncesMap : MapRef :=
  { id := "nonces", keyType := .u64, valueType := .u64 }

def domainSeparatorSlot : ScalarRef :=
  ProofForge.Contract.Surface.slot "domainSeparator" .hash

def totalSupply : ScalarRef :=
  ProofForge.Contract.Surface.slot "totalSupply" .u64

def balances : MapRef :=
  { id := "balances", keyType := .u64, valueType := .u64 }

def allowances : MapRef :=
  { id := "allowances", keyType := .u64, valueType := .u64 }

def permitV : ScalarRef :=
  ProofForge.Contract.Surface.slot "permitV" .u64

def permitR : ScalarRef :=
  ProofForge.Contract.Surface.slot "permitR" .hash

def permitS : ScalarRef :=
  ProofForge.Contract.Surface.slot "permitS" .hash

contract_mixin ERC20PermitMixin do
  use ProofForge.Contract.Surface.scalar totalSupply
  use ProofForge.Contract.Surface.scalar domainSeparatorSlot
  use ProofForge.Contract.Surface.scalar permitV
  use ProofForge.Contract.Surface.scalar permitR
  use ProofForge.Contract.Surface.scalar permitS
  use ProofForge.Contract.Surface.mapState balances
  use ProofForge.Contract.Surface.mapState allowances
  use ProofForge.Contract.Surface.mapState noncesMap

  event Approval

  query nonces (who : .address) returns(.u64) do
    return mapRead noncesMap who;

  query DOMAIN_SEPARATOR returns(.hash) do
    return domainSeparatorSlot;

  entry initDomain (sep : .hash) do
    domainSeparatorSlot := sep;

  entry setPermitSig (v : .u64, r : .hash, s : .hash) do
    permitV := v;
    permitR := r;
    permitS := s;

  entry permit (holder : .address, spender : .address, value : .u64, deadline : .u64)
      returns(.bool) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref holder)
      "zero owner";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref spender)
      "zero spender";
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref deadline) timestamp
      "permit expired";
    let n : .u64 := mapRead noncesMap holder;
    let digest : .hash :=
      ProofForge.Contract.Surface.eip712PermitDigest
        (ProofForge.Contract.Surface.ref holder)
        (ProofForge.Contract.Surface.ref spender)
        (ProofForge.Contract.Surface.ref value)
        (ProofForge.Contract.Surface.ref n)
        (ProofForge.Contract.Surface.ref deadline)
        (ProofForge.Contract.Surface.read domainSeparatorSlot);
    let recovered : .u64 :=
      ProofForge.Contract.Surface.ecrecover
        (ProofForge.Contract.Surface.ref digest)
        (ProofForge.Contract.Surface.read permitV)
        (ProofForge.Contract.Surface.read permitR)
        (ProofForge.Contract.Surface.read permitS);
    do ProofForge.Contract.Surface.requireEq
      (ProofForge.Contract.Surface.ref recovered)
      (ProofForge.Contract.Surface.ref holder)
      "invalid permit signature";
    do mapWrite noncesMap holder (n +! u64 1);
    do pathWriteAllowance allowances (ProofForge.Contract.Surface.ref holder)
      (ProofForge.Contract.Surface.ref spender) value;
    emit Approval indexed #[
      fieldAsName "owner" holder,
      fieldAsName "spender" spender
    ] data #[
      fieldAsName "value" value
    ];
    return boolLit true;

contract_source ERC20Permit do
  use mixin
  entry init do
    totalSupply := u64 0;

end ProofForge.Contract.Stdlib.ERC20Permit
