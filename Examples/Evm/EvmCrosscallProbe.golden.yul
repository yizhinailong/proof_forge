object "EvmCrosscallProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x0de1d044 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x7ec7d7f8 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote1(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xff5ce87f {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote2(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmCrosscallProbe_call_remote(target, method) -> result {
      result := __proof_forge_crosscall_0(target, method)
    }
    function f_EvmCrosscallProbe_call_remote1(target, method, x) -> result {
      result := __proof_forge_crosscall_1(target, method, x)
    }
    function f_EvmCrosscallProbe_call_remote2(target, method, x, y) -> result {
      result := __proof_forge_crosscall_2(target, method, x, y)
    }
    function __proof_forge_crosscall_0(target, selector) -> result {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, 0, 0, 4, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_1(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := call(gas(), target, 0, 0, 36, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_2(target, selector, arg0, arg1) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      let _success := call(gas(), target, 0, 0, 68, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
  }
}
