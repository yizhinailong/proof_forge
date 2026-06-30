object "EvmMapProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x3bb39394 {
      let _r := f_EvmMapProbe_map_lifecycle()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x541be503 {
      let _r := f_EvmMapProbe_get_seed_balance()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x68eb1eef {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmMapProbe_read_balance(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xe1de6ac8 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      let _r := f_EvmMapProbe_upsert_balance(calldataload(4), calldataload(36))
      mstore(0, _r)
      return(0, 32)
    }
    case 0xb41d1f5c {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_EvmMapProbe_set_balance(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0x84c21205 {
      let _r := f_EvmMapProbe_path_lifecycle()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_EvmMapProbe_map_lifecycle() -> result {
      sstore(0, 111)
      sstore(2, 222)
      let old0 := __proof_forge_map_set_return(1, 1001, 11)
      if iszero(eq(old0, 0)) {
        revert(0, 0)
      }
      if iszero(eq(sload(__proof_forge_map_slot(1, 1001)), 11)) {
        revert(0, 0)
      }
      let old1 := __proof_forge_map_set_return(1, 1001, 55)
      if iszero(eq(old1, 11)) {
        revert(0, 0)
      }
      result := sload(__proof_forge_map_slot(1, 1001))
    }
    function f_EvmMapProbe_get_seed_balance() -> result {
      result := sload(__proof_forge_map_slot(1, 1001))
    }
    function f_EvmMapProbe_read_balance(key) -> result {
      result := sload(__proof_forge_map_slot(1, key))
    }
    function f_EvmMapProbe_upsert_balance(key, value) -> result {
      result := __proof_forge_map_set_return(1, key, value)
    }
    function f_EvmMapProbe_set_balance(key, value) {
      __proof_forge_map_write(1, key, value)
    }
    function f_EvmMapProbe_path_lifecycle() -> result {
      __proof_forge_map_write(1, 2002, 77)
      result := sload(__proof_forge_map_slot(1, 2002))
    }
    function __proof_forge_map_slot(slot, key) -> result {
      mstore(0, key)
      mstore(32, slot)
      result := keccak256(0, 64)
    }
    function __proof_forge_map_write(slot, key, value) {
      let _slot := __proof_forge_map_slot(slot, key)
      sstore(_slot, value)
    }
    function __proof_forge_map_set_return(slot, key, value) -> old {
      let _slot := __proof_forge_map_slot(slot, key)
      old := sload(_slot)
      sstore(_slot, value)
    }
  }
}
