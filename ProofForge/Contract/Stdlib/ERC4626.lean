/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer C — ERC-4626 vault mixin (pro-rata exchange rate)

Deployable vault **body** (you *are* the vault), not the Layer B external
client (`Protocols.Evm.IERC4626` / Product `external_vault`).

## Honesty bounds

| Feature | Behavior |
|---------|----------|
| Exchange rate | **Pro-rata**: `shares = assets * totalSupply / totalAssets` when supply > 0;
  empty vault (`totalSupply = 0`) is **1:1**. Floor division (OpenZeppelin-style). |
| Underlying ERC-20 | `deposit`/`mint` **pull** via IERC20 `transferFrom(caller, vaultSelf, amount)`;
  `withdraw`/`redeem` **push** via IERC20 `transfer(receiver, amount)`.
  `vaultSelf` is init-set (portable `address(this)`). Method words are EVM
  selectors — **EVM-primary** packing. |
| Share token | Minimal ERC-20 surface on **shares** |
| Entry fee | Optional **`feeBps` / 10000** on deposit/mint share mint:
  `feeShares = gross * feeBps / 10000`, user gets `gross - fee`, fee minted
  to `feeRecipient`. Zero bps = previous behavior. Exit fees: none. |
| Fee-on-transfer assets | Not modeled (assumes transfer amount equals requested) |
| `preview*` deposit/mint | Net after entry fee; withdraw/redeem = convert floor |

Spec math lives in `Spec` (Nat formulas + fee/empty-vault theorems).
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.ERC4626

open ProofForge.Contract.Source

namespace Spec

structure State where
  totalAssets : Nat
  totalSupply : Nat

def empty : State := { totalAssets := 0, totalSupply := 0 }

/-- OpenZeppelin-style convert (floor). Empty supply → 1:1. -/
def convertToShares (s : State) (assets : Nat) : Nat :=
  if s.totalSupply == 0 || s.totalAssets == 0 then assets
  else assets * s.totalSupply / s.totalAssets

def convertToAssets (s : State) (shares : Nat) : Nat :=
  if s.totalSupply == 0 || s.totalAssets == 0 then shares
  else shares * s.totalAssets / s.totalSupply

/-- Entry fee shares from gross mint (`feeBps` basis points, floor). -/
def entryFeeShares (gross feeBps : Nat) : Nat :=
  gross * feeBps / 10000

def netAfterEntryFee (gross feeBps : Nat) : Nat :=
  gross - entryFeeShares gross feeBps

/-- Deposit; optional entry fee. Returns `(next, userShares)` where
`totalSupply` grows by **gross** shares (user + fee). -/
def deposit? (s : State) (assets : Nat) (feeBps : Nat := 0) : Option (State × Nat) :=
  if assets == 0 then none
  else
    let gross := convertToShares s assets
    if gross == 0 then none
    else
      let fee := entryFeeShares gross feeBps
      let user := gross - fee
      if user == 0 then none
      else some ({
        totalAssets := s.totalAssets + assets
        totalSupply := s.totalSupply + gross
      }, user)

def withdraw? (s : State) (assets : Nat) : Option (State × Nat) :=
  if assets == 0 || assets > s.totalAssets then none
  else
    let shares := convertToShares s assets
    if shares == 0 || shares > s.totalSupply then none
    else some ({
      totalAssets := s.totalAssets - assets
      totalSupply := s.totalSupply - shares
    }, shares)

def redeem? (s : State) (shares : Nat) : Option (State × Nat) :=
  if shares == 0 || shares > s.totalSupply then none
  else
    let assets := convertToAssets s shares
    if assets == 0 || assets > s.totalAssets then none
    else some ({
      totalAssets := s.totalAssets - assets
      totalSupply := s.totalSupply - shares
    }, assets)

theorem empty_convert_shares (a : Nat) : convertToShares empty a = a := by
  simp [convertToShares, empty]

theorem empty_convert_assets (sh : Nat) : convertToAssets empty sh = sh := by
  simp [convertToAssets, empty]

theorem deposit_empty_1to1 (a : Nat) (ha : a ≠ 0) :
    deposit? empty a 0 = some ({ totalAssets := a, totalSupply := a }, a) := by
  simp [deposit?, convertToShares, empty, entryFeeShares, ha]

theorem entry_fee_zero (g : Nat) : entryFeeShares g 0 = 0 := by
  simp [entryFeeShares]

theorem entry_fee_one_percent :
    entryFeeShares 1000 100 = 10 := by
  decide

theorem deposit_fee_user_shares :
    netAfterEntryFee (convertToShares empty 1000) 100 = 990 := by
  decide

/-- After a first deposit of `a`, convert is still 1:1. -/
theorem convert_after_first_deposit (a assets : Nat) (ha : a ≠ 0) :
    convertToShares { totalAssets := a, totalSupply := a } assets = assets := by
  unfold convertToShares
  have h : (a == 0 || a == 0) = false := by simp [ha]
  rw [h]
  exact Nat.mul_div_cancel assets (Nat.pos_of_ne_zero ha)

/-- Concrete pro-rata: after donation doubles assets, deposit half-rates. -/
theorem convert_donation_example :
    convertToShares { totalAssets := 200, totalSupply := 100 } 100 = 50 := by
  native_decide

theorem convert_assets_donation_example :
    convertToAssets { totalAssets := 200, totalSupply := 100 } 50 = 100 := by
  native_decide

end Spec

def assetAddress : ScalarRef :=
  ProofForge.Contract.Surface.slot "asset" .u64

def vaultSelf : ScalarRef :=
  ProofForge.Contract.Surface.slot "vaultSelf" .u64

def totalAssetsSlot : ScalarRef :=
  ProofForge.Contract.Surface.slot "totalAssets" .u64

def totalSupply : ScalarRef :=
  ProofForge.Contract.Surface.slot "totalSupply" .u64

/-- Scratch for convert results (pro-rata branch). -/
def convertScratch : ScalarRef :=
  ProofForge.Contract.Surface.slot "convertScratch" .u64

/-- Scratch for entry-fee shares (`gross * feeBps / 10000`). -/
def feeScratch : ScalarRef :=
  ProofForge.Contract.Surface.slot "feeScratch" .u64

/-- Entry fee in basis points (0 = off, max 10000). -/
def feeBps : ScalarRef :=
  ProofForge.Contract.Surface.slot "feeBps" .u64

/-- Recipient of entry-fee share mints (must be non-zero when fee > 0). -/
def feeRecipient : ScalarRef :=
  ProofForge.Contract.Surface.slot "feeRecipient" .u64

def shareBalances : MapRef :=
  { id := "shareBalances", keyType := .u64, valueType := .u64 }

def shareAllowances : MapRef :=
  { id := "shareAllowances", keyType := .u64, valueType := .u64 }

/-- When `totalSupply > 0`, overwrite `convertScratch` with
    `amount * totalSupply / totalAssets` (floor). Caller must seed
    `convertScratch` with the empty-vault 1:1 fallback first. -/
def applyConvertToShares (amount : ProofForge.IR.Expr) : EntryM Unit := do
  let ts := ProofForge.Contract.Surface.read totalSupply
  ProofForge.Contract.Surface.whenPositive ts do
    let ta := ProofForge.Contract.Surface.read totalAssetsSlot
    ProofForge.Contract.Surface.requireNonZero ta "zero totalAssets"
    ProofForge.Contract.Surface.write convertScratch
      (ProofForge.Contract.Surface.div
        (ProofForge.Contract.Surface.mul amount ts) ta)

/-- When `totalSupply > 0`, overwrite `convertScratch` with
    `amount * totalAssets / totalSupply` (floor). -/
def applyConvertToAssets (amount : ProofForge.IR.Expr) : EntryM Unit := do
  let ts := ProofForge.Contract.Surface.read totalSupply
  ProofForge.Contract.Surface.whenPositive ts do
    let ta := ProofForge.Contract.Surface.read totalAssetsSlot
    ProofForge.Contract.Surface.requireNonZero ta "zero totalAssets"
    ProofForge.Contract.Surface.write convertScratch
      (ProofForge.Contract.Surface.div
        (ProofForge.Contract.Surface.mul amount ta) ts)

/-- `convertScratch` holds **gross** shares. Writes fee to `feeScratch` and
    net user shares back to `convertScratch`. -/
def applyEntryFee : EntryM Unit := do
  let gross := ProofForge.Contract.Surface.read convertScratch
  let bps := ProofForge.Contract.Surface.read feeBps
  ProofForge.Contract.Surface.write feeScratch
    (ProofForge.Contract.Surface.div
      (ProofForge.Contract.Surface.mul gross bps)
      (ProofForge.Contract.Surface.u64 10000))
  ProofForge.Contract.Surface.write convertScratch
    (ProofForge.Contract.Surface.sub gross
      (ProofForge.Contract.Surface.read feeScratch))

/-- Mint fee shares to `feeRecipient` when fee > 0. -/
def mintFeeSharesIfAny : EntryM Unit := do
  let fee := ProofForge.Contract.Surface.read feeScratch
  ProofForge.Contract.Surface.whenPositive fee do
    let recip := ProofForge.Contract.Surface.read feeRecipient
    ProofForge.Contract.Surface.requireNonZero recip "zero feeRecipient"
    let bal :=
      ProofForge.Contract.Surface.mapGet shareBalances recip
    ProofForge.Contract.Surface.mapSet shareBalances recip
      (ProofForge.Contract.Surface.add bal fee)
    ProofForge.Contract.Surface.emitIndexed (ProofForge.Contract.Surface.event "Transfer")
      #[
        ProofForge.Contract.Surface.field "from" (ProofForge.Contract.Surface.u64 0),
        ProofForge.Contract.Surface.field "to" recip
      ]
      #[ProofForge.Contract.Surface.field "value" fee]

contract_mixin ERC4626Mixin do
  use ProofForge.Contract.Surface.scalar assetAddress
  use ProofForge.Contract.Surface.scalar vaultSelf
  use ProofForge.Contract.Surface.scalar totalAssetsSlot
  use ProofForge.Contract.Surface.scalar totalSupply
  use ProofForge.Contract.Surface.scalar convertScratch
  use ProofForge.Contract.Surface.scalar feeScratch
  use ProofForge.Contract.Surface.scalar feeBps
  use ProofForge.Contract.Surface.scalar feeRecipient
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

  -- pro-rata: empty supply → identity; else assets * supply / totalAssets (floor)
  query convertToShares (assets : .u64) returns(.u64) do
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    return convertScratch;

  query convertToAssets (shares : .u64) returns(.u64) do
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    return convertScratch;

  query maxDeposit (who : .address) returns(.u64) do
    return u64 0xffffffffffffffff;

  query maxMint (who : .address) returns(.u64) do
    return u64 0xffffffffffffffff;

  query maxWithdraw (holder : .address) returns(.u64) do
    convertScratch := mapRead shareBalances holder;
    do applyConvertToAssets (ProofForge.Contract.Surface.read convertScratch);
    return convertScratch;

  query maxRedeem (holder : .address) returns(.u64) do
    return mapRead shareBalances holder;

  query feeBps returns(.u64) do
    return feeBps;

  query feeRecipient returns(.u64) do
    return feeRecipient;

  -- preview deposit/mint: net shares after entry fee; withdraw/redeem: convert floor
  query previewDeposit (assets : .u64) returns(.u64) do
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    do applyEntryFee;
    return convertScratch;

  query previewMint (shares : .u64) returns(.u64) do
    -- assets required for gross `shares` mint (fee is taken from shares, not assets)
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    return convertScratch;

  query previewWithdraw (assets : .u64) returns(.u64) do
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    return convertScratch;

  query previewRedeem (shares : .u64) returns(.u64) do
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    return convertScratch;

  entry deposit (assets : .u64, receiver : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    let gross : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref gross)
      "zero shares";
    do applyEntryFee;
    let shares : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero net shares";
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
    totalSupply := ts +! gross;
    let bal : .u64 := mapRead shareBalances receiver;
    do mapWrite shareBalances receiver (bal +! shares);
    do mintFeeSharesIfAny;
    emit Deposit indexed #[
      fieldAsName "sender" caller,
      fieldAsName "owner" receiver
    ] data #[
      fieldAsName "assets" assets,
      fieldAsName "shares" shares
    ];
    emit Transfer indexed #[
      fieldAsName "from" (u64 0),
      fieldAsName "to" receiver
    ] data #[
      fieldAsName "value" shares
    ];
    return shares;

  entry mint (shares : .u64, receiver : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    -- `shares` is gross mint; user receives net after entry fee
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    let assets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    convertScratch := shares;
    do applyEntryFee;
    let userShares : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref userShares)
      "zero net shares";
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
    totalSupply := ts +! shares;
    let bal : .u64 := mapRead shareBalances receiver;
    do mapWrite shareBalances receiver (bal +! userShares);
    do mintFeeSharesIfAny;
    emit Deposit indexed #[
      fieldAsName "sender" caller,
      fieldAsName "owner" receiver
    ] data #[
      fieldAsName "assets" assets,
      fieldAsName "shares" userShares
    ];
    emit Transfer indexed #[
      fieldAsName "from" (u64 0),
      fieldAsName "to" receiver
    ] data #[
      fieldAsName "value" userShares
    ];
    return assets;

  entry withdraw (assets : .u64, receiver : .address, holder : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    do ProofForge.Contract.Surface.requireEq caller (ProofForge.Contract.Surface.ref holder)
      "not holder";
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    let shares : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    let ownerBal : .u64 := mapRead shareBalances holder;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref ownerBal)
      (ProofForge.Contract.Surface.ref shares) "insufficient shares";
    do mapWrite shareBalances holder (ownerBal -! shares);
    let ts : .u64 := totalSupply;
    totalSupply := ts -! shares;
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta -! assets;
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
      fieldAsName "shares" shares
    ];
    emit Transfer indexed #[
      fieldAsName "from" holder,
      fieldAsName "to" (u64 0)
    ] data #[
      fieldAsName "value" shares
    ];
    return shares;

  entry redeem (shares : .u64, receiver : .address, holder : .address) returns(.u64) do
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref receiver)
      "zero receiver";
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    do ProofForge.Contract.Surface.requireEq caller (ProofForge.Contract.Surface.ref holder)
      "not holder";
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    let assets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    let ownerBal : .u64 := mapRead shareBalances holder;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref ownerBal)
      (ProofForge.Contract.Surface.ref shares) "insufficient shares";
    do mapWrite shareBalances holder (ownerBal -! shares);
    let ts : .u64 := totalSupply;
    totalSupply := ts -! shares;
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta -! assets;
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
      fieldAsName "shares" shares
    ];
    return assets;

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
  -- feeBpsVal ∈ [0, 10000]; feeRecipientAddr used only when fee shares > 0
  entry init (assetAddr : .u64, selfAddr : .u64, feeBpsVal : .u64, feeRecipientAddr : .u64) do
    assetAddress := assetAddr;
    vaultSelf := selfAddr;
    do ProofForge.Contract.Surface.requireGe (u64 10000)
      (ProofForge.Contract.Surface.ref feeBpsVal) "feeBps > 10000";
    feeBps := feeBpsVal;
    feeRecipient := feeRecipientAddr;
    totalAssetsSlot := u64 0;
    totalSupply := u64 0;
    feeScratch := u64 0;

end ProofForge.Contract.Stdlib.ERC4626
