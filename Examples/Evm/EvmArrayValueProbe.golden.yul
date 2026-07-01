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
  }
}
