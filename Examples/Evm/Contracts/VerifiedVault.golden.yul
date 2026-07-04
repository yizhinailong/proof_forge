object "VerifiedVault" {
  code {
    switch shr(224, calldataload(0))
    case 0xe1c7392a {
      f_VerifiedVault_init()
      return(0, 0)
    }
    case 0xd0e30db0 {
      f_VerifiedVault_deposit()
      return(0, 0)
    }
    case 0x2e1a7d4d {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      f_VerifiedVault_withdraw(calldataload(4))
      return(0, 0)
    }
    case 0x75172a8b {
      let _r := f_VerifiedVault_reserves()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x3a98ef39 {
      let _r := f_VerifiedVault_totalShares()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x9cc7f708 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_VerifiedVault_balanceOf(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x893d20e8 {
      let _r := f_VerifiedVault_getOwner()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_VerifiedVault_init() {
      if iszero(eq(sload(1), 0)) {
        revert(0, 0)
      }
      sstore(0, caller())
      sstore(1, 1)
      sstore(2, 0)
      sstore(3, 0)
    }
    function f_VerifiedVault_deposit() {
      if iszero(iszero(eq(sload(1), 0))) {
        revert(0, 0)
      }
      let depositor := caller()
      let amount := callvalue()
      if iszero(iszero(eq(amount, 0))) {
        revert(0, 0)
      }
      let curReserves := sload(2)
      sstore(2, __pf_checked_add(curReserves, amount))
      let curShares := sload(3)
      sstore(3, __pf_checked_add(curShares, amount))
      let bal := sload(__proof_forge_map_slot(4, depositor))
      __proof_forge_map_write(4, depositor, __pf_checked_add(bal, amount))
    }
    function f_VerifiedVault_withdraw(amount) {
      if iszero(iszero(eq(sload(1), 0))) {
        revert(0, 0)
      }
      if iszero(eq(sload(5), 0)) {
        revert(0, 0)
      }
      sstore(5, 1)
      let withdrawer := caller()
      let bal := sload(__proof_forge_map_slot(4, withdrawer))
      if iszero(iszero(lt(bal, amount))) {
        revert(0, 0)
      }
      let curReserves := sload(2)
      if iszero(iszero(lt(curReserves, amount))) {
        revert(0, 0)
      }
      let curShares := sload(3)
      if iszero(iszero(lt(curShares, amount))) {
        revert(0, 0)
      }
      sstore(2, __pf_checked_sub(curReserves, amount))
      sstore(3, __pf_checked_sub(curShares, amount))
      __proof_forge_map_write(4, withdrawer, __pf_checked_sub(bal, amount))
      let _sent := __proof_forge_native_transfer(withdrawer, amount)
      sstore(5, 0)
    }
    function f_VerifiedVault_reserves() -> result {
      result := sload(2)
    }
    function f_VerifiedVault_totalShares() -> result {
      result := sload(3)
    }
    function f_VerifiedVault_balanceOf(depositor) -> result {
      result := sload(__proof_forge_map_slot(4, depositor))
    }
    function f_VerifiedVault_getOwner() -> result {
      result := sload(0)
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
    function __proof_forge_native_transfer(target, call_value) -> result {
      let _success := call(gas(), target, call_value, 0, 0, 0, 0)
      if iszero(_success) {
        revert(0, 0)
      }
      result := 0
    }
  }
}
