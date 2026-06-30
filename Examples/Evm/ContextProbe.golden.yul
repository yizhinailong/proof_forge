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
    default {
      revert(0, 0)
    }
    function f_ContextProbe_sum_context(a, b) -> result {
      result := add(add(a, b), add(caller(), add(address(), number())))
    }
  }
}
