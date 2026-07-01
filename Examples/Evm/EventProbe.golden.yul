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
    case 0x35361bda {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_EventProbe_emit_pair_event(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0x393f7138 {
      if lt(calldatasize(), 68) {
        revert(0, 0)
      }
      f_EventProbe_emit_array_event(calldataload(4), calldataload(36))
      return(0, 0)
    }
    case 0x85611e74 {
      if lt(calldatasize(), 132) {
        revert(0, 0)
      }
      f_EventProbe_emit_pair_array_event(calldataload(4), calldataload(36), calldataload(68), calldataload(100))
      return(0, 0)
    }
    case 0xe027f054 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      f_EventProbe_emit_indexed_pair_event(calldataload(4), calldataload(36), calldataload(68))
      return(0, 0)
    }
    case 0xb7de5dd7 {
      if lt(calldatasize(), 100) {
        revert(0, 0)
      }
      f_EventProbe_emit_indexed_array_event(calldataload(4), calldataload(36), calldataload(68))
      return(0, 0)
    }
    case 0xc1375f82 {
      if lt(calldatasize(), 164) {
        revert(0, 0)
      }
      f_EventProbe_emit_indexed_pair_array_event(calldataload(4), calldataload(36), calldataload(68), calldataload(100), calldataload(132))
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
    function f_EventProbe_emit_pair_event(left, right) {
      let __proof_forge_struct_pair_left := left
      let __proof_forge_struct_pair_right := right
      {
        mstore(0, 36357139816060400917849370525218542085058024887522720989284665839002891321344)
        let _topic0 := keccak256(0, 26)
        mstore(0, __proof_forge_struct_pair_left)
        mstore(32, __proof_forge_struct_pair_right)
        log1(0, 64, _topic0)
      }
    }
    function f_EventProbe_emit_array_event(left, right) {
      let __proof_forge_array_values_0 := left
      let __proof_forge_array_values_1 := right
      {
        mstore(0, 29602545150266774396616420083867752660517947997539484713696773112108127617024)
        let _topic0 := keccak256(0, 21)
        mstore(0, __proof_forge_array_values_0)
        mstore(32, __proof_forge_array_values_1)
        log1(0, 64, _topic0)
      }
    }
    function f_EventProbe_emit_pair_array_event(a, b, c, d) {
      let __proof_forge_array_struct_pairs_0_left := a
      let __proof_forge_array_struct_pairs_0_right := b
      let __proof_forge_array_struct_pairs_1_left := c
      let __proof_forge_array_struct_pairs_1_right := d
      {
        mstore(0, 36357139815637527055335479830577877812296532846634599718780626255005467892530)
        mstore(32, 42137535647899687876232062095217863683969663456586636532242186294627689037824)
        let _topic0 := keccak256(0, 34)
        mstore(0, __proof_forge_array_struct_pairs_0_left)
        mstore(32, __proof_forge_array_struct_pairs_0_right)
        mstore(64, __proof_forge_array_struct_pairs_1_left)
        mstore(96, __proof_forge_array_struct_pairs_1_right)
        log1(0, 128, _topic0)
      }
    }
    function f_EventProbe_emit_indexed_pair_event(left, right, value) {
      let __proof_forge_struct_pair_left := left
      let __proof_forge_struct_pair_right := right
      {
        mstore(0, 33213884033972546254760509534762344613534147965852086162890939770421711040116)
        mstore(32, 24517052842465079370413120945299090683665717048513947648744169312629567782912)
        let _topic0 := keccak256(0, 35)
        mstore(0, __proof_forge_struct_pair_left)
        mstore(32, __proof_forge_struct_pair_right)
        let _indexed_topic0 := keccak256(0, 64)
        mstore(0, value)
        log2(0, 32, _topic0, _indexed_topic0)
      }
    }
    function f_EventProbe_emit_indexed_array_event(left, right, value) {
      let __proof_forge_array_values_0 := left
      let __proof_forge_array_values_1 := right
      {
        mstore(0, 33213884033972546161021678077745898947667239935089798860719422326732315230208)
        let _topic0 := keccak256(0, 30)
        mstore(0, __proof_forge_array_values_0)
        mstore(32, __proof_forge_array_values_1)
        let _indexed_topic0 := keccak256(0, 64)
        mstore(0, value)
        log2(0, 32, _topic0, _indexed_topic0)
      }
    }
    function f_EventProbe_emit_indexed_pair_array_event(a, b, c, d, value) {
      let __proof_forge_array_struct_pairs_0_left := a
      let __proof_forge_array_struct_pairs_0_right := b
      let __proof_forge_array_struct_pairs_1_left := c
      let __proof_forge_array_struct_pairs_1_right := d
      {
        mstore(0, 33213884033972546254760509571722283268355815339268100639988835399448156058665)
        mstore(32, 41249454635328975548020660243773414201120874226841181152181438624278037659648)
        let _topic0 := keccak256(0, 43)
        mstore(0, __proof_forge_array_struct_pairs_0_left)
        mstore(32, __proof_forge_array_struct_pairs_0_right)
        mstore(64, __proof_forge_array_struct_pairs_1_left)
        mstore(96, __proof_forge_array_struct_pairs_1_right)
        let _indexed_topic0 := keccak256(0, 128)
        mstore(0, value)
        log2(0, 32, _topic0, _indexed_topic0)
      }
    }
  }
}
