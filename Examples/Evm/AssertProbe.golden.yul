object "AssertProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0xfe24a759 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_AssertProbe_checked_sum(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_AssertProbe_checked_sum(a, b) -> result {
      let total := add(a, b)
      let ok := 1
      if iszero(ok) {
        revert(0, 0)
      }
      if iszero(eq(total, 12)) {
        revert(0, 0)
      }
      result := total
    }
  }
}
