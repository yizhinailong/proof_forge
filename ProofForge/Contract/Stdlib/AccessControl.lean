/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

AccessControl role mixin for `contract_source` composition.
Uses nested map storage `(role, account) -> membership` and `guard_role` checks.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.AccessControl

open ProofForge.Contract.Source

namespace Spec

def hasMembership (member : Nat) : Prop := member ≠ 0

theorem zero_not_member : ¬ hasMembership 0 := by simp [hasMembership]

end Spec

/-- Default admin role id (OpenZeppelin `DEFAULT_ADMIN_ROLE` is zero). -/
def defaultAdminRole : Nat := 0

/-- Example minter role id for demos and smokes. -/
def minterRole : Nat := 1

def roleMembers : MapRef :=
  { id := "roleMembers", keyType := .u64, valueType := .u64 }

contract_mixin AccessControlMixin do
  use ProofForge.Contract.Surface.mapState roleMembers

  query hasRole (role : .u64, who : .address) returns(.bool) do
    let member : .u64 := pathReadRole roleMembers role who;
    return ProofForge.Contract.Surface.ne (ProofForge.Contract.Surface.ref member) (u64 0);

  entry grantRole (role : .u64, who : .address) do
    guard_role defaultAdminRole;
    do pathWriteRole roleMembers role who (u64 1);

  entry revokeRole (role : .u64, who : .address) do
    guard_role defaultAdminRole;
    do pathWriteRole roleMembers role who (u64 0);

contract_source AccessControl do
  use mixin
  entry init do
    let admin : .address := caller;
    do pathWriteRole roleMembers (u64 defaultAdminRole) admin (u64 1);

end ProofForge.Contract.Stdlib.AccessControl
