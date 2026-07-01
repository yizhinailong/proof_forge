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
    case 0x47c6c9b7 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_pair(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x717d6851 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x365f4a44 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_value(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xd13203a8 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xae266f0a {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_bool(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xec8c40f9 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_u32(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x4e0edd3c {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_hash(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x427320b1 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x62e5114d {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_bool(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xe3abe276 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      if gt(calldataload(68), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_u32(calldataload(4), calldataload(36), calldataload(68))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x6a2c2006 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_hash(calldataload(4), calldataload(36), calldataload(68))
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
    function f_EvmCrosscallProbe_call_remote_pair(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_0_abi_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_0_abi_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_value(target, method) -> result {
      result := __proof_forge_crosscall_value_0(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_static(target, method) -> result {
      result := __proof_forge_crosscall_static_0(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_static_bool(target, method, flag) -> result {
      result := __proof_forge_crosscall_static_1_bool(target, method, flag)
    }
    function f_EvmCrosscallProbe_call_remote_static_u32(target, method, x) -> result {
      result := __proof_forge_crosscall_static_1_u32(target, method, x)
    }
    function f_EvmCrosscallProbe_call_remote_static_hash(target, method, value) -> result {
      result := __proof_forge_crosscall_static_1_hash(target, method, value)
    }
    function f_EvmCrosscallProbe_call_remote_delegate(target, method) -> result {
      result := __proof_forge_crosscall_delegate_0(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_bool(target, method, flag) -> result {
      result := __proof_forge_crosscall_delegate_1_bool(target, method, flag)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_u32(target, method, x) -> result {
      result := __proof_forge_crosscall_delegate_1_u32(target, method, x)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_hash(target, method, value) -> result {
      result := __proof_forge_crosscall_delegate_1_hash(target, method, value)
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
    function __proof_forge_crosscall_0_abi_bool_u32(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, 0, 0, 4, 0, 64)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 64) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 64)
      result0 := mload(0)
      result1 := mload(32)
      if gt(result0, 1) {
        revert(0, 0)
      }
      if gt(result1, 4294967295) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_0_abi_u64_u64(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, 0, 0, 4, 0, 64)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 64) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 64)
      result0 := mload(0)
      result1 := mload(32)
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
    function __proof_forge_crosscall_static_0(target, selector) -> result {
      mstore(0, shl(224, selector))
      let _success := staticcall(gas(), target, 0, 4, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_static_1_bool(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := staticcall(gas(), target, 0, 36, 0, 32)
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
    function __proof_forge_crosscall_static_1_u32(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := staticcall(gas(), target, 0, 36, 0, 32)
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
    function __proof_forge_crosscall_static_1_hash(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := staticcall(gas(), target, 0, 36, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_delegate_0(target, selector) -> result {
      mstore(0, shl(224, selector))
      let _success := delegatecall(gas(), target, 0, 4, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_delegate_1_bool(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := delegatecall(gas(), target, 0, 36, 0, 32)
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
    function __proof_forge_crosscall_delegate_1_u32(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := delegatecall(gas(), target, 0, 36, 0, 32)
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
    function __proof_forge_crosscall_delegate_1_hash(target, selector, arg0) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      let _success := delegatecall(gas(), target, 0, 36, 0, 32)
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
