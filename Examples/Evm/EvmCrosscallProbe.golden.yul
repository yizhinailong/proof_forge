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
    case 0x6a7b13b8 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_bool(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0f35944c {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_u32(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x6a5317aa {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_hash(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x365f4a44 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_value(calldataload(4), calldataload(36))
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
    function f_EvmCrosscallProbe_call_remote_bool(target, method, flag) -> result {
      result := __proof_forge_crosscall_1_bool(target, method, flag)
    }
    function f_EvmCrosscallProbe_call_remote_u32(target, method, x) -> result {
      result := __proof_forge_crosscall_1_u32(target, method, x)
    }
    function f_EvmCrosscallProbe_call_remote_hash(target, method, value) -> result {
      result := __proof_forge_crosscall_1_hash(target, method, value)
    }
    function f_EvmCrosscallProbe_call_remote_value(target, method) -> result {
      result := __proof_forge_crosscall_value_0(target, method, callvalue())
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
    function __proof_forge_crosscall_1_bool(target, selector, arg0) -> result {
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
      if gt(result, 1) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_1_u32(target, selector, arg0) -> result {
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
      if gt(result, 4294967295) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_1_hash(target, selector, arg0) -> result {
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
    function __proof_forge_crosscall_value_0(target, selector, call_value) -> result {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, call_value, 0, 4, 0, 32)
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
