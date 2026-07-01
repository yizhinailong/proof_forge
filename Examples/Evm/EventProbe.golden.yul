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
    case 0xbc07d04f {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_EventProbe_emit_indexed_event(calldataload(4), calldataload(36))
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function f_EventProbe_emit_value_event(value) {
      {
        mstore(0, 39071037697028742785112238941195820511403663684262765307557390900479590924288)
        let _topic0 := keccak256(0, 18)
        mstore(0, value)
        log1(0, 32, _topic0)
      }
    }
    function f_EventProbe_emit_indexed_event(user, value) {
      {
        mstore(0, 33213884033972546292423408501581198898028345886020401664275624245368457265152)
        let _topic0 := keccak256(0, 27)
        let _indexed_topic0 := user
        mstore(0, value)
        log2(0, 32, _topic0, _indexed_topic0)
      }
    }
  }
}
