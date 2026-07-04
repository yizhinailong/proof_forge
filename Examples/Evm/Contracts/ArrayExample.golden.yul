object "ArrayExample" {
  code {
    switch shr(224, calldataload(0))
    case 0x8c471d33 {
      let _r := f_ArrayExample_sizeOf3()
      mstore(0, _r)
      return(0, 32)
    }
    case 0xff170768 {
      let _r := f_ArrayExample_getElem()
      mstore(0, _r)
      return(0, 32)
    }
    case 0x6d666075 {
      let _r := f_ArrayExample_sumOf3()
      mstore(0, _r)
      return(0, 32)
    }
    default {
      revert(0, 0)
    }
    function f_ArrayExample_sizeOf3() -> result {
      result := 3
    }
    function f_ArrayExample_getElem() -> result {
      let __proof_forge_array_xs_0 := 10
      let __proof_forge_array_xs_1 := 20
      let __proof_forge_array_xs_2 := 30
      result := __proof_forge_array_xs_1
    }
    function f_ArrayExample_sumOf3() -> result {
      let __proof_forge_array_xs_0 := 10
      let __proof_forge_array_xs_1 := 20
      let __proof_forge_array_xs_2 := 30
      result := __proof_forge_local_array_get_3(__pf_checked_add(0, __proof_forge_local_array_get_3(__pf_checked_add(1, __proof_forge_array_xs_2), __proof_forge_array_xs_0, __proof_forge_array_xs_1, __proof_forge_array_xs_2)), __proof_forge_array_xs_0, __proof_forge_array_xs_1, __proof_forge_array_xs_2)
    }
    function __pf_checked_add(a, b) -> r {
      if gt(a, sub(115792089237316195423570985008687907853269984665640564039457584007913129639935, b)) {
        revert(0, 0)
      }
      r := add(a, b)
    }
    function __pf_checked_sub(a, b) -> r {
      if gt(b, a) {
        revert(0, 0)
      }
      r := sub(a, b)
    }
    function __pf_checked_mul(a, b) -> r {
      if iszero(a) {
        r := 0
        leave
      }
      if gt(a, div(115792089237316195423570985008687907853269984665640564039457584007913129639935, b)) {
        revert(0, 0)
      }
      r := mul(a, b)
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
