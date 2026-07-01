object "EvmStructArrayValueProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x6dcefec0 {
      let _r := f_EvmStructArrayValueProbe_local_struct_array_sum()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x0601d7ac {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmStructArrayValueProbe_dynamic_struct_array_pick(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xbfa2eef8 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmStructArrayValueProbe_mutable_struct_array_update(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc8c9bc70 {
      let _r := f_EvmStructArrayValueProbe_static_struct_array_update()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x8c32c4da {
      let _r := f_EvmStructArrayValueProbe_mixed_struct_array_fields()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xcd4a0dc2 {
      let _r := f_EvmStructArrayValueProbe_whole_struct_array_assign()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xe5ea5747 {
      let _r := f_EvmStructArrayValueProbe_self_struct_array_assign()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmStructArrayValueProbe_local_struct_array_sum() -> result {
      let __proof_forge_array_struct_people_0_age := 10
      let __proof_forge_array_struct_people_0_score := 80
      let __proof_forge_array_struct_people_1_age := 20
      let __proof_forge_array_struct_people_1_score := 90
      result := add(__proof_forge_array_struct_people_0_age, __proof_forge_array_struct_people_1_score)
    }
    function f_EvmStructArrayValueProbe_dynamic_struct_array_pick(idx) -> result {
      let __proof_forge_array_struct_people_0_age := 10
      let __proof_forge_array_struct_people_0_score := 80
      let __proof_forge_array_struct_people_1_age := 20
      let __proof_forge_array_struct_people_1_score := 90
      result := add(__proof_forge_local_array_get_2(idx, __proof_forge_array_struct_people_0_age, __proof_forge_array_struct_people_1_age), __proof_forge_local_array_get_2(idx, __proof_forge_array_struct_people_0_score, __proof_forge_array_struct_people_1_score))
    }
    function f_EvmStructArrayValueProbe_mutable_struct_array_update(idx) -> result {
      let __proof_forge_array_struct_people_0_age := 10
      let __proof_forge_array_struct_people_0_score := 80
      let __proof_forge_array_struct_people_1_age := 20
      let __proof_forge_array_struct_people_1_score := 90
      {
        let __proof_forge_array_index := idx
        let __proof_forge_array_value := 30
        switch __proof_forge_array_index
        case 0 {
          __proof_forge_array_struct_people_0_age := __proof_forge_array_value
        }
        case 1 {
          __proof_forge_array_struct_people_1_age := __proof_forge_array_value
        }
        default {
          revert(0, 0)
        }
      }
      {
        let __proof_forge_array_index := idx
        let __proof_forge_array_value := 7
        switch __proof_forge_array_index
        case 0 {
          __proof_forge_array_struct_people_0_score := add(__proof_forge_array_struct_people_0_score, __proof_forge_array_value)
        }
        case 1 {
          __proof_forge_array_struct_people_1_score := add(__proof_forge_array_struct_people_1_score, __proof_forge_array_value)
        }
        default {
          revert(0, 0)
        }
      }
      result := add(__proof_forge_local_array_get_2(idx, __proof_forge_array_struct_people_0_age, __proof_forge_array_struct_people_1_age), __proof_forge_local_array_get_2(idx, __proof_forge_array_struct_people_0_score, __proof_forge_array_struct_people_1_score))
    }
    function f_EvmStructArrayValueProbe_static_struct_array_update() -> result {
      let __proof_forge_array_struct_people_0_age := 10
      let __proof_forge_array_struct_people_0_score := 80
      let __proof_forge_array_struct_people_1_age := 20
      let __proof_forge_array_struct_people_1_score := 90
      __proof_forge_array_struct_people_1_age := 33
      __proof_forge_array_struct_people_0_score := add(__proof_forge_array_struct_people_0_score, 5)
      result := add(__proof_forge_array_struct_people_0_score, __proof_forge_array_struct_people_1_age)
    }
    function f_EvmStructArrayValueProbe_mixed_struct_array_fields() -> result {
      let __proof_forge_array_struct_rows_0_enabled := 0
      let __proof_forge_array_struct_rows_0_small := 7
      let __proof_forge_array_struct_rows_0_root := 6277101735386680764516354157049543343084444891548699590660
      let __proof_forge_array_struct_rows_1_enabled := 1
      let __proof_forge_array_struct_rows_1_small := 9
      let __proof_forge_array_struct_rows_1_root := 31385508676933403821220641317563962861421152075426748694536
      __proof_forge_array_struct_rows_0_enabled := 1
      __proof_forge_array_struct_rows_1_small := 11
      __proof_forge_array_struct_rows_0_root := 56493915618480126877924928478078382379757859259304797798412
      if iszero(__proof_forge_array_struct_rows_0_enabled) {
        revert(0, 0)
      }
      if iszero(eq(__proof_forge_array_struct_rows_0_root, 56493915618480126877924928478078382379757859259304797798412)) {
        revert(0, 0)
      }
      result := add(__proof_forge_array_struct_rows_1_small, __proof_forge_array_struct_rows_0_enabled)
    }
    function f_EvmStructArrayValueProbe_whole_struct_array_assign() -> result {
      let __proof_forge_array_struct_people_0_age := 1
      let __proof_forge_array_struct_people_0_score := 2
      let __proof_forge_array_struct_people_1_age := 3
      let __proof_forge_array_struct_people_1_score := 4
      let __proof_forge_array_struct_next_0_age := 11
      let __proof_forge_array_struct_next_0_score := 13
      let __proof_forge_array_struct_next_1_age := 17
      let __proof_forge_array_struct_next_1_score := 19
      {
        let __proof_forge_assign_array_struct_people_0_age := __proof_forge_array_struct_next_0_age
        let __proof_forge_assign_array_struct_people_0_score := __proof_forge_array_struct_next_0_score
        let __proof_forge_assign_array_struct_people_1_age := __proof_forge_array_struct_next_1_age
        let __proof_forge_assign_array_struct_people_1_score := __proof_forge_array_struct_next_1_score
        __proof_forge_array_struct_people_0_age := __proof_forge_assign_array_struct_people_0_age
        __proof_forge_array_struct_people_0_score := __proof_forge_assign_array_struct_people_0_score
        __proof_forge_array_struct_people_1_age := __proof_forge_assign_array_struct_people_1_age
        __proof_forge_array_struct_people_1_score := __proof_forge_assign_array_struct_people_1_score
      }
      result := add(add(__proof_forge_array_struct_people_0_age, __proof_forge_array_struct_people_0_score), add(__proof_forge_array_struct_people_1_age, __proof_forge_array_struct_people_1_score))
    }
    function f_EvmStructArrayValueProbe_self_struct_array_assign() -> result {
      let __proof_forge_array_struct_people_0_age := 5
      let __proof_forge_array_struct_people_0_score := 7
      let __proof_forge_array_struct_people_1_age := 11
      let __proof_forge_array_struct_people_1_score := 13
      {
        let __proof_forge_assign_array_struct_people_0_age := __proof_forge_array_struct_people_1_age
        let __proof_forge_assign_array_struct_people_0_score := __proof_forge_array_struct_people_0_score
        let __proof_forge_assign_array_struct_people_1_age := __proof_forge_array_struct_people_0_age
        let __proof_forge_assign_array_struct_people_1_score := __proof_forge_array_struct_people_1_score
        __proof_forge_array_struct_people_0_age := __proof_forge_assign_array_struct_people_0_age
        __proof_forge_array_struct_people_0_score := __proof_forge_assign_array_struct_people_0_score
        __proof_forge_array_struct_people_1_age := __proof_forge_assign_array_struct_people_1_age
        __proof_forge_array_struct_people_1_score := __proof_forge_assign_array_struct_people_1_score
      }
      result := add(add(__proof_forge_array_struct_people_0_age, __proof_forge_array_struct_people_0_score), add(__proof_forge_array_struct_people_1_age, __proof_forge_array_struct_people_1_score))
    }
    function __proof_forge_local_array_get_2(index, value_0, value_1) -> result {
      switch index
      case 0 {
        result := value_0
      }
      case 1 {
        result := value_1
      }
      default {
        revert(0, 0)
      }
    }
  }
}
