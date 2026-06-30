object "AbiScalarProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x7f97495c {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(36), 4294967295) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      let _r := f_AbiScalarProbe_mix(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc32c70b1 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_AbiScalarProbe_same(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_AbiScalarProbe_mix(base, delta, flag) -> result {
      result := add(add(base, delta), flag)
    }
    function f_AbiScalarProbe_same(left, right) -> result {
      result := eq(left, right)
    }
  }
}
