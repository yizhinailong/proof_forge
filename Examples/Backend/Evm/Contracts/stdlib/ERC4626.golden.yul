object "ERC4626" {
  code {
    switch shr(224, calldataload(0))
    case 0x38d52e0f {
      let _r := f_ERC4626_asset()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x01e1d114 {
      let _r := f_ERC4626_totalAssets()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x18160ddd {
      let _r := f_ERC4626_totalSupply()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x70a08231 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_balanceOf(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc6e6f592 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_convertToShares(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x07a2d13a {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_convertToAssets(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x402d267d {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_maxDeposit(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc63d75b6 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_maxMint(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xce96cb77 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_maxWithdraw(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xd905777e {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_maxRedeem(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x24a9d853 {
      let _r := f_ERC4626_feeBps()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x46904840 {
      let _r := f_ERC4626_feeRecipient()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xef8b30f7 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_previewDeposit(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xb3d7f6b9 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_previewMint(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0a28a477 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_previewWithdraw(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x4cdad506 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_ERC4626_previewRedeem(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x6e553f65 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_ERC4626_deposit(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x94bf804d {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_ERC4626_mint(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xb460af94 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_ERC4626_withdraw(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xba087652 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_ERC4626_redeem(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xa9059cbb {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_ERC4626_transfer(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x095ea7b3 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_ERC4626_approve(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x7662850d {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      f_ERC4626_init(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_ERC4626_asset() -> result {
      result := and(shr(192, sload(0)), 18446744073709551615)
    }
    function f_ERC4626_totalAssets() -> result {
      result := and(shr(64, sload(0)), 18446744073709551615)
    }
    function f_ERC4626_totalSupply() -> result {
      result := and(shr(0, sload(0)), 18446744073709551615)
    }
    function f_ERC4626_balanceOf(who) -> result {
      result := sload(__proof_forge_map_slot(3, who))
    }
    function f_ERC4626_convertToShares(assets) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, assets)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(assets, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_convertToAssets(shares) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, shares)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(shares, and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_maxDeposit(who) -> result {
      result := 18446744073709551615
    }
    function f_ERC4626_maxMint(who) -> result {
      result := 18446744073709551615
    }
    function f_ERC4626_maxWithdraw(holder) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, sload(__proof_forge_map_slot(3, holder)))))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_maxRedeem(holder) -> result {
      result := sload(__proof_forge_map_slot(3, holder))
    }
    function f_ERC4626_feeBps() -> result {
      result := and(shr(64, sload(2)), 18446744073709551615)
    }
    function f_ERC4626_feeRecipient() -> result {
      result := and(shr(0, sload(2)), 18446744073709551615)
    }
    function f_ERC4626_previewDeposit(assets) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, assets)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(assets, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_previewMint(shares) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, shares)))
      switch gt(and(shr(64, sload(2)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(2)), 18446744073709551615), 10000))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), 10000), __pf_checked_sub(10000, and(shr(64, sload(2)), 18446744073709551615))))))
      }
      let gross := and(shr(192, sload(1)), 18446744073709551615)
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, gross)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(gross, and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_previewWithdraw(assets) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, assets)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(assets, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_previewRedeem(shares) -> result {
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, shares)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(shares, and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      result := and(shr(192, sload(1)), 18446744073709551615)
    }
    function f_ERC4626_deposit(assets, receiver) -> result {
      if iszero(iszero(eq(receiver, 0))) {
        revert(0, 0)
      }
      if iszero(iszero(eq(assets, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(64, 18446744073709551615))), shl(64, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615)))))
      let _pf_pull := __proof_forge_crosscall_3(and(shr(192, sload(0)), 18446744073709551615), 599290589, caller(), and(shr(128, sload(0)), 18446744073709551615), assets)
      let _pf_bal_after := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615))
      sstore(1, or(and(sload(1), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(_pf_bal_after, and(shr(64, sload(1)), 18446744073709551615)))))
      if iszero(iszero(eq(and(shr(0, sload(1)), 18446744073709551615), 0))) {
        revert(0, 0)
      }
      let actual := and(shr(0, sload(1)), 18446744073709551615)
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, actual)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(actual, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      let gross := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(gross, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      let shares := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(shares, 0))) {
        revert(0, 0)
      }
      let ta := and(shr(64, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(64, 18446744073709551615))), shl(64, __pf_checked_add(ta, actual))))
      let ts := and(shr(0, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_add(ts, gross))))
      let bal := sload(__proof_forge_map_slot(3, receiver))
      __proof_forge_map_write(3, receiver, __pf_checked_add(bal, shares))
      switch gt(and(shr(128, sload(1)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(0, sload(2)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        __proof_forge_map_write(3, and(shr(0, sload(2)), 18446744073709551615), __pf_checked_add(sload(__proof_forge_map_slot(3, and(shr(0, sload(2)), 18446744073709551615))), and(shr(128, sload(1)), 18446744073709551615)))
        {
          mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
          mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
          let _topic0 := keccak256(0, 33)
          let _indexed_topic0 := 0
          let _indexed_topic1 := and(shr(0, sload(2)), 18446744073709551615)
          mstore(0, and(shr(128, sload(1)), 18446744073709551615))
          log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
        }
      }
      {
        mstore(0, 30936501257503946518829057408626967045710902236682229979781169841054563002734)
        mstore(32, 52564060173324780267596278835754282818996031008839138188382124664963096117248)
        let _topic0 := keccak256(0, 36)
        let _indexed_topic0 := caller()
        let _indexed_topic1 := receiver
        mstore(0, actual)
        mstore(32, shares)
        log3(0, 64, _topic0, _indexed_topic0, _indexed_topic1)
      }
      {
        mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
        mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
        let _topic0 := keccak256(0, 33)
        let _indexed_topic0 := 0
        let _indexed_topic1 := receiver
        mstore(0, shares)
        log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
      }
      result := shares
    }
    function f_ERC4626_mint(shares, receiver) -> result {
      if iszero(iszero(eq(receiver, 0))) {
        revert(0, 0)
      }
      if iszero(iszero(eq(shares, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, shares)))
      switch gt(and(shr(64, sload(2)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(2)), 18446744073709551615), 10000))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), 10000), __pf_checked_sub(10000, and(shr(64, sload(2)), 18446744073709551615))))))
      }
      let grossWanted := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(grossWanted, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, grossWanted)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(grossWanted, and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      let assetsWanted := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(assetsWanted, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(64, 18446744073709551615))), shl(64, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615)))))
      let _pf_pull := __proof_forge_crosscall_3(and(shr(192, sload(0)), 18446744073709551615), 599290589, caller(), and(shr(128, sload(0)), 18446744073709551615), assetsWanted)
      let _pf_bal_after := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615))
      sstore(1, or(and(sload(1), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(_pf_bal_after, and(shr(64, sload(1)), 18446744073709551615)))))
      if iszero(iszero(eq(and(shr(0, sload(1)), 18446744073709551615), 0))) {
        revert(0, 0)
      }
      let actual := and(shr(0, sload(1)), 18446744073709551615)
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, actual)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(actual, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      let gross := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(gross, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      let userShares := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(userShares, 0))) {
        revert(0, 0)
      }
      let ta := and(shr(64, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(64, 18446744073709551615))), shl(64, __pf_checked_add(ta, actual))))
      let ts := and(shr(0, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_add(ts, gross))))
      let bal := sload(__proof_forge_map_slot(3, receiver))
      __proof_forge_map_write(3, receiver, __pf_checked_add(bal, userShares))
      switch gt(and(shr(128, sload(1)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(0, sload(2)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        __proof_forge_map_write(3, and(shr(0, sload(2)), 18446744073709551615), __pf_checked_add(sload(__proof_forge_map_slot(3, and(shr(0, sload(2)), 18446744073709551615))), and(shr(128, sload(1)), 18446744073709551615)))
        {
          mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
          mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
          let _topic0 := keccak256(0, 33)
          let _indexed_topic0 := 0
          let _indexed_topic1 := and(shr(0, sload(2)), 18446744073709551615)
          mstore(0, and(shr(128, sload(1)), 18446744073709551615))
          log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
        }
      }
      {
        mstore(0, 30936501257503946518829057408626967045710902236682229979781169841054563002734)
        mstore(32, 52564060173324780267596278835754282818996031008839138188382124664963096117248)
        let _topic0 := keccak256(0, 36)
        let _indexed_topic0 := caller()
        let _indexed_topic1 := receiver
        mstore(0, actual)
        mstore(32, userShares)
        log3(0, 64, _topic0, _indexed_topic0, _indexed_topic1)
      }
      {
        mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
        mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
        let _topic0 := keccak256(0, 33)
        let _indexed_topic0 := 0
        let _indexed_topic1 := receiver
        mstore(0, userShares)
        log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
      }
      result := actual
    }
    function f_ERC4626_withdraw(assets, receiver, holder) -> result {
      if iszero(iszero(eq(receiver, 0))) {
        revert(0, 0)
      }
      if iszero(iszero(eq(assets, 0))) {
        revert(0, 0)
      }
      if iszero(eq(caller(), holder)) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, assets)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(assets, and(shr(0, sload(0)), 18446744073709551615)), and(shr(64, sload(0)), 18446744073709551615)))))
      }
      let shares := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(shares, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, assets)))
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      let userAssets := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(userAssets, 0))) {
        revert(0, 0)
      }
      let ownerBal := sload(__proof_forge_map_slot(3, holder))
      if iszero(iszero(lt(ownerBal, shares))) {
        revert(0, 0)
      }
      __proof_forge_map_write(3, holder, __pf_checked_sub(ownerBal, shares))
      let ts := and(shr(0, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(ts, shares))))
      sstore(1, or(and(sload(1), not(shl(64, 18446744073709551615))), shl(64, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615)))))
      sstore(2, or(and(sload(2), not(shl(192, 18446744073709551615))), shl(192, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, receiver))))
      let _pf_push_recv := __proof_forge_crosscall_2(and(shr(192, sload(0)), 18446744073709551615), 2835717307, receiver, userAssets)
      let _pf_recv_after := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, receiver)
      sstore(2, or(and(sload(2), not(shl(128, 18446744073709551615))), shl(128, __pf_checked_sub(_pf_recv_after, and(shr(192, sload(2)), 18446744073709551615)))))
      switch gt(and(shr(128, sload(1)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(0, sload(2)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        let _pf_exit_fee_push := __proof_forge_crosscall_2(and(shr(192, sload(0)), 18446744073709551615), 2835717307, and(shr(0, sload(2)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615))
      }
      let _pf_bal_after_push := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615))
      sstore(1, or(and(sload(1), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(and(shr(64, sload(1)), 18446744073709551615), _pf_bal_after_push))))
      if iszero(iszero(eq(and(shr(0, sload(1)), 18446744073709551615), 0))) {
        revert(0, 0)
      }
      let actualLeft := and(shr(0, sload(1)), 18446744073709551615)
      let actualRecv := and(shr(128, sload(2)), 18446744073709551615)
      if iszero(iszero(lt(and(shr(64, sload(0)), 18446744073709551615), actualLeft))) {
        revert(0, 0)
      }
      let ta := and(shr(64, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(64, 18446744073709551615))), shl(64, __pf_checked_sub(ta, actualLeft))))
      {
        mstore(0, 39537540185534869899848144892628232627837003291985737810377847980649312187753)
        mstore(32, 49959741704575589949118613920192228808117714233700886055915928452907449450496)
        let _topic0 := keccak256(0, 44)
        let _indexed_topic0 := caller()
        let _indexed_topic1 := receiver
        let _indexed_topic2 := holder
        mstore(0, actualRecv)
        mstore(32, shares)
        log4(0, 64, _topic0, _indexed_topic0, _indexed_topic1, _indexed_topic2)
      }
      {
        mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
        mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
        let _topic0 := keccak256(0, 33)
        let _indexed_topic0 := holder
        let _indexed_topic1 := 0
        mstore(0, shares)
        log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
      }
      result := shares
    }
    function f_ERC4626_redeem(shares, receiver, holder) -> result {
      if iszero(iszero(eq(receiver, 0))) {
        revert(0, 0)
      }
      if iszero(iszero(eq(shares, 0))) {
        revert(0, 0)
      }
      if iszero(eq(caller(), holder)) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, shares)))
      switch gt(and(shr(0, sload(0)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(64, sload(0)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, div(__pf_checked_mul(shares, and(shr(64, sload(0)), 18446744073709551615)), and(shr(0, sload(0)), 18446744073709551615)))))
      }
      let grossAssets := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(grossAssets, 0))) {
        revert(0, 0)
      }
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, grossAssets)))
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, div(__pf_checked_mul(and(shr(192, sload(1)), 18446744073709551615), and(shr(64, sload(2)), 18446744073709551615)), 10000))))
      sstore(1, or(and(sload(1), not(shl(192, 18446744073709551615))), shl(192, __pf_checked_sub(and(shr(192, sload(1)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615)))))
      let userAssets := and(shr(192, sload(1)), 18446744073709551615)
      if iszero(iszero(eq(userAssets, 0))) {
        revert(0, 0)
      }
      let ownerBal := sload(__proof_forge_map_slot(3, holder))
      if iszero(iszero(lt(ownerBal, shares))) {
        revert(0, 0)
      }
      __proof_forge_map_write(3, holder, __pf_checked_sub(ownerBal, shares))
      let ts := and(shr(0, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(ts, shares))))
      sstore(1, or(and(sload(1), not(shl(64, 18446744073709551615))), shl(64, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615)))))
      sstore(2, or(and(sload(2), not(shl(192, 18446744073709551615))), shl(192, __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, receiver))))
      let _pf_push_recv := __proof_forge_crosscall_2(and(shr(192, sload(0)), 18446744073709551615), 2835717307, receiver, userAssets)
      let _pf_recv_after := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, receiver)
      sstore(2, or(and(sload(2), not(shl(128, 18446744073709551615))), shl(128, __pf_checked_sub(_pf_recv_after, and(shr(192, sload(2)), 18446744073709551615)))))
      switch gt(and(shr(128, sload(1)), 18446744073709551615), 0)
      case 0 { }
      default {
        if iszero(iszero(eq(and(shr(0, sload(2)), 18446744073709551615), 0))) {
          revert(0, 0)
        }
        let _pf_exit_fee_push := __proof_forge_crosscall_2(and(shr(192, sload(0)), 18446744073709551615), 2835717307, and(shr(0, sload(2)), 18446744073709551615), and(shr(128, sload(1)), 18446744073709551615))
      }
      let _pf_bal_after_push := __proof_forge_crosscall_1(and(shr(192, sload(0)), 18446744073709551615), 1889567281, and(shr(128, sload(0)), 18446744073709551615))
      sstore(1, or(and(sload(1), not(shl(0, 18446744073709551615))), shl(0, __pf_checked_sub(and(shr(64, sload(1)), 18446744073709551615), _pf_bal_after_push))))
      if iszero(iszero(eq(and(shr(0, sload(1)), 18446744073709551615), 0))) {
        revert(0, 0)
      }
      let actualLeft := and(shr(0, sload(1)), 18446744073709551615)
      let actualRecv := and(shr(128, sload(2)), 18446744073709551615)
      if iszero(iszero(lt(and(shr(64, sload(0)), 18446744073709551615), actualLeft))) {
        revert(0, 0)
      }
      let ta := and(shr(64, sload(0)), 18446744073709551615)
      sstore(0, or(and(sload(0), not(shl(64, 18446744073709551615))), shl(64, __pf_checked_sub(ta, actualLeft))))
      {
        mstore(0, 39537540185534869899848144892628232627837003291985737810377847980649312187753)
        mstore(32, 49959741704575589949118613920192228808117714233700886055915928452907449450496)
        let _topic0 := keccak256(0, 44)
        let _indexed_topic0 := caller()
        let _indexed_topic1 := receiver
        let _indexed_topic2 := holder
        mstore(0, actualRecv)
        mstore(32, shares)
        log4(0, 64, _topic0, _indexed_topic0, _indexed_topic1, _indexed_topic2)
      }
      result := actualRecv
    }
    function f_ERC4626_transfer(recipient, amount) -> result {
      if iszero(iszero(eq(recipient, 0))) {
        revert(0, 0)
      }
      let sender := caller()
      let srcBal := sload(__proof_forge_map_slot(3, sender))
      if iszero(iszero(lt(srcBal, amount))) {
        revert(0, 0)
      }
      __proof_forge_map_write(3, sender, __pf_checked_sub(srcBal, amount))
      let dstBal := sload(__proof_forge_map_slot(3, recipient))
      __proof_forge_map_write(3, recipient, __pf_checked_add(dstBal, amount))
      {
        mstore(0, 38196372293521921433607444633801509737016894376733792893611070291108288410934)
        mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
        let _topic0 := keccak256(0, 33)
        let _indexed_topic0 := sender
        let _indexed_topic1 := recipient
        mstore(0, amount)
        log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
      }
      result := 1
    }
    function f_ERC4626_approve(spender, amount) -> result {
      let holder := caller()
      if iszero(iszero(eq(spender, 0))) {
        revert(0, 0)
      }
      {
        let _slot := __proof_forge_map_slot(__proof_forge_map_slot(4, holder), spender)
        let _presence_slot := __proof_forge_map_presence_slot(__proof_forge_map_slot(4, holder), spender)
        sstore(_slot, amount)
        sstore(_presence_slot, 1)
      }
      {
        mstore(0, 29598998109930618199054758324288223757593108964568133265786181954376800810294)
        mstore(32, 18544826791913921923306290567797672742125270981606496584444378688767337168896)
        let _topic0 := keccak256(0, 33)
        let _indexed_topic0 := holder
        let _indexed_topic1 := spender
        mstore(0, amount)
        log3(0, 32, _topic0, _indexed_topic0, _indexed_topic1)
      }
      result := 1
    }
    function f_ERC4626_init(assetAddr, selfAddr, feeBpsVal, feeRecipientAddr) {
      sstore(0, or(and(sload(0), not(shl(192, 18446744073709551615))), shl(192, assetAddr)))
      sstore(0, or(and(sload(0), not(shl(128, 18446744073709551615))), shl(128, selfAddr)))
      if iszero(iszero(lt(10000, feeBpsVal))) {
        revert(0, 0)
      }
      sstore(2, or(and(sload(2), not(shl(64, 18446744073709551615))), shl(64, feeBpsVal)))
      sstore(2, or(and(sload(2), not(shl(0, 18446744073709551615))), shl(0, feeRecipientAddr)))
      sstore(0, or(and(sload(0), not(shl(64, 18446744073709551615))), shl(64, 0)))
      sstore(0, or(and(sload(0), not(shl(0, 18446744073709551615))), shl(0, 0)))
      sstore(1, or(and(sload(1), not(shl(128, 18446744073709551615))), shl(128, 0)))
    }
    function __proof_forge_map_slot(slot, key) -> result {
      mstore(0, key)
      mstore(32, slot)
      result := keccak256(0, 64)
    }
    function __proof_forge_map_presence_slot(slot, key) -> result {
      mstore(0, slot)
      mstore(32, 1969478005224772198022937154314036040895674356107534287685)
      let _presence_slot := keccak256(0, 64)
      mstore(0, key)
      mstore(32, _presence_slot)
      result := keccak256(0, 64)
    }
    function __proof_forge_map_write(slot, key, value) {
      let _slot := __proof_forge_map_slot(slot, key)
      sstore(_slot, value)
      sstore(__proof_forge_map_presence_slot(slot, key), 1)
    }
    function __pf_checked_add(a, b) -> r {
      if gt(a, sub(115792089237316195423570985008687907853269984665640564039457584007913129639935, b)) {
        revert(0, 0)
      }
      r := add(a, b)
    }
    function __pf_checked_sub(a, b) -> r {
      if gt(b, a) {
        revert(0, 0)
      }
      r := sub(a, b)
    }
    function __pf_checked_mul(a, b) -> r {
      if iszero(a) {
        r := 0
        leave
      }
      if gt(a, div(115792089237316195423570985008687907853269984665640564039457584007913129639935, b)) {
        revert(0, 0)
      }
      r := mul(a, b)
    }
    function __proof_forge_crosscall_1(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := call(gas(), target, 0, 0, 36, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_3(target, selector, arg0, arg1, arg2) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      mstore(68, arg2)
      let _success := call(gas(), target, 0, 0, 100, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_2(target, selector, arg0, arg1) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      let _success := call(gas(), target, 0, 0, 68, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
  }
}
