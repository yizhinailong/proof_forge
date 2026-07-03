object "Contract" {
  code {
    mstore(64, 128)
    switch shr(224, calldataload(0))
    case 0x6d4ce63c {
      let _r := f_Counter_get()
      let _v := mload(add(_r, mul(1, 32)))
      mstore(0, shr(1, _v))
      return(0, 32)
    }
    case 0x60fe47b1 {
      let _r := f_Counter_set(or(shl(1, calldataload(4)), 1))
      return(0, 0)
    }
    case 0xd09de08a {
      let _r := f_Counter_increment()
      return(0, 0)
    }
    case 0x2baeceb7 {
      let _r := f_Counter_decrement()
      return(0, 0)
    }
    default {
      revert(0, 0)
    }
    function lean_box(n) -> r {
      r := or(shl(1, n), 1)
    }
    function lean_unbox(o) -> r {
      r := shr(1, o)
    }
    function lean_alloc_ctor(tag, nfields) -> obj {
      let ptr := mload(64)
      mstore(64, add(ptr, mul(add(nfields, 1), 32)))
      mstore(ptr, or(or(tag, shl(8, nfields)), shl(32, 1)))
      obj := ptr
    }
    function lean_ctor_get(obj, i) -> v {
      v := mload(add(obj, mul(add(i, 1), 32)))
    }
    function lean_ctor_set(obj, i, v) {
      mstore(add(obj, mul(add(i, 1), 32)), v)
    }
    function lean_obj_tag(o) -> t {
      t := and(mload(o), 255)
      if and(o, 1) {
        let v := shr(1, o)
        t := iszero(iszero(v))
      }
    }
    function f_Nat_add(a, b) -> r {
      if gt(shr(1, a), sub(115792089237316195423570985008687907853269984665640564039457584007913129639935, shr(1, b))) {
        revert(0, 0)
      }
      r := or(shl(1, add(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_sub(a, b) -> r {
      if gt(shr(1, b), shr(1, a)) {
        revert(0, 0)
      }
      r := or(shl(1, sub(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_mul(a, b) -> r {
      if iszero(shr(1, a)) {
        r := or(shl(1, 0), 1)
        leave
      }
      if gt(shr(1, a), div(115792089237316195423570985008687907853269984665640564039457584007913129639935, shr(1, b))) {
        revert(0, 0)
      }
      r := or(shl(1, mul(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_decEq(a, b) -> r {
      r := or(shl(1, 0), 1)
      if eq(shr(1, a), shr(1, b)) {
        r := or(shl(1, 1), 1)
      }
    }
    function f_Nat_decLe(a, b) -> r {
      r := or(shl(1, 0), 1)
      if iszero(gt(shr(1, a), shr(1, b))) {
        r := or(shl(1, 1), 1)
      }
    }
    function f_Nat_decLt(a, b) -> r {
      r := or(shl(1, 0), 1)
      if lt(shr(1, a), shr(1, b)) {
        r := or(shl(1, 1), 1)
      }
    }
    function f_Nat_div(a, b) -> r {
      if iszero(b) {
        revert(0, 0)
      }
      r := or(shl(1, div(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_mod(a, b) -> r {
      if iszero(b) {
        revert(0, 0)
      }
      r := or(shl(1, mod(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_shiftRight(a, b) -> r {
      r := or(shl(1, shr(shr(1, b), shr(1, a))), 1)
    }
    function f_Nat_shiftLeft(a, b) -> r {
      r := or(shl(1, shl(shr(1, b), shr(1, a))), 1)
    }
    function f_Nat_land(a, b) -> r {
      r := or(shl(1, and(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_lor(a, b) -> r {
      r := or(shl(1, or(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_xor(a, b) -> r {
      r := or(shl(1, xor(shr(1, a), shr(1, b))), 1)
    }
    function lean_array_get_size(a) -> r {
      r := or(shl(1, mload(add(a, 32))), 1)
    }
    function lean_array_get_core(a, i) -> r {
      r := mload(add(add(a, 96), mul(i, 32)))
    }
    function lean_array_set_core(a, i, v) {
      mstore(add(add(a, 96), mul(i, 32)), v)
    }
    function lean_array_push(a, v) -> r {
      let sz := mload(add(a, 32))
      mstore(add(add(a, 96), mul(sz, 32)), v)
      mstore(add(a, 32), add(sz, 1))
      r := a
    }
    function lean_array_mk(n) -> r {
      let _mk_ptr := mload(64)
      mstore(64, add(_mk_ptr, mul(add(n, 3), 32)))
      mstore(_mk_ptr, or(or(or(248, shl(8, 0)), shl(16, 0)), shl(32, 1)))
      mstore(add(_mk_ptr, 32), 0)
      mstore(add(_mk_ptr, 64), shr(1, n))
      r := _mk_ptr
    }
    function f_Array_mkEmpty(c) -> r {
      r := lean_array_mk(c)
    }
    function f_Array_push(a, v) -> r {
      r := lean_array_push(a, v)
    }
    function f_Array_size(a) -> r {
      r := lean_array_get_size(a)
    }
    function f_Array_get_x21InternalBorrowed(_s, a, i) -> r {
      r := lean_array_get_core(a, shr(1, i))
    }
    function f_Counter_get() -> _ret {
      let v___uniq_2_ := or(shl(1, 0), 1)
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_2_))), 1))
      let v___uniq_3_ := _t0
      _ret := v___uniq_3_
      leave
      leave
    }
    function f_Counter_get___boxed(v___uniq_1_) -> _ret {
      let v___uniq_2_ := f_Counter_get()
      _ret := v___uniq_2_
      leave
      leave
    }
    function f_Counter_set(v___uniq_1_) -> _ret {
      let v___uniq_3_ := or(shl(1, 0), 1)
      sstore(shr(1, v___uniq_3_), shr(1, v___uniq_1_))
      let v___uniq_4_ := or(shl(1, 0), 1)
      _ret := v___uniq_4_
      leave
      leave
    }
    function f_Counter_set___boxed(v___uniq_1_, v___uniq_2_) -> _ret {
      let v___uniq_3_ := f_Counter_set(v___uniq_1_)
      _ret := v___uniq_3_
      leave
      leave
    }
    function f_Counter_increment() -> _ret {
      let v___uniq_2_ := or(shl(1, 0), 1)
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_2_))), 1))
      let v___uniq_3_ := _t0
      switch lean_obj_tag(v___uniq_3_)
      case 0 {
        let v___uniq_4_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_5_ := or(shl(1, 1), 1)
        let v___uniq_6_ := f_Nat_add(v___uniq_4_, v___uniq_5_)
        sstore(shr(1, v___uniq_2_), shr(1, v___uniq_6_))
        let v___uniq_7_ := or(shl(1, 0), 1)
        _ret := v___uniq_7_
        leave
      }
      case 1 {
        let v___uniq_8_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_15_ := 1
        switch lean_obj_tag(v___uniq_15_)
        case 0 {
          let v___uniq_9_ := v___uniq_3_
          let v___uniq_10_ := v___uniq_15_
          switch lean_obj_tag(v___uniq_10_)
          case 0 {
            let v___uniq_11_ := v___uniq_9_
            _ret := v___uniq_11_
            leave
          }
          case 1 {
            let _t1 := mload(64)
            mstore(64, add(_t1, mul(2, 32)))
            mstore(_t1, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t1, mul(1, 32)), v___uniq_8_)
            let v___uniq_13_ := _t1
            let v___uniq_11_ := v___uniq_13_
            _ret := v___uniq_11_
            leave
          }
        }
        case 1 {
          let v___uniq_9_ := or(shl(1, 0), 1)
          let v___uniq_10_ := v___uniq_15_
          switch lean_obj_tag(v___uniq_10_)
          case 0 {
            let v___uniq_11_ := v___uniq_9_
            _ret := v___uniq_11_
            leave
          }
          case 1 {
            let _t2 := mload(64)
            mstore(64, add(_t2, mul(2, 32)))
            mstore(_t2, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t2, mul(1, 32)), v___uniq_8_)
            let v___uniq_13_ := _t2
            let v___uniq_11_ := v___uniq_13_
            _ret := v___uniq_11_
            leave
          }
        }
      }
      leave
    }
    function f_Counter_increment___boxed(v___uniq_1_) -> _ret {
      let v___uniq_2_ := f_Counter_increment()
      _ret := v___uniq_2_
      leave
      leave
    }
    function f_Counter_decrement() -> _ret {
      let v___uniq_2_ := or(shl(1, 0), 1)
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_2_))), 1))
      let v___uniq_3_ := _t0
      switch lean_obj_tag(v___uniq_3_)
      case 0 {
        let v___uniq_4_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_16_ := 1
        switch lean_obj_tag(v___uniq_16_)
        case 0 {
          let v___uniq_5_ := v___uniq_3_
          let v___uniq_6_ := v___uniq_16_
          let v___uniq_7_ := f_Nat_decLt(v___uniq_2_, v___uniq_4_)
          switch lean_obj_tag(v___uniq_7_)
          case 0 {
            let v___uniq_8_ := or(shl(1, 0), 1)
            switch lean_obj_tag(v___uniq_6_)
            case 0 {
              mstore(add(v___uniq_5_, mul(1, 32)), v___uniq_8_)
              let v___uniq_9_ := v___uniq_5_
              _ret := v___uniq_9_
              leave
            }
            case 1 {
              let _t1 := mload(64)
              mstore(64, add(_t1, mul(2, 32)))
              mstore(_t1, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
              mstore(add(_t1, mul(1, 32)), v___uniq_8_)
              let v___uniq_11_ := _t1
              let v___uniq_9_ := v___uniq_11_
              _ret := v___uniq_9_
              leave
            }
          }
          case 1 {
            let v___uniq_12_ := or(shl(1, 1), 1)
            let v___uniq_13_ := f_Nat_sub(v___uniq_4_, v___uniq_12_)
            sstore(shr(1, v___uniq_2_), shr(1, v___uniq_13_))
            let v___uniq_14_ := or(shl(1, 0), 1)
            _ret := v___uniq_14_
            leave
          }
        }
        case 1 {
          let v___uniq_5_ := or(shl(1, 0), 1)
          let v___uniq_6_ := v___uniq_16_
          let v___uniq_7_ := f_Nat_decLt(v___uniq_2_, v___uniq_4_)
          switch lean_obj_tag(v___uniq_7_)
          case 0 {
            let v___uniq_8_ := or(shl(1, 0), 1)
            switch lean_obj_tag(v___uniq_6_)
            case 0 {
              mstore(add(v___uniq_5_, mul(1, 32)), v___uniq_8_)
              let v___uniq_9_ := v___uniq_5_
              _ret := v___uniq_9_
              leave
            }
            case 1 {
              let _t2 := mload(64)
              mstore(64, add(_t2, mul(2, 32)))
              mstore(_t2, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
              mstore(add(_t2, mul(1, 32)), v___uniq_8_)
              let v___uniq_11_ := _t2
              let v___uniq_9_ := v___uniq_11_
              _ret := v___uniq_9_
              leave
            }
          }
          case 1 {
            let v___uniq_12_ := or(shl(1, 1), 1)
            let v___uniq_13_ := f_Nat_sub(v___uniq_4_, v___uniq_12_)
            sstore(shr(1, v___uniq_2_), shr(1, v___uniq_13_))
            let v___uniq_14_ := or(shl(1, 0), 1)
            _ret := v___uniq_14_
            leave
          }
        }
      }
      case 1 {
        let v___uniq_17_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_24_ := 1
        switch lean_obj_tag(v___uniq_24_)
        case 0 {
          let v___uniq_18_ := v___uniq_3_
          let v___uniq_19_ := v___uniq_24_
          switch lean_obj_tag(v___uniq_19_)
          case 0 {
            let v___uniq_20_ := v___uniq_18_
            _ret := v___uniq_20_
            leave
          }
          case 1 {
            let _t3 := mload(64)
            mstore(64, add(_t3, mul(2, 32)))
            mstore(_t3, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t3, mul(1, 32)), v___uniq_17_)
            let v___uniq_22_ := _t3
            let v___uniq_20_ := v___uniq_22_
            _ret := v___uniq_20_
            leave
          }
        }
        case 1 {
          let v___uniq_18_ := or(shl(1, 0), 1)
          let v___uniq_19_ := v___uniq_24_
          switch lean_obj_tag(v___uniq_19_)
          case 0 {
            let v___uniq_20_ := v___uniq_18_
            _ret := v___uniq_20_
            leave
          }
          case 1 {
            let _t4 := mload(64)
            mstore(64, add(_t4, mul(2, 32)))
            mstore(_t4, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t4, mul(1, 32)), v___uniq_17_)
            let v___uniq_22_ := _t4
            let v___uniq_20_ := v___uniq_22_
            _ret := v___uniq_20_
            leave
          }
        }
      }
      leave
    }
    function f_Counter_decrement___boxed(v___uniq_1_) -> _ret {
      let v___uniq_2_ := f_Counter_decrement()
      _ret := v___uniq_2_
      leave
      leave
    }
  }
}
