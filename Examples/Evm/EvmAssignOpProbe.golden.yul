object "EvmAssignOpProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x72250d96 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmAssignOpProbe_compound_assignment(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x1508c8ff {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      if gt(calldataload(4), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmAssignOpProbe_compound_u32(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmAssignOpProbe_compound_assignment(seed) -> result {
      let total := seed
      total := add(total, 7)
      total := sub(total, 2)
      total := mul(total, 3)
      total := div(total, 5)
      total := mod(total, 11)
      total := or(total, 8)
      total := and(total, 14)
      total := xor(total, 3)
      total := shl(1, total)
      total := shr(1, total)
      sstore(0, total)
      sstore(0, add(sload(0), 5))
      sstore(0, sub(sload(0), 1))
      sstore(0, mul(sload(0), 2))
      sstore(0, div(sload(0), 3))
      sstore(0, mod(sload(0), 13))
      sstore(0, or(sload(0), 16))
      sstore(0, and(sload(0), 31))
      sstore(0, xor(sload(0), 7))
      sstore(0, shl(2, sload(0)))
      sstore(0, shr(1, sload(0)))
      result := sload(0)
    }
    function f_EvmAssignOpProbe_compound_u32(seed) -> result {
      let word := seed
      word := add(word, 3)
      word := sub(word, 1)
      word := mul(word, 2)
      word := div(word, 11)
      word := mod(word, 3)
      word := or(word, 8)
      word := and(word, 10)
      word := xor(word, 3)
      word := shl(1, word)
      word := shr(1, word)
      result := word
    }
  }
}
