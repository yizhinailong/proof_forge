object "SimpleToken" {
  code {
    switch shr(224, calldataload(0))
    case 0xb7b0422d {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      f_SimpleToken_init(calldataload(4))
      return(0, 0)
    }
    case 0x893d20e8 {
      let _r := f_SimpleToken_getOwner()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x18160ddd {
      let _r := f_SimpleToken_totalSupply()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x9cc7f708 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_SimpleToken_balanceOf(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0cf79e0a {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_SimpleToken_transfer(calldataload(4), calldataload(36))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_SimpleToken_init(supply) {
      sstore(0, caller())
      sstore(1, supply)
      let who := caller()
      __proof_forge_map_write(2, who, supply)
    }
    function f_SimpleToken_getOwner() -> result {
      result := sload(0)
    }
    function f_SimpleToken_totalSupply() -> result {
      result := sload(1)
    }
    function f_SimpleToken_balanceOf(addr) -> result {
      result := sload(__proof_forge_map_slot(2, addr))
    }
    function f_SimpleToken_transfer(recipient, amount) {
      let sender := caller()
      let bal := sload(__proof_forge_map_slot(2, sender))
      if iszero(iszero(lt(bal, amount))) {
        revert(0, 0)
      }
      __proof_forge_map_write(2, sender, __pf_checked_sub(bal, amount))
      let recvBal := sload(__proof_forge_map_slot(2, recipient))
      __proof_forge_map_write(2, recipient, __pf_checked_add(recvBal, amount))
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
