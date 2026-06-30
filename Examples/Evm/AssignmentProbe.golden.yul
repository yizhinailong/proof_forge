object "AssignmentProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x91a3e2ac {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_AssignmentProbe_reassignment(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_AssignmentProbe_reassignment(seed) -> result {
      let total := seed
      total := add(total, 7)
      let matched := 0
      matched := eq(total, 12)
      if iszero(matched) {
        revert(0, 0)
      }
      result := total
    }
  }
}
