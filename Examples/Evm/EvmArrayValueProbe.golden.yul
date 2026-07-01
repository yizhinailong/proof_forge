object "EvmArrayValueProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x77bd09b1 {
      let _r := f_EvmArrayValueProbe_local_sum()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x7389a736 {
      let _r := f_EvmArrayValueProbe_direct_literal_index()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x7c95ba13 {
      let _r := f_EvmArrayValueProbe_bool_guard()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xa13f4ee0 {
      let _r := f_EvmArrayValueProbe_u32_pick()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x211a2fc4 {
      let _r := f_EvmArrayValueProbe_hash_pick()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0cde63a1 {
      let _r := f_EvmArrayValueProbe_mutable_update()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x70d82dc9 {
      let _r := f_EvmArrayValueProbe_mutable_mixed()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x17e4f54c {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmArrayValueProbe_dynamic_pick(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xf45e18ed {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmArrayValueProbe_dynamic_update(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmArrayValueProbe_local_sum() -> result {
      let __proof_forge_array_xs_0 := 7
      let __proof_forge_array_xs_1 := 11
      let __proof_forge_array_xs_2 := 13
      let head := __proof_forge_array_xs_0
      result := add(head, __proof_forge_array_xs_2)
    }
    function f_EvmArrayValueProbe_direct_literal_index() -> result {
      result := 6
    }
    function f_EvmArrayValueProbe_bool_guard() -> result {
      let __proof_forge_array_flags_0 := 0
      let __proof_forge_array_flags_1 := 1
      if iszero(__proof_forge_array_flags_1) {
        revert(0, 0)
      }
      result := __proof_forge_array_flags_0
    }
    function f_EvmArrayValueProbe_u32_pick() -> result {
      let __proof_forge_array_smalls_0 := 3
      let __proof_forge_array_smalls_1 := 5
      result := __proof_forge_array_smalls_1
    }
    function f_EvmArrayValueProbe_hash_pick() -> result {
      let __proof_forge_array_roots_0 := 6277101735386680764516354157049543343084444891548699590660
      let __proof_forge_array_roots_1 := 31385508676933403821220641317563962861421152075426748694536
      result := __proof_forge_array_roots_0
    }
    function f_EvmArrayValueProbe_mutable_update() -> result {
      let __proof_forge_array_xs_0 := 7
      let __proof_forge_array_xs_1 := 11
      let __proof_forge_array_xs_2 := 13
      __proof_forge_array_xs_1 := 19
      __proof_forge_array_xs_2 := add(__proof_forge_array_xs_2, 5)
      result := add(__proof_forge_array_xs_1, __proof_forge_array_xs_2)
    }
    function f_EvmArrayValueProbe_mutable_mixed() -> result {
      let __proof_forge_array_flags_0 := 0
      let __proof_forge_array_flags_1 := 0
      __proof_forge_array_flags_0 := 1
      if iszero(__proof_forge_array_flags_0) {
        revert(0, 0)
      }
      let __proof_forge_array_smalls_0 := 3
      let __proof_forge_array_smalls_1 := 5
      __proof_forge_array_smalls_1 := 9
      let __proof_forge_array_roots_0 := 6277101735386680764516354157049543343084444891548699590660
      let __proof_forge_array_roots_1 := 31385508676933403821220641317563962861421152075426748694536
      __proof_forge_array_roots_1 := 56493915618480126877924928478078382379757859259304797798412
      if iszero(eq(__proof_forge_array_roots_1, 56493915618480126877924928478078382379757859259304797798412)) {
        revert(0, 0)
      }
      result := add(__proof_forge_array_flags_0, __proof_forge_array_smalls_1)
    }
    function f_EvmArrayValueProbe_dynamic_pick(idx) -> result {
      let __proof_forge_array_xs_0 := 7
      let __proof_forge_array_xs_1 := 11
      let __proof_forge_array_xs_2 := 13
      result := add(__proof_forge_local_array_get_3(idx, __proof_forge_array_xs_0, __proof_forge_array_xs_1, __proof_forge_array_xs_2), __proof_forge_local_array_get_3(idx, 4, 6, 8))
    }
    function f_EvmArrayValueProbe_dynamic_update(idx) -> result {
      let __proof_forge_array_xs_0 := 7
      let __proof_forge_array_xs_1 := 11
      let __proof_forge_array_xs_2 := 13
      {
        let __proof_forge_array_index := idx
        let __proof_forge_array_value := 20
        switch __proof_forge_array_index
        case 0 {
          __proof_forge_array_xs_0 := __proof_forge_array_value
        }
        case 1 {
          __proof_forge_array_xs_1 := __proof_forge_array_value
        }
        case 2 {
          __proof_forge_array_xs_2 := __proof_forge_array_value
        }
        default {
          revert(0, 0)
        }
      }
      {
        let __proof_forge_array_index := idx
        let __proof_forge_array_value := 3
        switch __proof_forge_array_index
        case 0 {
          __proof_forge_array_xs_0 := add(__proof_forge_array_xs_0, __proof_forge_array_value)
        }
        case 1 {
          __proof_forge_array_xs_1 := add(__proof_forge_array_xs_1, __proof_forge_array_value)
        }
        case 2 {
          __proof_forge_array_xs_2 := add(__proof_forge_array_xs_2, __proof_forge_array_value)
        }
        default {
          revert(0, 0)
        }
      }
      result := __proof_forge_local_array_get_3(idx, __proof_forge_array_xs_0, __proof_forge_array_xs_1, __proof_forge_array_xs_2)
    }
    function __proof_forge_local_array_get_3(index, value_0, value_1, value_2) -> result {
      switch index
      case 0 {
        result := value_0
      }
      case 1 {
        result := value_1
      }
      case 2 {
        result := value_2
      }
      default {
        revert(0, 0)
      }
    }
  }
}
