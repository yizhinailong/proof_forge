object "EvmStorageArrayProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0xe4684b67 {
      let _r := f_EvmStorageArrayProbe_storage_lifecycle()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xac35feee {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      let _r := f_EvmStorageArrayProbe_read_value(calldataload(4))
      mstore(0, _r)
      return(0, 32)
    }
    case 0x5a6fd3b0 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_EvmStorageArrayProbe_write_value(calldataload(4), calldataload(36))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_EvmStorageArrayProbe_storage_lifecycle() -> result {
      sstore(0, 111)
      sstore(4, 222)
      sstore(__proof_forge_array_slot(1, 3, 0), 7)
      sstore(__proof_forge_array_slot(1, 3, 1), 11)
      sstore(__proof_forge_array_slot(1, 3, 2), 13)
      result := add(add(sload(__proof_forge_array_slot(1, 3, 0)), sload(__proof_forge_array_slot(1, 3, 1))), sload(__proof_forge_array_slot(1, 3, 2)))
    }
    function f_EvmStorageArrayProbe_read_value(index) -> result {
      result := sload(__proof_forge_array_slot(1, 3, index))
    }
    function f_EvmStorageArrayProbe_write_value(index, value) {
      sstore(__proof_forge_array_slot(1, 3, index), value)
    }
    function __proof_forge_array_slot(slot, length, index) -> result {
      if iszero(lt(index, length)) {
        revert(0, 0)
      }
      result := add(slot, index)
    }
  }
}
