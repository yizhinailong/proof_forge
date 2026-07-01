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
    case 0xd49690a6 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_matrix(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0xcabe3922 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_pair_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x00746b10 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_array_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x25c0a43d {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_matrix_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x031396d6 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_pair_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0x7a45fdce {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      if gt(calldataload(132), 1) {
        revert(0, 0)
      }
      if gt(calldataload(164), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_pair_array_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
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
    case 0x885cf3f5 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_value_pair_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x01ff40fb {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_value_pair(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x2bedc30a {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_value_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x4b634dd4 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_value_matrix(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0x63ec1609 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_value_pair_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0x27c33745 {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      if gt(calldataload(132), 1) {
        revert(0, 0)
      }
      if gt(calldataload(164), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_value_pair_array_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x635d3715 {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_value_matrix_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
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
    case 0xd1b1bf68 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_pair_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x2236e75b {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_static_pair(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0xb1d5165b {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_static_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x202850f3 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_static_matrix(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0xe0315e4e {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_static_pair_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0x1b46265d {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      if gt(calldataload(132), 1) {
        revert(0, 0)
      }
      if gt(calldataload(164), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_pair_array_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x5ef5b6fb {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_static_matrix_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
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
    case 0x8283d1d1 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_pair_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x41e8bd85 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_delegate_pair(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0x52579065 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1 := f_EvmCrosscallProbe_call_remote_delegate_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      return(0, 64)
    }
    case 0xb8c58c92 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_delegate_matrix(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0xa26d8a3c {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r0, _r1, _r2, _r3 := f_EvmCrosscallProbe_call_remote_delegate_pair_array(calldataload(4), calldataload(36))
      mstore(0, _r0)
      mstore(32, _r1)
      mstore(64, _r2)
      mstore(96, _r3)
      return(0, 128)
    }
    case 0x73049a39 {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      if gt(calldataload(68), 1) {
        revert(0, 0)
      }
      if gt(calldataload(100), 4294967295) {
        revert(0, 0)
      }
      if gt(calldataload(132), 1) {
        revert(0, 0)
      }
      if gt(calldataload(164), 4294967295) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_pair_array_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x08edf8ea {
      if lt(calldatasize(), 196) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_call_remote_delegate_matrix_arg(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132), calldataload(164))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc9bc2909 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_deploy_create(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x70b22efb {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmCrosscallProbe_deploy_create2(calldataload(4), calldataload(36))
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
    function f_EvmCrosscallProbe_call_remote_matrix(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_0_abi_u64_u64_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_pair_arg(target, method, flag, small) -> result {
      let __proof_forge_struct_pair_flag := flag
      let __proof_forge_struct_pair_small := small
      result := __proof_forge_crosscall_2_bool(target, method, __proof_forge_struct_pair_flag, __proof_forge_struct_pair_small)
    }
    function f_EvmCrosscallProbe_call_remote_array_arg(target, method, x, y) -> result {
      let __proof_forge_array_values_0 := x
      let __proof_forge_array_values_1 := y
      result := __proof_forge_crosscall_2(target, method, __proof_forge_array_values_0, __proof_forge_array_values_1)
    }
    function f_EvmCrosscallProbe_call_remote_matrix_arg(target, method, a, b, c, d) -> result {
      result := __proof_forge_crosscall_4(target, method, a, b, c, d)
    }
    function f_EvmCrosscallProbe_call_remote_pair_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_0_abi_bool_u32_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_pair_array_arg(target, method, flag0, small0, flag1, small1) -> result {
      let __proof_forge_array_struct_pairs_0_flag := flag0
      let __proof_forge_array_struct_pairs_0_small := small0
      let __proof_forge_array_struct_pairs_1_flag := flag1
      let __proof_forge_array_struct_pairs_1_small := small1
      result := __proof_forge_crosscall_4(target, method, __proof_forge_array_struct_pairs_0_flag, __proof_forge_array_struct_pairs_0_small, __proof_forge_array_struct_pairs_1_flag, __proof_forge_array_struct_pairs_1_small)
    }
    function f_EvmCrosscallProbe_call_remote_value(target, method) -> result {
      result := __proof_forge_crosscall_value_0(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_value_pair_arg(target, method, flag, small) -> result {
      let __proof_forge_struct_pair_flag := flag
      let __proof_forge_struct_pair_small := small
      result := __proof_forge_crosscall_value_2(target, method, callvalue(), __proof_forge_struct_pair_flag, __proof_forge_struct_pair_small)
    }
    function f_EvmCrosscallProbe_call_remote_value_pair(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_value_0_abi_bool_u32(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_value_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_value_0_abi_u64_u64(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_value_matrix(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_value_0_abi_u64_u64_u64_u64(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_value_pair_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_value_0_abi_bool_u32_bool_u32(target, method, callvalue())
    }
    function f_EvmCrosscallProbe_call_remote_value_pair_array_arg(target, method, flag0, small0, flag1, small1) -> result {
      let __proof_forge_array_struct_pairs_0_flag := flag0
      let __proof_forge_array_struct_pairs_0_small := small0
      let __proof_forge_array_struct_pairs_1_flag := flag1
      let __proof_forge_array_struct_pairs_1_small := small1
      result := __proof_forge_crosscall_value_4(target, method, callvalue(), __proof_forge_array_struct_pairs_0_flag, __proof_forge_array_struct_pairs_0_small, __proof_forge_array_struct_pairs_1_flag, __proof_forge_array_struct_pairs_1_small)
    }
    function f_EvmCrosscallProbe_call_remote_value_matrix_arg(target, method, a, b, c, d) -> result {
      result := __proof_forge_crosscall_value_4(target, method, callvalue(), a, b, c, d)
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
    function f_EvmCrosscallProbe_call_remote_static_pair_arg(target, method, flag, small) -> result {
      let __proof_forge_struct_pair_flag := flag
      let __proof_forge_struct_pair_small := small
      result := __proof_forge_crosscall_static_2_u32(target, method, __proof_forge_struct_pair_flag, __proof_forge_struct_pair_small)
    }
    function f_EvmCrosscallProbe_call_remote_static_pair(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_static_0_abi_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_static_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_static_0_abi_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_static_matrix(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_static_0_abi_u64_u64_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_static_pair_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_static_0_abi_bool_u32_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_static_pair_array_arg(target, method, flag0, small0, flag1, small1) -> result {
      let __proof_forge_array_struct_pairs_0_flag := flag0
      let __proof_forge_array_struct_pairs_0_small := small0
      let __proof_forge_array_struct_pairs_1_flag := flag1
      let __proof_forge_array_struct_pairs_1_small := small1
      result := __proof_forge_crosscall_static_4(target, method, __proof_forge_array_struct_pairs_0_flag, __proof_forge_array_struct_pairs_0_small, __proof_forge_array_struct_pairs_1_flag, __proof_forge_array_struct_pairs_1_small)
    }
    function f_EvmCrosscallProbe_call_remote_static_matrix_arg(target, method, a, b, c, d) -> result {
      result := __proof_forge_crosscall_static_4(target, method, a, b, c, d)
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
    function f_EvmCrosscallProbe_call_remote_delegate_pair_arg(target, method, flag, small) -> result {
      let __proof_forge_struct_pair_flag := flag
      let __proof_forge_struct_pair_small := small
      result := __proof_forge_crosscall_delegate_2_u32(target, method, __proof_forge_struct_pair_flag, __proof_forge_struct_pair_small)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_pair(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_delegate_0_abi_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1 {
      __proof_forge_return_0, __proof_forge_return_1 := __proof_forge_crosscall_delegate_0_abi_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_matrix(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_delegate_0_abi_u64_u64_u64_u64(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_pair_array(target, method) -> __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 {
      __proof_forge_return_0, __proof_forge_return_1, __proof_forge_return_2, __proof_forge_return_3 := __proof_forge_crosscall_delegate_0_abi_bool_u32_bool_u32(target, method)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_pair_array_arg(target, method, flag0, small0, flag1, small1) -> result {
      let __proof_forge_array_struct_pairs_0_flag := flag0
      let __proof_forge_array_struct_pairs_0_small := small0
      let __proof_forge_array_struct_pairs_1_flag := flag1
      let __proof_forge_array_struct_pairs_1_small := small1
      result := __proof_forge_crosscall_delegate_4(target, method, __proof_forge_array_struct_pairs_0_flag, __proof_forge_array_struct_pairs_0_small, __proof_forge_array_struct_pairs_1_flag, __proof_forge_array_struct_pairs_1_small)
    }
    function f_EvmCrosscallProbe_call_remote_delegate_matrix_arg(target, method, a, b, c, d) -> result {
      result := __proof_forge_crosscall_delegate_4(target, method, a, b, c, d)
    }
    function f_EvmCrosscallProbe_deploy_create(value) -> result {
      result := __proof_forge_create_69602a60005260206000f3600052600a6016f3(value)
    }
    function f_EvmCrosscallProbe_deploy_create2(value, salt) -> result {
      result := __proof_forge_create2_69602a60005260206000f3600052600a6016f3(value, salt)
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
    function __proof_forge_crosscall_0_abi_u64_u64_u64_u64(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, 0, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
    }
    function __proof_forge_crosscall_2_bool(target, selector, arg0, arg1) -> result {
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
      if gt(result, 1) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_4(target, selector, arg0, arg1, arg2, arg3) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      mstore(68, arg2)
      mstore(100, arg3)
      let _success := call(gas(), target, 0, 0, 132, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_0_abi_bool_u32_bool_u32(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, 0, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
      if gt(result0, 1) {
        revert(0, 0)
      }
      if gt(result1, 4294967295) {
        revert(0, 0)
      }
      if gt(result2, 1) {
        revert(0, 0)
      }
      if gt(result3, 4294967295) {
        revert(0, 0)
      }
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
    function __proof_forge_crosscall_value_2(target, selector, call_value, arg0, arg1) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      let _success := call(gas(), target, call_value, 0, 68, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_crosscall_value_0_abi_bool_u32(target, selector, call_value) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, call_value, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_value_0_abi_u64_u64(target, selector, call_value) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, call_value, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_value_0_abi_u64_u64_u64_u64(target, selector, call_value) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, call_value, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
    }
    function __proof_forge_crosscall_value_0_abi_bool_u32_bool_u32(target, selector, call_value) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := call(gas(), target, call_value, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
      if gt(result0, 1) {
        revert(0, 0)
      }
      if gt(result1, 4294967295) {
        revert(0, 0)
      }
      if gt(result2, 1) {
        revert(0, 0)
      }
      if gt(result3, 4294967295) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_value_4(target, selector, call_value, arg0, arg1, arg2, arg3) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      mstore(68, arg2)
      mstore(100, arg3)
      let _success := call(gas(), target, call_value, 0, 132, 0, 32)
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
    function __proof_forge_crosscall_static_2_u32(target, selector, arg0, arg1) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      let _success := staticcall(gas(), target, 0, 68, 0, 32)
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
    function __proof_forge_crosscall_static_0_abi_bool_u32(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := staticcall(gas(), target, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_static_0_abi_u64_u64(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := staticcall(gas(), target, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_static_0_abi_u64_u64_u64_u64(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := staticcall(gas(), target, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
    }
    function __proof_forge_crosscall_static_0_abi_bool_u32_bool_u32(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := staticcall(gas(), target, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
      if gt(result0, 1) {
        revert(0, 0)
      }
      if gt(result1, 4294967295) {
        revert(0, 0)
      }
      if gt(result2, 1) {
        revert(0, 0)
      }
      if gt(result3, 4294967295) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_static_4(target, selector, arg0, arg1, arg2, arg3) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      mstore(68, arg2)
      mstore(100, arg3)
      let _success := staticcall(gas(), target, 0, 132, 0, 32)
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
    function __proof_forge_crosscall_delegate_2_u32(target, selector, arg0, arg1) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      let _success := delegatecall(gas(), target, 0, 68, 0, 32)
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
    function __proof_forge_crosscall_delegate_0_abi_bool_u32(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := delegatecall(gas(), target, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_delegate_0_abi_u64_u64(target, selector) -> result0, result1 {
      mstore(0, shl(224, selector))
      let _success := delegatecall(gas(), target, 0, 4, 0, 64)
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
    function __proof_forge_crosscall_delegate_0_abi_u64_u64_u64_u64(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := delegatecall(gas(), target, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
    }
    function __proof_forge_crosscall_delegate_0_abi_bool_u32_bool_u32(target, selector) -> result0, result1, result2, result3 {
      mstore(0, shl(224, selector))
      let _success := delegatecall(gas(), target, 0, 4, 0, 128)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 128) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 128)
      result0 := mload(0)
      result1 := mload(32)
      result2 := mload(64)
      result3 := mload(96)
      if gt(result0, 1) {
        revert(0, 0)
      }
      if gt(result1, 4294967295) {
        revert(0, 0)
      }
      if gt(result2, 1) {
        revert(0, 0)
      }
      if gt(result3, 4294967295) {
        revert(0, 0)
      }
    }
    function __proof_forge_crosscall_delegate_4(target, selector, arg0, arg1, arg2, arg3) -> result {
      mstore(0, shl(224, selector))
      mstore(4, arg0)
      mstore(36, arg1)
      mstore(68, arg2)
      mstore(100, arg3)
      let _success := delegatecall(gas(), target, 0, 132, 0, 32)
      if iszero(_success) {
        revert(0, 0)
      }
      if lt(returndatasize(), 32) {
        revert(0, 0)
      }
      returndatacopy(0, 0, 32)
      result := mload(0)
    }
    function __proof_forge_create_69602a60005260206000f3600052600a6016f3(call_value) -> result {
      mstore(0, 0x69602a60005260206000f3600052600a6016f300000000000000000000000000)
      result := create(call_value, 0, 19)
      if iszero(result) {
        revert(0, 0)
      }
    }
    function __proof_forge_create2_69602a60005260206000f3600052600a6016f3(call_value, salt) -> result {
      mstore(0, 0x69602a60005260206000f3600052600a6016f300000000000000000000000000)
      result := create2(call_value, 0, 19, salt)
      if iszero(result) {
        revert(0, 0)
      }
    }
  }
}
