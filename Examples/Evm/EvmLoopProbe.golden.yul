object "EvmLoopProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0xc4eff2de {
      let _r := f_EvmLoopProbe_count_to_three()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xd9b42937 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      if gt(calldataload(4), 1) {
        revert(0, 0)
      }
      let _r := f_EvmLoopProbe_choose_with_early_return(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xd11c9505 {
      let _r := f_EvmLoopProbe_loop_early_return()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmLoopProbe_count_to_three() -> result {
      sstore(0, 0)
      for {
        let _i := 0
      } lt(_i, 3) {
        _i := add(_i, 1)
      } {
        let n := sload(0)
        sstore(0, add(n, 1))
      }
      result := sload(0)
    }
    function f_EvmLoopProbe_choose_with_early_return(flag) -> result {
      sstore(0, 0)
      switch flag
      case 0 {
        sstore(0, 22)
      }
      default {
        result := 11
        leave
      }
      sstore(0, 99)
      result := sload(0)
    }
    function f_EvmLoopProbe_loop_early_return() -> result {
      sstore(0, 100)
      for {
        let _i := 0
      } lt(_i, 3) {
        _i := add(_i, 1)
      } {
        result := _i
        leave
      }
    }
  }
}
