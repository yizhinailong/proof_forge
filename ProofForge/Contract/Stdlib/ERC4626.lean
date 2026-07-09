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
| Entry fee | Optional **`feeBps` / 10000** on deposit/mint: fee shares mint to
  `feeRecipient`; user gets net. `mint(shares)` = **net** shares requested
  (gross = `shares * 10000 / (10000 - feeBps)` when fee > 0). |
| Exit fee | Same **`feeBps`** on withdraw/redeem: skim fee assets to
  `feeRecipient`; user receives net underlying. |
| Fee-on-transfer assets | Not modeled (assumes transfer amount equals requested) |
| `preview*` | deposit/mint net after entry fee; withdraw/redeem net after exit fee |

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

/-- Entry/exit fee amount from gross (`feeBps` basis points, floor). -/
def feeFromGross (gross feeBps : Nat) : Nat :=
  gross * feeBps / 10000

def entryFeeShares (gross feeBps : Nat) : Nat :=
  feeFromGross gross feeBps

def netAfterEntryFee (gross feeBps : Nat) : Nat :=
  gross - entryFeeShares gross feeBps

def exitFeeAssets (grossAssets feeBps : Nat) : Nat :=
  feeFromGross grossAssets feeBps

def netAfterExitFee (grossAssets feeBps : Nat) : Nat :=
  grossAssets - exitFeeAssets grossAssets feeBps

/-- Gross shares to mint so user receives `net` after entry fee (floor). -/
def grossSharesForNet (net feeBps : Nat) : Option Nat :=
  if feeBps == 0 then some net
  else if feeBps ≥ 10000 then none
  else
    let gross := net * 10000 / (10000 - feeBps)
    if gross == 0 || netAfterEntryFee gross feeBps == 0 then none
    else some gross

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

/-- Withdraw `assets` from vault totals; user receives net after exit fee.
Returns `(next, sharesBurned)`. -/
def withdraw? (s : State) (assets : Nat) (feeBps : Nat := 0) : Option (State × Nat) :=
  if assets == 0 || assets > s.totalAssets then none
  else
    let shares := convertToShares s assets
    if shares == 0 || shares > s.totalSupply then none
    else
      let userAssets := netAfterExitFee assets feeBps
      if userAssets == 0 then none
      else some ({
        totalAssets := s.totalAssets - assets
        totalSupply := s.totalSupply - shares
      }, shares)

/-- Redeem `shares`; user assets net of exit fee. Returns `(next, userAssets)`. -/
def redeem? (s : State) (shares : Nat) (feeBps : Nat := 0) : Option (State × Nat) :=
  if shares == 0 || shares > s.totalSupply then none
  else
    let assets := convertToAssets s shares
    if assets == 0 || assets > s.totalAssets then none
    else
      let userAssets := netAfterExitFee assets feeBps
      if userAssets == 0 then none
      else some ({
        totalAssets := s.totalAssets - assets
        totalSupply := s.totalSupply - shares
      }, userAssets)

theorem empty_convert_shares (a : Nat) : convertToShares empty a = a := by
  simp [convertToShares, empty]

theorem empty_convert_assets (sh : Nat) : convertToAssets empty sh = sh := by
  simp [convertToAssets, empty]

theorem entry_fee_zero (g : Nat) : entryFeeShares g 0 = 0 := by
  simp [entryFeeShares, feeFromGross]

theorem entry_fee_one_percent :
    entryFeeShares 1000 100 = 10 := by
  decide

theorem deposit_fee_user_shares :
    netAfterEntryFee (convertToShares empty 1000) 100 = 990 := by
  decide

theorem exit_fee_one_percent :
    netAfterExitFee 1000 100 = 990 := by
  decide

theorem gross_for_net_zero_fee (n : Nat) :
    grossSharesForNet n 0 = some n := by
  simp [grossSharesForNet]

theorem gross_for_net_one_percent :
    grossSharesForNet 990 100 = some 1000 := by
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

/-- `convertScratch` holds **gross** assets. Exit fee skim → `feeScratch`;
    net user assets remain in `convertScratch`. -/
def applyExitFee : EntryM Unit := do
  let gross := ProofForge.Contract.Surface.read convertScratch
  let bps := ProofForge.Contract.Surface.read feeBps
  ProofForge.Contract.Surface.write feeScratch
    (ProofForge.Contract.Surface.div
      (ProofForge.Contract.Surface.mul gross bps)
      (ProofForge.Contract.Surface.u64 10000))
  ProofForge.Contract.Surface.write convertScratch
    (ProofForge.Contract.Surface.sub gross
      (ProofForge.Contract.Surface.read feeScratch))

/-- `convertScratch` holds **net** shares desired. Overwrite with **gross** mint
    so that after entry fee the user receives approximately net
    (`gross = net * 10000 / (10000 - feeBps)`). Fee 0 → identity. -/
def applyGrossFromNetShares : EntryM Unit := do
  let net := ProofForge.Contract.Surface.read convertScratch
  let bps := ProofForge.Contract.Surface.read feeBps
  ProofForge.Contract.Surface.whenPositive bps do
    ProofForge.Contract.Surface.requireNe bps (ProofForge.Contract.Surface.u64 10000)
      "feeBps 10000 blocks mint"
    let denom :=
      ProofForge.Contract.Surface.sub (ProofForge.Contract.Surface.u64 10000) bps
    ProofForge.Contract.Surface.write convertScratch
      (ProofForge.Contract.Surface.div
        (ProofForge.Contract.Surface.mul net (ProofForge.Contract.Surface.u64 10000))
        denom)

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

/-- Push exit-fee assets to `feeRecipient` (IERC20 transfer). -/
def pushExitFeeAssetsIfAny : EntryM Unit := do
  let fee := ProofForge.Contract.Surface.read feeScratch
  ProofForge.Contract.Surface.whenPositive fee do
    let recip := ProofForge.Contract.Surface.read feeRecipient
    ProofForge.Contract.Surface.requireNonZero recip "zero feeRecipient"
    let assetTok := ProofForge.Contract.Surface.read assetAddress
    let _sent :=
      ProofForge.Contract.Surface.remoteCall assetTok
        (ProofForge.Contract.Surface.u64 0xa9059cbb)
        #[recip, fee]
    pure ()

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
    -- max **net** assets redeemable after exit fee
    convertScratch := mapRead shareBalances holder;
    do applyConvertToAssets (ProofForge.Contract.Surface.read convertScratch);
    do applyExitFee;
    return convertScratch;

  query maxRedeem (holder : .address) returns(.u64) do
    return mapRead shareBalances holder;

  query feeBps returns(.u64) do
    return feeBps;

  query feeRecipient returns(.u64) do
    return feeRecipient;

  -- preview: net after entry fee (deposit/mint) or exit fee (withdraw/redeem)
  query previewDeposit (assets : .u64) returns(.u64) do
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    do applyEntryFee;
    return convertScratch;

  query previewMint (shares : .u64) returns(.u64) do
    -- assets required so user receives **net** `shares` after entry fee
    convertScratch := shares;
    do applyGrossFromNetShares;
    let gross : .u64 := convertScratch;
    convertScratch := gross;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref gross);
    return convertScratch;

  query previewWithdraw (assets : .u64) returns(.u64) do
    -- shares burned to withdraw `assets` from vault (user gets net after exit fee)
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    return convertScratch;

  query previewRedeem (shares : .u64) returns(.u64) do
    -- net assets user receives after exit fee
    convertScratch := shares;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref shares);
    do applyExitFee;
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
    -- `shares` is **net** user receives; compute gross mint for entry fee
    convertScratch := shares;
    do applyGrossFromNetShares;
    let gross : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref gross)
      "zero gross shares";
    convertScratch := gross;
    do applyConvertToAssets (ProofForge.Contract.Surface.ref gross);
    let assets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref assets)
      "zero assets";
    convertScratch := gross;
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
    totalSupply := ts +! gross;
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
    -- `assets` leave the vault; user receives net after exit fee
    convertScratch := assets;
    do applyConvertToShares (ProofForge.Contract.Surface.ref assets);
    let shares : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref shares)
      "zero shares";
    convertScratch := assets;
    do applyExitFee;
    let userAssets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref userAssets)
      "zero net assets";
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
        #[ProofForge.Contract.Surface.ref receiver, ProofForge.Contract.Surface.ref userAssets];
    do pushExitFeeAssetsIfAny;
    emit Withdraw indexed #[
      fieldAsName "sender" caller,
      fieldAsName "receiver" receiver,
      fieldAsName "owner" holder
    ] data #[
      fieldAsName "assets" userAssets,
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
    let grossAssets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref grossAssets)
      "zero assets";
    convertScratch := grossAssets;
    do applyExitFee;
    let userAssets : .u64 := convertScratch;
    do ProofForge.Contract.Surface.requireNonZero (ProofForge.Contract.Surface.ref userAssets)
      "zero net assets";
    let ownerBal : .u64 := mapRead shareBalances holder;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref ownerBal)
      (ProofForge.Contract.Surface.ref shares) "insufficient shares";
    do mapWrite shareBalances holder (ownerBal -! shares);
    let ts : .u64 := totalSupply;
    totalSupply := ts -! shares;
    let ta : .u64 := totalAssetsSlot;
    totalAssetsSlot := ta -! grossAssets;
    let assetTok : .u64 := assetAddress;
    let _sent : .u64 :=
      ProofForge.Contract.Surface.remoteCall
        (ProofForge.Contract.Surface.ref assetTok)
        (u64 0xa9059cbb)
        #[ProofForge.Contract.Surface.ref receiver, ProofForge.Contract.Surface.ref userAssets];
    do pushExitFeeAssetsIfAny;
    emit Withdraw indexed #[
      fieldAsName "sender" caller,
      fieldAsName "receiver" receiver,
      fieldAsName "owner" holder
    ] data #[
      fieldAsName "assets" userAssets,
      fieldAsName "shares" shares
    ];
    return userAssets;

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
