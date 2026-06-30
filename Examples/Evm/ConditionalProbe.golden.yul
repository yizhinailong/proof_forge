object "ConditionalProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0xf3380744 {
      let _r := f_ConditionalProbe_conditional_lifecycle()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_ConditionalProbe_conditional_lifecycle() -> result {
      sstore(0, 0)
      switch eq(1, 1)
      case 0 {
        sstore(0, 99)
      }
      default {
        let seed := 4
        sstore(0, seed)
      }
      switch lt(sload(0), 2)
      case 0 {
        let next := add(sload(0), 6)
        sstore(0, next)
      }
      default {
        sstore(0, 100)
      }
      if iszero(eq(sload(0), 10)) {
        revert(0, 0)
      }
      result := sload(0)
    }
  }
}
