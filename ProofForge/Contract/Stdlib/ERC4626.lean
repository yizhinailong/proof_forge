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
| Underlying ERC-20 | `deposit`/`mint` **pull** via IERC20 `transferFrom(caller, vaultSelf, amount)`;
  `withdraw`/`redeem` **push** via IERC20 `transfer(receiver, amount)`.
  `vaultSelf` is set in `init` (portable stand-in for `address(this)` so Solana/NEAR
  do not need unsupported `contractId`). Method words are EVM selectors
  (`0x23b872dd` / `0xa9059cbb`) — **EVM-primary** packing; other hosts still get
  portable remote nodes (CPI/promise smoke). |
| Share token | Minimal ERC-20 surface: `balanceOf` / `totalSupply` / `transfer` /
  `approve` on **shares** |
| Full fee / preview rounding | Deferred |

Solvent model: `totalAssets = totalSupply` (1:1) when pull/push succeed.
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

/-- Portable vault self address (init-set stand-in for `address(this)`). -/
def vaultSelf : ScalarRef :=
  ProofForge.Contract.Surface.slot "vaultSelf" .u64

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
  use ProofForge.Contract.Surface.scalar vaultSelf
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

  -- IERC20 transferFrom / transfer selectors (EVM-primary remote packing).
  -- transferFrom(address,address,uint256) = 0x23b872dd
  -- transfer(address,uint256) = 0xa9059cbb

  entry deposit (assets : .u64, receiver : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    -- Pull underlying: transferFrom(caller, this, assets)
    let assetTok : .u64 := assetAddress;
    let selfAddr : .u64 := vaultSelf;
    let _pulled : .u64 :=
      ProofForge.Contract.Surface.remoteCall
        (ProofForge.Contract.Surface.ref assetTok)
        (u64 0x23b872dd)
        #[caller, ProofForge.Contract.Surface.ref selfAddr, ProofForge.Contract.Surface.ref assets];
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
    let assetTok : .u64 := assetAddress;
    let selfAddr : .u64 := vaultSelf;
    let _pulled : .u64 :=
      ProofForge.Contract.Surface.remoteCall
        (ProofForge.Contract.Surface.ref assetTok)
        (u64 0x23b872dd)
        #[caller, ProofForge.Contract.Surface.ref selfAddr, ProofForge.Contract.Surface.ref shares];
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
    -- Push underlying: transfer(receiver, assets)
    let assetTok : .u64 := assetAddress;
    let _sent : .u64 :=
      ProofForge.Contract.Surface.remoteCall
        (ProofForge.Contract.Surface.ref assetTok)
        (u64 0xa9059cbb)
        #[ProofForge.Contract.Surface.ref receiver, ProofForge.Contract.Surface.ref assets];
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
    let assetTok : .u64 := assetAddress;
    let _sent : .u64 :=
      ProofForge.Contract.Surface.remoteCall
        (ProofForge.Contract.Surface.ref assetTok)
        (u64 0xa9059cbb)
        #[ProofForge.Contract.Surface.ref receiver, ProofForge.Contract.Surface.ref shares];
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
  -- assetAddr: underlying ERC-20; selfAddr: this vault (portable address(this)).
  entry init (assetAddr : .u64, selfAddr : .u64) do
    assetAddress := assetAddr;
    vaultSelf := selfAddr;
    totalAssetsSlot := u64 0;
    totalSupply := u64 0;

end ProofForge.Contract.Stdlib.ERC4626
