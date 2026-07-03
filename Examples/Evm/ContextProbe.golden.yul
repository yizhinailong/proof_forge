object "ContextProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x14a70e97 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_ContextProbe_sum_context(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xf0eba40f {
      let _r := f_ContextProbe_native_value()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_ContextProbe_sum_context(a, b) -> result {
      result := __pf_checked_add(__pf_checked_add(a, b), __pf_checked_add(caller(), __pf_checked_add(address(), number())))
    }
    function f_ContextProbe_native_value() -> result {
      result := callvalue()
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
