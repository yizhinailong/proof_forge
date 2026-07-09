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
      total := __pf_checked_add(total, 7)
      let matched := 0
      matched := eq(total, 12)
      if iszero(matched) {
        revert(0, 0)
      }
      result := total
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
