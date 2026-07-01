object "EvmLoopProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0xc4eff2de {
      let _r := f_EvmLoopProbe_count_to_three()
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
  }
}
