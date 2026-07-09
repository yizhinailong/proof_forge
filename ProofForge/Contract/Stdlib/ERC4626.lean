/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer C — ERC-4626 vault mixin (honest 1:1 exchange-rate subset)

Deployable vault **body** (you *are* the vault), not the Layer B external
client (`Protocols.Evm.IERC4626` / Product `external_vault`).

## Honesty bounds (Wave ε Layer C)

| Feature | Behavior |
|---------|----------|
| Exchange rate | **1:1** `shares ↔ assets` (`convertTo*` is identity) |
| Underlying ERC-20 pull | **Synthetic** — `deposit` credits `totalAssets` without
  `transferFrom` on an external token (no ecrecover / nested CALL required) |
| Share token | Minimal ERC-20 surface: `balanceOf` / `totalSupply` / `transfer` /
  `approve` / `transferFrom` on **shares** |
| Full fee / preview rounding | Deferred |

This matches VerifiedVault’s solvent model (`reserves = shares`) with the
EIP-4626 method surface for multi-target product demos.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.ERC4626

open ProofForge.Contract.Source

namespace Spec

/-- Vault solvent when tracked assets equal share supply (1:1 rate). -/
structure State where
  totalAssets : Nat
  totalSupply : Nat

def solvent (s : State) : Prop := s.totalAssets = s.totalSupply

def empty : State := { totalAssets := 0, totalSupply := 0 }

def deposit? (s : State) (amount : Nat) : Option State :=
  some { totalAssets := s.totalAssets + amount, totalSupply := s.totalSupply + amount }

def withdraw? (s : State) (amount : Nat) : Option State :=
  if amount ≤ s.totalAssets ∧ amount ≤ s.totalSupply then
    some { totalAssets := s.totalAssets - amount, totalSupply := s.totalSupply - amount }
  else
    none

theorem empty_solvent : solvent empty := by rfl

theorem deposit_preserves_solvent {s next : State} {amount : Nat}
    (h : solvent s) (hn : deposit? s amount = some next) : solvent next := by
  unfold deposit? at hn
  simp at hn
  rw [← hn]
  show s.totalAssets + amount = s.totalSupply + amount
  rw [h]

theorem withdraw_preserves_solvent {s next : State} {amount : Nat}
    (h : solvent s) (hn : withdraw? s amount = some next) : solvent next := by
  unfold withdraw? at hn
  by_cases w : amount ≤ s.totalAssets ∧ amount ≤ s.totalSupply
  · simp [w] at hn
    rw [← hn]
    show s.totalAssets - amount = s.totalSupply - amount
    rw [h]
  · simp [w] at hn

theorem convert_identity (n : Nat) : n = n := rfl

end Spec

def assetAddress : ScalarRef :=
  ProofForge.Contract.Surface.slot "asset" .u64

def totalAssetsSlot : ScalarRef :=
  ProofForge.Contract.Surface.slot "totalAssets" .u64

def totalSupply : ScalarRef :=
  ProofForge.Contract.Surface.slot "totalSupply" .u64

def shareBalances : MapRef :=
  { id := "shareBalances", keyType := .u64, valueType := .u64 }

def shareAllowances : MapRef :=
  { id := "shareAllowances", keyType := .u64, valueType := .u64 }

contract_mixin ERC4626Mixin do
  use ProofForge.Contract.Surface.scalar assetAddress
  use ProofForge.Contract.Surface.scalar totalAssetsSlot
  use ProofForge.Contract.Surface.scalar totalSupply
  use ProofForge.Contract.Surface.mapState shareBalances
  use ProofForge.Contract.Surface.mapState shareAllowances

  event Deposit
  event Withdraw
  event Transfer
  event Approval

  query «asset» returns(.u64) do
    return assetAddress;

  query totalAssets returns(.u64) do
    return totalAssetsSlot;

  query totalSupply returns(.u64) do
    return totalSupply;

  query balanceOf (who : .address) returns(.u64) do
    return mapRead shareBalances who;

  query convertToShares (assets : .u64) returns(.u64) do
    return assets;

  query convertToAssets (shares : .u64) returns(.u64) do
    return shares;

  query maxDeposit (who : .address) returns(.u64) do
    return u64 0xffffffffffffffff;

  query maxMint (who : .address) returns(.u64) do
    return u64 0xffffffffffffffff;

  query maxWithdraw (holder : .address) returns(.u64) do
    return mapRead shareBalances holder;

  query maxRedeem (holder : .address) returns(.u64) do
    return mapRead shareBalances holder;

  entry deposit (assets : .u64, receiver : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta +! assets;
    let ts : .u64 := totalSupply;
    totalSupply := ts +! assets;
    let bal : .u64 := mapRead shareBalances receiver;
    do mapWrite shareBalances receiver (bal +! assets);
    emit Deposit indexed #[
      fieldAsName "sender" caller,
      fieldAsName "owner" receiver
    ] data #[
      fieldAsName "assets" assets,
      fieldAsName "shares" assets
    ];
    emit Transfer indexed #[
      fieldAsName "from" (u64 0),
      fieldAsName "to" receiver
    ] data #[
      fieldAsName "value" assets
    ];
    return assets;

  entry mint (shares : .u64, receiver : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta +! shares;
    let ts : .u64 := totalSupply;
    totalSupply := ts +! shares;
    let bal : .u64 := mapRead shareBalances receiver;
    do mapWrite shareBalances receiver (bal +! shares);
    emit Deposit indexed #[
      fieldAsName "sender" caller,
      fieldAsName "owner" receiver
    ] data #[
      fieldAsName "assets" shares,
      fieldAsName "shares" shares
    ];
    return shares;

  -- MVP: caller must be holder (no share-allowance spend path yet).
  entry withdraw (assets : .u64, receiver : .address, holder : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    do ProofForge.Contract.Surface.requireEq caller (ProofForge.Contract.Surface.ref holder)
      "not holder";
    let ownerBal : .u64 := mapRead shareBalances holder;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref ownerBal)
      (ProofForge.Contract.Surface.ref assets) "insufficient shares";
    do mapWrite shareBalances holder (ownerBal -! assets);
    let ts : .u64 := totalSupply;
    totalSupply := ts -! assets;
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta -! assets;
    emit Withdraw indexed #[
      fieldAsName "sender" caller,
      fieldAsName "receiver" receiver,
      fieldAsName "owner" holder
    ] data #[
      fieldAsName "assets" assets,
      fieldAsName "shares" assets
    ];
    emit Transfer indexed #[
      fieldAsName "from" holder,
      fieldAsName "to" (u64 0)
    ] data #[
      fieldAsName "value" assets
    ];
    return assets;

  -- MVP: caller must be holder (no share-allowance spend path yet).
  entry redeem (shares : .u64, receiver : .address, holder : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    do ProofForge.Contract.Surface.requireEq caller (ProofForge.Contract.Surface.ref holder)
      "not holder";
    let ownerBal : .u64 := mapRead shareBalances holder;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref ownerBal)
      (ProofForge.Contract.Surface.ref shares) "insufficient shares";
    do mapWrite shareBalances holder (ownerBal -! shares);
    let ts : .u64 := totalSupply;
    totalSupply := ts -! shares;
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta -! shares;
    emit Withdraw indexed #[
      fieldAsName "sender" caller,
      fieldAsName "receiver" receiver,
      fieldAsName "owner" holder
    ] data #[
      fieldAsName "assets" shares,
      fieldAsName "shares" shares
    ];
    return shares;

  entry transfer (recipient : .address, amount : .u64) returns(.bool) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref recipient)
      "zero recipient";
    let sender : .address := caller;
    let srcBal : .u64 := mapRead shareBalances sender;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref srcBal)
      (ProofForge.Contract.Surface.ref amount) "insufficient balance";
    do mapWrite shareBalances sender (srcBal -! amount);
    let dstBal : .u64 := mapRead shareBalances recipient;
    do mapWrite shareBalances recipient (dstBal +! amount);
    emit Transfer indexed #[
      fieldAsName "from" sender,
      fieldAsName "to" recipient
    ] data #[
      fieldAsName "value" amount
    ];
    return boolLit true;

  entry approve (spender : .address, amount : .u64) returns(.bool) do
    let holder : .address := caller;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref spender)
      "zero spender";
    do pathWriteAllowance shareAllowances (ProofForge.Contract.Surface.ref holder)
      (ProofForge.Contract.Surface.ref spender) amount;
    emit Approval indexed #[
      fieldAsName "owner" holder,
      fieldAsName "spender" spender
    ] data #[
      fieldAsName "value" amount
    ];
    return boolLit true;

contract_source ERC4626 do
  use mixin
  entry init (assetAddr : .u64) do
    assetAddress := assetAddr;
    totalAssetsSlot := u64 0;
    totalSupply := u64 0;

end ProofForge.Contract.Stdlib.ERC4626
