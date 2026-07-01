object "EventProbe" {
  code {
    switch shr(224, calldataload(0))
    case 0x2ae8cae3 {
      if lt(calldatasize(), 36) {
        revert(0, 0)
      }
      f_EventProbe_emit_value_event(calldataload(4))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_EventProbe_emit_value_event(value) {
      {
        mstore(0, 39071037697028742785112223803821455438864049692237600240117038234351465136128)
        let _topic0 := keccak256(0, 10)
        mstore(0, value)
        log1(0, 32, _topic0)
      }
    }
  }
}
