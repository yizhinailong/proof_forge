/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

ERC-165 interface introspection mixin for `contract_source` composition.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.ERC165

open ProofForge.Contract.Source

def erc165InterfaceId : Nat := 0x01ffc9a7

def erc165InterfaceWord : ProofForge.IR.Expr :=
  .shiftLeft (.literal (.u64 erc165InterfaceId)) (.literal (.u64 224))

def registeredInterfaces : MapRef :=
  { id := "registeredInterfaces", keyType := .u64, valueType := .u64 }

contract_mixin ERC165Mixin do
  use ProofForge.Contract.Surface.mapState registeredInterfaces

  query supportsInterface (interfaceId : .bytes4) returns(.bool) do
    let registered : .u64 := mapRead registeredInterfaces interfaceId;
    return ProofForge.Contract.Surface.boolOr
      (ProofForge.Contract.Surface.eq (ProofForge.Contract.Surface.ref interfaceId) erc165InterfaceWord)
      (ProofForge.Contract.Surface.ne (ProofForge.Contract.Surface.ref registered) (u64 0));

  entry registerInterface (interfaceId : .bytes4) do
    do mapWrite registeredInterfaces interfaceId (u64 1);

contract_source ERC165 do
  use mixin
  entry init do
    do mapWrite registeredInterfaces erc165InterfaceWord (u64 1);

end ProofForge.Contract.Stdlib.ERC165
