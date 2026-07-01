object "EvmStructValueProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x77bd09b1 {
      let _r := f_EvmStructValueProbe_local_sum()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x25e7fc3e {
      let _r := f_EvmStructValueProbe_direct_literal_field()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x7c95ba13 {
      let _r := f_EvmStructValueProbe_bool_guard()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xa13f4ee0 {
      let _r := f_EvmStructValueProbe_u32_pick()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x211a2fc4 {
      let _r := f_EvmStructValueProbe_hash_pick()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xc7096012 {
      let _r := f_EvmStructValueProbe_mutable_point_update()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xb18f76a4 {
      let _r := f_EvmStructValueProbe_mutable_mixed_fields()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmStructValueProbe_local_sum() -> result {
      let __proof_forge_struct_p_x := 7
      let __proof_forge_struct_p_y := 13
      let head := __proof_forge_struct_p_x
      result := add(head, __proof_forge_struct_p_y)
    }
    function f_EvmStructValueProbe_direct_literal_field() -> result {
      result := 6
    }
    function f_EvmStructValueProbe_bool_guard() -> result {
      let __proof_forge_struct_flags_enabled := 1
      let __proof_forge_struct_flags_archived := 0
      if iszero(__proof_forge_struct_flags_enabled) {
        revert(0, 0)
      }
      result := __proof_forge_struct_flags_archived
    }
    function f_EvmStructValueProbe_u32_pick() -> result {
      let __proof_forge_struct_small_a := 3
      let __proof_forge_struct_small_b := 5
      result := __proof_forge_struct_small_b
    }
    function f_EvmStructValueProbe_hash_pick() -> result {
      let __proof_forge_struct_roots_root := 6277101735386680764516354157049543343084444891548699590660
      let __proof_forge_struct_roots_next := 31385508676933403821220641317563962861421152075426748694536
      result := __proof_forge_struct_roots_root
    }
    function f_EvmStructValueProbe_mutable_point_update() -> result {
      let __proof_forge_struct_p_x := 7
      let __proof_forge_struct_p_y := 13
      __proof_forge_struct_p_x := 9
      __proof_forge_struct_p_y := add(__proof_forge_struct_p_y, 5)
      result := add(__proof_forge_struct_p_x, __proof_forge_struct_p_y)
    }
    function f_EvmStructValueProbe_mutable_mixed_fields() -> result {
      let __proof_forge_struct_flags_enabled := 0
      let __proof_forge_struct_flags_archived := 0
      __proof_forge_struct_flags_enabled := 1
      if iszero(__proof_forge_struct_flags_enabled) {
        revert(0, 0)
      }
      let __proof_forge_struct_small_a := 3
      let __proof_forge_struct_small_b := 5
      __proof_forge_struct_small_b := 9
      let __proof_forge_struct_roots_root := 6277101735386680764516354157049543343084444891548699590660
      let __proof_forge_struct_roots_next := 31385508676933403821220641317563962861421152075426748694536
      __proof_forge_struct_roots_next := 56493915618480126877924928478078382379757859259304797798412
      if iszero(eq(__proof_forge_struct_roots_next, 56493915618480126877924928478078382379757859259304797798412)) {
        revert(0, 0)
      }
      result := add(__proof_forge_struct_flags_enabled, __proof_forge_struct_small_b)
    }
  }
}
