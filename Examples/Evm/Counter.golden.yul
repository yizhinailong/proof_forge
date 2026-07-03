object "Counter" {
  code {
    switch shr(224, calldataload(0))
    case 0x8129fc1c {
      f_Counter_initialize()
      return(0, 0)
    }
    case 0xd09de08a {
      f_Counter_increment()
      return(0, 0)
    }
    case 0x6d4ce63c {
      let _r := f_Counter_get()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_Counter_initialize() {
      sstore(0, 0)
    }
    function f_Counter_increment() {
      let n := sload(0)
      sstore(0, add(n, 1))
    }
    function f_Counter_get() -> result {
      result := sload(0)
    }
  }
}
