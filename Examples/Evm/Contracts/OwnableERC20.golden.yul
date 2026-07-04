object "OwnableERC20" {
  code {
    switch shr(224, calldataload(0))
    case 0x8da5cb5b {
      let _r := f_OwnableERC20_owner()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xd23e8489 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      f_OwnableERC20_transferOwnership(calldataload(4))
      return(0, 0)
    }
    case 0x715018a6 {
      f_OwnableERC20_renounceOwnership()
      return(0, 0)
    }
    case 0x18160ddd {
      let _r := f_OwnableERC20_totalSupply()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x9cc7f708 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_OwnableERC20_balanceOf(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0cf79e0a {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_OwnableERC20_transfer(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0xcca16fa8 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_OwnableERC20_allowance(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x5d35a3d9 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_OwnableERC20_approve(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0x310ed7f0 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      f_OwnableERC20_transferFrom(calldataload(4), calldataload(36), calldataload(68))
      return(0, 0)
    }
    case 0x1b2ef1ca {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_OwnableERC20_mint(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0xb390c0ab {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_OwnableERC20_burn(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0xb7b0422d {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      f_OwnableERC20_init(calldataload(4))
      return(0, 0)
    }
    case 0xd47573d4 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_OwnableERC20_ownerMint(calldataload(4), calldataload(36))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_OwnableERC20_owner() -> result {
      result := sload(0)
    }
    function f_OwnableERC20_transferOwnership(newOwner) {
      if iszero(eq(caller(), sload(0))) {
        revert(0, 0)
      }
      if iszero(iszero(eq(newOwner, 0))) {
        revert(0, 0)
      }
      sstore(0, newOwner)
    }
    function f_OwnableERC20_renounceOwnership() {
      if iszero(eq(caller(), sload(0))) {
        revert(0, 0)
      }
      sstore(0, 0)
    }
    function f_OwnableERC20_totalSupply() -> result {
      result := sload(1)
    }
    function f_OwnableERC20_balanceOf(who) -> result {
      result := sload(__proof_forge_map_slot(2, who))
    }
    function f_OwnableERC20_transfer(recipient, amount) {
      if iszero(iszero(eq(recipient, 0))) {
        revert(0, 0)
      }
      let sender := caller()
      let srcBal := sload(__proof_forge_map_slot(2, sender))
      if iszero(iszero(lt(srcBal, amount))) {
        revert(0, 0)
      }
      __proof_forge_map_write(2, sender, __pf_checked_sub(srcBal, amount))
      let dstBal := sload(__proof_forge_map_slot(2, recipient))
      __proof_forge_map_write(2, recipient, __pf_checked_add(dstBal, amount))
    }
    function f_OwnableERC20_allowance(ownerAddr, spender) -> result {
      result := sload(__proof_forge_map_slot(__proof_forge_map_slot(3, ownerAddr), spender))
    }
    function f_OwnableERC20_approve(spender, amount) {
      let ownerAddr := caller()
      if iszero(iszero(eq(spender, 0))) {
        revert(0, 0)
      }
      {
        let _slot := __proof_forge_map_slot(__proof_forge_map_slot(3, ownerAddr), spender)
        let _presence_slot := __proof_forge_map_presence_slot(__proof_forge_map_slot(3, ownerAddr), spender)
        sstore(_slot, amount)
        sstore(_presence_slot, 1)
      }
    }
    function f_OwnableERC20_transferFrom(src, dst, amount) {
      let spender := caller()
      let current := sload(__proof_forge_map_slot(__proof_forge_map_slot(3, src), spender))
      if iszero(iszero(lt(current, amount))) {
        revert(0, 0)
      }
      {
        let _slot := __proof_forge_map_slot(__proof_forge_map_slot(3, src), spender)
        let _presence_slot := __proof_forge_map_presence_slot(__proof_forge_map_slot(3, src), spender)
        sstore(_slot, __pf_checked_sub(current, amount))
        sstore(_presence_slot, 1)
      }
      let srcBal := sload(__proof_forge_map_slot(2, src))
      if iszero(iszero(lt(srcBal, amount))) {
        revert(0, 0)
      }
      __proof_forge_map_write(2, src, __pf_checked_sub(srcBal, amount))
      let dstBal := sload(__proof_forge_map_slot(2, dst))
      __proof_forge_map_write(2, dst, __pf_checked_add(dstBal, amount))
    }
    function f_OwnableERC20_mint(who, amount) {
      if iszero(iszero(eq(who, 0))) {
        revert(0, 0)
      }
      let ts := sload(1)
      sstore(1, __pf_checked_add(ts, amount))
      let bal := sload(__proof_forge_map_slot(2, who))
      __proof_forge_map_write(2, who, __pf_checked_add(bal, amount))
    }
    function f_OwnableERC20_burn(who, amount) {
      if iszero(iszero(eq(who, 0))) {
        revert(0, 0)
      }
      let bal := sload(__proof_forge_map_slot(2, who))
      if iszero(iszero(lt(bal, amount))) {
        revert(0, 0)
      }
      __proof_forge_map_write(2, who, __pf_checked_sub(bal, amount))
      let ts := sload(1)
      sstore(1, __pf_checked_sub(ts, amount))
    }
    function f_OwnableERC20_init(supply) {
      if iszero(eq(sload(0), 0)) {
        revert(0, 0)
      }
      sstore(0, caller())
      sstore(1, supply)
      let who := caller()
      __proof_forge_map_write(2, who, supply)
    }
    function f_OwnableERC20_ownerMint(who, amount) {
      if iszero(eq(caller(), sload(0))) {
        revert(0, 0)
      }
      let ts := sload(1)
      sstore(1, __pf_checked_add(ts, amount))
      let bal := sload(__proof_forge_map_slot(2, who))
      __proof_forge_map_write(2, who, __pf_checked_add(bal, amount))
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
    function __proof_forge_map_set_return(slot, key, value) -> old {
      let _slot := __proof_forge_map_slot(slot, key)
      old := sload(_slot)
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
  }
}
