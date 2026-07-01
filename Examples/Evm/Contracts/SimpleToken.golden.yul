object "Contract" {
  code {
    mstore(64, 128)
    switch shr(224, calldataload(0))
    case 0xb7b0422d {
      let _r := f_SimpleToken_init(or(shl(1, calldataload(4)), 1))
      return(0, 0)
    }
    case 0x893d20e8 {
      let _r := f_SimpleToken_getOwner()
      let _v := mload(add(_r, mul(1, 32)))
      mstore(0, shr(1, _v))
      return(0, 32)
    }
    case 0x18160ddd {
      let _r := f_SimpleToken_totalSupply()
      let _v := mload(add(_r, mul(1, 32)))
      mstore(0, shr(1, _v))
      return(0, 32)
    }
    case 0x9cc7f708 {
      let _r := f_SimpleToken_balanceOf(or(shl(1, calldataload(4)), 1))
      let _v := mload(add(_r, mul(1, 32)))
      mstore(0, shr(1, _v))
      return(0, 32)
    }
    case 0x0cf79e0a {
      let _r := f_SimpleToken_transfer(or(shl(1, calldataload(4)), 1), or(shl(1, calldataload(36)), 1))
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
        t := shr(1, o)
      }
    }
    function f_Nat_add(a, b) -> r {
      r := or(shl(1, add(shr(1, a), shr(1, b))), 1)
    }
    function f_Nat_sub(a, b) -> r {
      r := or(shl(1, 0), 1)
      if iszero(lt(shr(1, a), shr(1, b))) {
        let va := shr(1, a)
        let vb := shr(1, b)
        r := or(shl(1, sub(va, vb)), 1)
      }
    }
    function f_Nat_mul(a, b) -> r {
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
    function f_SimpleToken_init(v___uniq_1_) -> _ret {
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, caller()), 1))
      let v___uniq_3_ := _t0
      switch lean_obj_tag(v___uniq_3_)
      case 0 {
        let v___uniq_4_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_5_ := or(shl(1, 0), 1)
        sstore(shr(1, v___uniq_5_), shr(1, v___uniq_4_))
        let v___uniq_6_ := or(shl(1, 0), 1)
        switch lean_obj_tag(v___uniq_6_)
        case 0 {
          let v___uniq_7_ := or(shl(1, 1), 1)
          sstore(shr(1, v___uniq_7_), shr(1, v___uniq_1_))
          let v___uniq_8_ := or(shl(1, 0), 1)
          switch lean_obj_tag(v___uniq_8_)
          case 0 {
            mstore(shr(1, v___uniq_5_), shr(1, v___uniq_4_))
            let v___uniq_9_ := or(shl(1, 0), 1)
            switch lean_obj_tag(v___uniq_9_)
            case 0 {
              let v___uniq_10_ := or(shl(1, 2), 1)
              let v___uniq_11_ := or(shl(1, 32), 1)
              mstore(shr(1, v___uniq_11_), shr(1, v___uniq_10_))
              let v___uniq_12_ := or(shl(1, 0), 1)
              switch lean_obj_tag(v___uniq_12_)
              case 0 {
                let v___uniq_13_ := or(shl(1, 64), 1)
                let _t1 := mload(64)
                mstore(64, add(_t1, mul(2, 32)))
                mstore(_t1, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                mstore(add(_t1, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_5_), shr(1, v___uniq_13_))), 1))
                let v___uniq_14_ := _t1
                switch lean_obj_tag(v___uniq_14_)
                case 0 {
                  let v___uniq_15_ := mload(add(v___uniq_14_, mul(1, 32)))
                  sstore(shr(1, v___uniq_15_), shr(1, v___uniq_1_))
                  let v___uniq_16_ := or(shl(1, 0), 1)
                  _ret := v___uniq_16_
                  leave
                }
                case 1 {
                  let v___uniq_17_ := mload(add(v___uniq_14_, mul(1, 32)))
                  let v___uniq_24_ := 1
                  switch lean_obj_tag(v___uniq_24_)
                  case 0 {
                    let v___uniq_18_ := v___uniq_14_
                    let v___uniq_19_ := v___uniq_24_
                    switch lean_obj_tag(v___uniq_19_)
                    case 0 {
                      let v___uniq_20_ := v___uniq_18_
                      _ret := v___uniq_20_
                      leave
                    }
                    case 1 {
                      let _t2 := mload(64)
                      mstore(64, add(_t2, mul(2, 32)))
                      mstore(_t2, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                      mstore(add(_t2, mul(1, 32)), v___uniq_17_)
                      let v___uniq_22_ := _t2
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
                }
              }
              case 1 {
                _ret := v___uniq_12_
                leave
              }
            }
            case 1 {
              _ret := v___uniq_9_
              leave
            }
          }
          case 1 {
            _ret := v___uniq_8_
            leave
          }
        }
        case 1 {
          _ret := v___uniq_6_
          leave
        }
      }
      case 1 {
        let v___uniq_25_ := mload(add(v___uniq_3_, mul(1, 32)))
        let v___uniq_32_ := 1
        switch lean_obj_tag(v___uniq_32_)
        case 0 {
          let v___uniq_26_ := v___uniq_3_
          let v___uniq_27_ := v___uniq_32_
          switch lean_obj_tag(v___uniq_27_)
          case 0 {
            let v___uniq_28_ := v___uniq_26_
            _ret := v___uniq_28_
            leave
          }
          case 1 {
            let _t4 := mload(64)
            mstore(64, add(_t4, mul(2, 32)))
            mstore(_t4, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t4, mul(1, 32)), v___uniq_25_)
            let v___uniq_30_ := _t4
            let v___uniq_28_ := v___uniq_30_
            _ret := v___uniq_28_
            leave
          }
        }
        case 1 {
          let v___uniq_26_ := or(shl(1, 0), 1)
          let v___uniq_27_ := v___uniq_32_
          switch lean_obj_tag(v___uniq_27_)
          case 0 {
            let v___uniq_28_ := v___uniq_26_
            _ret := v___uniq_28_
            leave
          }
          case 1 {
            let _t5 := mload(64)
            mstore(64, add(_t5, mul(2, 32)))
            mstore(_t5, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t5, mul(1, 32)), v___uniq_25_)
            let v___uniq_30_ := _t5
            let v___uniq_28_ := v___uniq_30_
            _ret := v___uniq_28_
            leave
          }
        }
      }
      leave
    }
    function f_SimpleToken_init___boxed(v___uniq_1_, v___uniq_2_) -> _ret {
      let v___uniq_3_ := f_SimpleToken_init(v___uniq_1_)
      _ret := v___uniq_3_
      leave
      leave
    }
    function f_SimpleToken_getOwner() -> _ret {
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
    function f_SimpleToken_getOwner___boxed(v___uniq_1_) -> _ret {
      let v___uniq_2_ := f_SimpleToken_getOwner()
      _ret := v___uniq_2_
      leave
      leave
    }
    function f_SimpleToken_totalSupply() -> _ret {
      let v___uniq_2_ := or(shl(1, 1), 1)
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_2_))), 1))
      let v___uniq_3_ := _t0
      _ret := v___uniq_3_
      leave
      leave
    }
    function f_SimpleToken_totalSupply___boxed(v___uniq_1_) -> _ret {
      let v___uniq_2_ := f_SimpleToken_totalSupply()
      _ret := v___uniq_2_
      leave
      leave
    }
    function f_SimpleToken_balanceOf(v___uniq_1_) -> _ret {
      let v___uniq_3_ := or(shl(1, 0), 1)
      mstore(shr(1, v___uniq_3_), shr(1, v___uniq_1_))
      let v___uniq_4_ := or(shl(1, 0), 1)
      switch lean_obj_tag(v___uniq_4_)
      case 0 {
        let v___uniq_5_ := or(shl(1, 2), 1)
        let v___uniq_6_ := or(shl(1, 32), 1)
        mstore(shr(1, v___uniq_6_), shr(1, v___uniq_5_))
        let v___uniq_7_ := or(shl(1, 0), 1)
        switch lean_obj_tag(v___uniq_7_)
        case 0 {
          let v___uniq_8_ := or(shl(1, 64), 1)
          let _t0 := mload(64)
          mstore(64, add(_t0, mul(2, 32)))
          mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
          mstore(add(_t0, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_3_), shr(1, v___uniq_8_))), 1))
          let v___uniq_9_ := _t0
          switch lean_obj_tag(v___uniq_9_)
          case 0 {
            let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
            let _t1 := mload(64)
            mstore(64, add(_t1, mul(2, 32)))
            mstore(_t1, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t1, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_10_))), 1))
            let v___uniq_11_ := _t1
            _ret := v___uniq_11_
            leave
          }
          case 1 {
            _ret := v___uniq_9_
            leave
          }
        }
        case 1 {
          let v___uniq_12_ := mload(add(v___uniq_7_, mul(1, 32)))
          let v___uniq_19_ := 1
          switch lean_obj_tag(v___uniq_19_)
          case 0 {
            let v___uniq_13_ := v___uniq_7_
            let v___uniq_14_ := v___uniq_19_
            switch lean_obj_tag(v___uniq_14_)
            case 0 {
              let v___uniq_15_ := v___uniq_13_
              _ret := v___uniq_15_
              leave
            }
            case 1 {
              let _t2 := mload(64)
              mstore(64, add(_t2, mul(2, 32)))
              mstore(_t2, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
              mstore(add(_t2, mul(1, 32)), v___uniq_12_)
              let v___uniq_17_ := _t2
              let v___uniq_15_ := v___uniq_17_
              _ret := v___uniq_15_
              leave
            }
          }
          case 1 {
            let v___uniq_13_ := or(shl(1, 0), 1)
            let v___uniq_14_ := v___uniq_19_
            switch lean_obj_tag(v___uniq_14_)
            case 0 {
              let v___uniq_15_ := v___uniq_13_
              _ret := v___uniq_15_
              leave
            }
            case 1 {
              let _t3 := mload(64)
              mstore(64, add(_t3, mul(2, 32)))
              mstore(_t3, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
              mstore(add(_t3, mul(1, 32)), v___uniq_12_)
              let v___uniq_17_ := _t3
              let v___uniq_15_ := v___uniq_17_
              _ret := v___uniq_15_
              leave
            }
          }
        }
      }
      case 1 {
        let v___uniq_20_ := mload(add(v___uniq_4_, mul(1, 32)))
        let v___uniq_27_ := 1
        switch lean_obj_tag(v___uniq_27_)
        case 0 {
          let v___uniq_21_ := v___uniq_4_
          let v___uniq_22_ := v___uniq_27_
          switch lean_obj_tag(v___uniq_22_)
          case 0 {
            let v___uniq_23_ := v___uniq_21_
            _ret := v___uniq_23_
            leave
          }
          case 1 {
            let _t4 := mload(64)
            mstore(64, add(_t4, mul(2, 32)))
            mstore(_t4, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t4, mul(1, 32)), v___uniq_20_)
            let v___uniq_25_ := _t4
            let v___uniq_23_ := v___uniq_25_
            _ret := v___uniq_23_
            leave
          }
        }
        case 1 {
          let v___uniq_21_ := or(shl(1, 0), 1)
          let v___uniq_22_ := v___uniq_27_
          switch lean_obj_tag(v___uniq_22_)
          case 0 {
            let v___uniq_23_ := v___uniq_21_
            _ret := v___uniq_23_
            leave
          }
          case 1 {
            let _t5 := mload(64)
            mstore(64, add(_t5, mul(2, 32)))
            mstore(_t5, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t5, mul(1, 32)), v___uniq_20_)
            let v___uniq_25_ := _t5
            let v___uniq_23_ := v___uniq_25_
            _ret := v___uniq_23_
            leave
          }
        }
      }
      leave
    }
    function f_SimpleToken_balanceOf___boxed(v___uniq_1_, v___uniq_2_) -> _ret {
      let v___uniq_3_ := f_SimpleToken_balanceOf(v___uniq_1_)
      _ret := v___uniq_3_
      leave
      leave
    }
    function f_SimpleToken_transfer(v___uniq_1_, v___uniq_2_) -> _ret {
      let _t0 := mload(64)
      mstore(64, add(_t0, mul(2, 32)))
      mstore(_t0, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
      mstore(add(_t0, mul(1, 32)), or(shl(1, caller()), 1))
      let v___uniq_4_ := _t0
      switch lean_obj_tag(v___uniq_4_)
      case 0 {
        let v___uniq_5_ := mload(add(v___uniq_4_, mul(1, 32)))
        let v___uniq_6_ := or(shl(1, 0), 1)
        mstore(shr(1, v___uniq_6_), shr(1, v___uniq_5_))
        let v___uniq_7_ := or(shl(1, 0), 1)
        switch lean_obj_tag(v___uniq_7_)
        case 0 {
          let v___uniq_8_ := or(shl(1, 2), 1)
          let v___uniq_74_ := or(shl(1, 32), 1)
          mstore(shr(1, v___uniq_74_), shr(1, v___uniq_8_))
          let v___uniq_75_ := or(shl(1, 0), 1)
          switch lean_obj_tag(v___uniq_75_)
          case 0 {
            let v___uniq_76_ := or(shl(1, 64), 1)
            let _t1 := mload(64)
            mstore(64, add(_t1, mul(2, 32)))
            mstore(_t1, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t1, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_76_))), 1))
            let v___uniq_77_ := _t1
            switch lean_obj_tag(v___uniq_77_)
            case 0 {
              let v___uniq_78_ := mload(add(v___uniq_77_, mul(1, 32)))
              let _t2 := mload(64)
              mstore(64, add(_t2, mul(2, 32)))
              mstore(_t2, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
              mstore(add(_t2, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_78_))), 1))
              let v___uniq_79_ := _t2
              let v___uniq_45_ := v___uniq_79_
              switch lean_obj_tag(v___uniq_45_)
              case 0 {
                let v___uniq_46_ := mload(add(v___uniq_45_, mul(1, 32)))
                let v___uniq_47_ := f_Nat_decLe(v___uniq_2_, v___uniq_46_)
                switch lean_obj_tag(v___uniq_47_)
                case 0 {
                  revert(shr(1, v___uniq_6_), shr(1, v___uniq_6_))
                  revert(0, 0)
                  let v___uniq_48_ := or(shl(1, 0), 1)
                  _ret := v___uniq_48_
                  leave
                }
                case 1 {
                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_5_))
                  let v___uniq_49_ := or(shl(1, 0), 1)
                  switch lean_obj_tag(v___uniq_49_)
                  case 0 {
                    let v___uniq_50_ := or(shl(1, 32), 1)
                    mstore(shr(1, v___uniq_50_), shr(1, v___uniq_8_))
                    let v___uniq_51_ := or(shl(1, 0), 1)
                    switch lean_obj_tag(v___uniq_51_)
                    case 0 {
                      let v___uniq_52_ := or(shl(1, 64), 1)
                      let _t3 := mload(64)
                      mstore(64, add(_t3, mul(2, 32)))
                      mstore(_t3, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                      mstore(add(_t3, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_52_))), 1))
                      let v___uniq_53_ := _t3
                      switch lean_obj_tag(v___uniq_53_)
                      case 0 {
                        let v___uniq_54_ := mload(add(v___uniq_53_, mul(1, 32)))
                        let v___uniq_55_ := f_Nat_sub(v___uniq_46_, v___uniq_2_)
                        sstore(shr(1, v___uniq_54_), shr(1, v___uniq_55_))
                        let v___uniq_56_ := or(shl(1, 0), 1)
                        let v___uniq_36_ := v___uniq_56_
                        switch lean_obj_tag(v___uniq_36_)
                        case 0 {
                          mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                          let v___uniq_37_ := or(shl(1, 0), 1)
                          switch lean_obj_tag(v___uniq_37_)
                          case 0 {
                            let v___uniq_38_ := or(shl(1, 32), 1)
                            mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                            let v___uniq_39_ := or(shl(1, 0), 1)
                            switch lean_obj_tag(v___uniq_39_)
                            case 0 {
                              let v___uniq_40_ := or(shl(1, 64), 1)
                              let _t4 := mload(64)
                              mstore(64, add(_t4, mul(2, 32)))
                              mstore(_t4, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                              mstore(add(_t4, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                              let v___uniq_41_ := _t4
                              switch lean_obj_tag(v___uniq_41_)
                              case 0 {
                                let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                                let _t5 := mload(64)
                                mstore(64, add(_t5, mul(2, 32)))
                                mstore(_t5, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                mstore(add(_t5, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                                let v___uniq_43_ := _t5
                                let v___uniq_9_ := v___uniq_43_
                                switch lean_obj_tag(v___uniq_9_)
                                case 0 {
                                  let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                  let v___uniq_11_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_11_)
                                  case 0 {
                                    let v___uniq_12_ := or(shl(1, 32), 1)
                                    mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                    let v___uniq_13_ := or(shl(1, 0), 1)
                                    switch lean_obj_tag(v___uniq_13_)
                                    case 0 {
                                      let v___uniq_14_ := or(shl(1, 64), 1)
                                      let _t6 := mload(64)
                                      mstore(64, add(_t6, mul(2, 32)))
                                      mstore(_t6, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t6, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                      let v___uniq_15_ := _t6
                                      switch lean_obj_tag(v___uniq_15_)
                                      case 0 {
                                        let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                        sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                        let v___uniq_18_ := or(shl(1, 0), 1)
                                        _ret := v___uniq_18_
                                        leave
                                      }
                                      case 1 {
                                        let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_26_ := 1
                                        switch lean_obj_tag(v___uniq_26_)
                                        case 0 {
                                          let v___uniq_20_ := v___uniq_15_
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t7 := mload(64)
                                            mstore(64, add(_t7, mul(2, 32)))
                                            mstore(_t7, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t7, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t7
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                        case 1 {
                                          let v___uniq_20_ := or(shl(1, 0), 1)
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t8 := mload(64)
                                            mstore(64, add(_t8, mul(2, 32)))
                                            mstore(_t8, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t8, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t8
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                      }
                                    }
                                    case 1 {
                                      _ret := v___uniq_13_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_11_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  let v___uniq_34_ := 1
                                  switch lean_obj_tag(v___uniq_34_)
                                  case 0 {
                                    let v___uniq_28_ := v___uniq_9_
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t9 := mload(64)
                                      mstore(64, add(_t9, mul(2, 32)))
                                      mstore(_t9, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t9, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t9
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    let v___uniq_28_ := or(shl(1, 0), 1)
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t10 := mload(64)
                                      mstore(64, add(_t10, mul(2, 32)))
                                      mstore(_t10, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t10, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t10
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                }
                              }
                              case 1 {
                                let v___uniq_9_ := v___uniq_41_
                                switch lean_obj_tag(v___uniq_9_)
                                case 0 {
                                  let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                  let v___uniq_11_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_11_)
                                  case 0 {
                                    let v___uniq_12_ := or(shl(1, 32), 1)
                                    mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                    let v___uniq_13_ := or(shl(1, 0), 1)
                                    switch lean_obj_tag(v___uniq_13_)
                                    case 0 {
                                      let v___uniq_14_ := or(shl(1, 64), 1)
                                      let _t11 := mload(64)
                                      mstore(64, add(_t11, mul(2, 32)))
                                      mstore(_t11, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t11, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                      let v___uniq_15_ := _t11
                                      switch lean_obj_tag(v___uniq_15_)
                                      case 0 {
                                        let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                        sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                        let v___uniq_18_ := or(shl(1, 0), 1)
                                        _ret := v___uniq_18_
                                        leave
                                      }
                                      case 1 {
                                        let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_26_ := 1
                                        switch lean_obj_tag(v___uniq_26_)
                                        case 0 {
                                          let v___uniq_20_ := v___uniq_15_
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t12 := mload(64)
                                            mstore(64, add(_t12, mul(2, 32)))
                                            mstore(_t12, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t12, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t12
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                        case 1 {
                                          let v___uniq_20_ := or(shl(1, 0), 1)
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t13 := mload(64)
                                            mstore(64, add(_t13, mul(2, 32)))
                                            mstore(_t13, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t13, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t13
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                      }
                                    }
                                    case 1 {
                                      _ret := v___uniq_13_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_11_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  let v___uniq_34_ := 1
                                  switch lean_obj_tag(v___uniq_34_)
                                  case 0 {
                                    let v___uniq_28_ := v___uniq_9_
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t14 := mload(64)
                                      mstore(64, add(_t14, mul(2, 32)))
                                      mstore(_t14, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t14, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t14
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    let v___uniq_28_ := or(shl(1, 0), 1)
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t15 := mload(64)
                                      mstore(64, add(_t15, mul(2, 32)))
                                      mstore(_t15, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t15, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t15
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                }
                              }
                            }
                            case 1 {
                              _ret := v___uniq_39_
                              leave
                            }
                          }
                          case 1 {
                            _ret := v___uniq_37_
                            leave
                          }
                        }
                        case 1 {
                          _ret := v___uniq_36_
                          leave
                        }
                      }
                      case 1 {
                        let v___uniq_57_ := mload(add(v___uniq_53_, mul(1, 32)))
                        let v___uniq_64_ := 1
                        switch lean_obj_tag(v___uniq_64_)
                        case 0 {
                          let v___uniq_58_ := v___uniq_53_
                          let v___uniq_59_ := v___uniq_64_
                          switch lean_obj_tag(v___uniq_59_)
                          case 0 {
                            let v___uniq_60_ := v___uniq_58_
                            _ret := v___uniq_60_
                            leave
                          }
                          case 1 {
                            let _t16 := mload(64)
                            mstore(64, add(_t16, mul(2, 32)))
                            mstore(_t16, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t16, mul(1, 32)), v___uniq_57_)
                            let v___uniq_62_ := _t16
                            let v___uniq_60_ := v___uniq_62_
                            _ret := v___uniq_60_
                            leave
                          }
                        }
                        case 1 {
                          let v___uniq_58_ := or(shl(1, 0), 1)
                          let v___uniq_59_ := v___uniq_64_
                          switch lean_obj_tag(v___uniq_59_)
                          case 0 {
                            let v___uniq_60_ := v___uniq_58_
                            _ret := v___uniq_60_
                            leave
                          }
                          case 1 {
                            let _t17 := mload(64)
                            mstore(64, add(_t17, mul(2, 32)))
                            mstore(_t17, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t17, mul(1, 32)), v___uniq_57_)
                            let v___uniq_62_ := _t17
                            let v___uniq_60_ := v___uniq_62_
                            _ret := v___uniq_60_
                            leave
                          }
                        }
                      }
                    }
                    case 1 {
                      let v___uniq_36_ := v___uniq_51_
                      switch lean_obj_tag(v___uniq_36_)
                      case 0 {
                        mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                        let v___uniq_37_ := or(shl(1, 0), 1)
                        switch lean_obj_tag(v___uniq_37_)
                        case 0 {
                          let v___uniq_38_ := or(shl(1, 32), 1)
                          mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                          let v___uniq_39_ := or(shl(1, 0), 1)
                          switch lean_obj_tag(v___uniq_39_)
                          case 0 {
                            let v___uniq_40_ := or(shl(1, 64), 1)
                            let _t18 := mload(64)
                            mstore(64, add(_t18, mul(2, 32)))
                            mstore(_t18, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t18, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                            let v___uniq_41_ := _t18
                            switch lean_obj_tag(v___uniq_41_)
                            case 0 {
                              let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                              let _t19 := mload(64)
                              mstore(64, add(_t19, mul(2, 32)))
                              mstore(_t19, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                              mstore(add(_t19, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                              let v___uniq_43_ := _t19
                              let v___uniq_9_ := v___uniq_43_
                              switch lean_obj_tag(v___uniq_9_)
                              case 0 {
                                let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                let v___uniq_11_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_11_)
                                case 0 {
                                  let v___uniq_12_ := or(shl(1, 32), 1)
                                  mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                  let v___uniq_13_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_13_)
                                  case 0 {
                                    let v___uniq_14_ := or(shl(1, 64), 1)
                                    let _t20 := mload(64)
                                    mstore(64, add(_t20, mul(2, 32)))
                                    mstore(_t20, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t20, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                    let v___uniq_15_ := _t20
                                    switch lean_obj_tag(v___uniq_15_)
                                    case 0 {
                                      let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                      sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                      let v___uniq_18_ := or(shl(1, 0), 1)
                                      _ret := v___uniq_18_
                                      leave
                                    }
                                    case 1 {
                                      let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_26_ := 1
                                      switch lean_obj_tag(v___uniq_26_)
                                      case 0 {
                                        let v___uniq_20_ := v___uniq_15_
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t21 := mload(64)
                                          mstore(64, add(_t21, mul(2, 32)))
                                          mstore(_t21, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t21, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t21
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                      case 1 {
                                        let v___uniq_20_ := or(shl(1, 0), 1)
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t22 := mload(64)
                                          mstore(64, add(_t22, mul(2, 32)))
                                          mstore(_t22, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t22, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t22
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_13_
                                    leave
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_11_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                let v___uniq_34_ := 1
                                switch lean_obj_tag(v___uniq_34_)
                                case 0 {
                                  let v___uniq_28_ := v___uniq_9_
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t23 := mload(64)
                                    mstore(64, add(_t23, mul(2, 32)))
                                    mstore(_t23, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t23, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t23
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_28_ := or(shl(1, 0), 1)
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t24 := mload(64)
                                    mstore(64, add(_t24, mul(2, 32)))
                                    mstore(_t24, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t24, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t24
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                              }
                            }
                            case 1 {
                              let v___uniq_9_ := v___uniq_41_
                              switch lean_obj_tag(v___uniq_9_)
                              case 0 {
                                let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                let v___uniq_11_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_11_)
                                case 0 {
                                  let v___uniq_12_ := or(shl(1, 32), 1)
                                  mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                  let v___uniq_13_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_13_)
                                  case 0 {
                                    let v___uniq_14_ := or(shl(1, 64), 1)
                                    let _t25 := mload(64)
                                    mstore(64, add(_t25, mul(2, 32)))
                                    mstore(_t25, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t25, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                    let v___uniq_15_ := _t25
                                    switch lean_obj_tag(v___uniq_15_)
                                    case 0 {
                                      let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                      sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                      let v___uniq_18_ := or(shl(1, 0), 1)
                                      _ret := v___uniq_18_
                                      leave
                                    }
                                    case 1 {
                                      let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_26_ := 1
                                      switch lean_obj_tag(v___uniq_26_)
                                      case 0 {
                                        let v___uniq_20_ := v___uniq_15_
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t26 := mload(64)
                                          mstore(64, add(_t26, mul(2, 32)))
                                          mstore(_t26, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t26, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t26
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                      case 1 {
                                        let v___uniq_20_ := or(shl(1, 0), 1)
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t27 := mload(64)
                                          mstore(64, add(_t27, mul(2, 32)))
                                          mstore(_t27, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t27, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t27
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_13_
                                    leave
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_11_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                let v___uniq_34_ := 1
                                switch lean_obj_tag(v___uniq_34_)
                                case 0 {
                                  let v___uniq_28_ := v___uniq_9_
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t28 := mload(64)
                                    mstore(64, add(_t28, mul(2, 32)))
                                    mstore(_t28, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t28, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t28
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_28_ := or(shl(1, 0), 1)
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t29 := mload(64)
                                    mstore(64, add(_t29, mul(2, 32)))
                                    mstore(_t29, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t29, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t29
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                              }
                            }
                          }
                          case 1 {
                            _ret := v___uniq_39_
                            leave
                          }
                        }
                        case 1 {
                          _ret := v___uniq_37_
                          leave
                        }
                      }
                      case 1 {
                        _ret := v___uniq_36_
                        leave
                      }
                    }
                  }
                  case 1 {
                    let v___uniq_36_ := v___uniq_49_
                    switch lean_obj_tag(v___uniq_36_)
                    case 0 {
                      mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                      let v___uniq_37_ := or(shl(1, 0), 1)
                      switch lean_obj_tag(v___uniq_37_)
                      case 0 {
                        let v___uniq_38_ := or(shl(1, 32), 1)
                        mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                        let v___uniq_39_ := or(shl(1, 0), 1)
                        switch lean_obj_tag(v___uniq_39_)
                        case 0 {
                          let v___uniq_40_ := or(shl(1, 64), 1)
                          let _t30 := mload(64)
                          mstore(64, add(_t30, mul(2, 32)))
                          mstore(_t30, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                          mstore(add(_t30, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                          let v___uniq_41_ := _t30
                          switch lean_obj_tag(v___uniq_41_)
                          case 0 {
                            let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                            let _t31 := mload(64)
                            mstore(64, add(_t31, mul(2, 32)))
                            mstore(_t31, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t31, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                            let v___uniq_43_ := _t31
                            let v___uniq_9_ := v___uniq_43_
                            switch lean_obj_tag(v___uniq_9_)
                            case 0 {
                              let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                              mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                              let v___uniq_11_ := or(shl(1, 0), 1)
                              switch lean_obj_tag(v___uniq_11_)
                              case 0 {
                                let v___uniq_12_ := or(shl(1, 32), 1)
                                mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                let v___uniq_13_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_13_)
                                case 0 {
                                  let v___uniq_14_ := or(shl(1, 64), 1)
                                  let _t32 := mload(64)
                                  mstore(64, add(_t32, mul(2, 32)))
                                  mstore(_t32, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t32, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                  let v___uniq_15_ := _t32
                                  switch lean_obj_tag(v___uniq_15_)
                                  case 0 {
                                    let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                    sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                    let v___uniq_18_ := or(shl(1, 0), 1)
                                    _ret := v___uniq_18_
                                    leave
                                  }
                                  case 1 {
                                    let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_26_ := 1
                                    switch lean_obj_tag(v___uniq_26_)
                                    case 0 {
                                      let v___uniq_20_ := v___uniq_15_
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t33 := mload(64)
                                        mstore(64, add(_t33, mul(2, 32)))
                                        mstore(_t33, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t33, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t33
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                    case 1 {
                                      let v___uniq_20_ := or(shl(1, 0), 1)
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t34 := mload(64)
                                        mstore(64, add(_t34, mul(2, 32)))
                                        mstore(_t34, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t34, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t34
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_13_
                                  leave
                                }
                              }
                              case 1 {
                                _ret := v___uniq_11_
                                leave
                              }
                            }
                            case 1 {
                              let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                              let v___uniq_34_ := 1
                              switch lean_obj_tag(v___uniq_34_)
                              case 0 {
                                let v___uniq_28_ := v___uniq_9_
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t35 := mload(64)
                                  mstore(64, add(_t35, mul(2, 32)))
                                  mstore(_t35, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t35, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t35
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_28_ := or(shl(1, 0), 1)
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t36 := mload(64)
                                  mstore(64, add(_t36, mul(2, 32)))
                                  mstore(_t36, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t36, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t36
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                            }
                          }
                          case 1 {
                            let v___uniq_9_ := v___uniq_41_
                            switch lean_obj_tag(v___uniq_9_)
                            case 0 {
                              let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                              mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                              let v___uniq_11_ := or(shl(1, 0), 1)
                              switch lean_obj_tag(v___uniq_11_)
                              case 0 {
                                let v___uniq_12_ := or(shl(1, 32), 1)
                                mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                let v___uniq_13_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_13_)
                                case 0 {
                                  let v___uniq_14_ := or(shl(1, 64), 1)
                                  let _t37 := mload(64)
                                  mstore(64, add(_t37, mul(2, 32)))
                                  mstore(_t37, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t37, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                  let v___uniq_15_ := _t37
                                  switch lean_obj_tag(v___uniq_15_)
                                  case 0 {
                                    let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                    sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                    let v___uniq_18_ := or(shl(1, 0), 1)
                                    _ret := v___uniq_18_
                                    leave
                                  }
                                  case 1 {
                                    let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_26_ := 1
                                    switch lean_obj_tag(v___uniq_26_)
                                    case 0 {
                                      let v___uniq_20_ := v___uniq_15_
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t38 := mload(64)
                                        mstore(64, add(_t38, mul(2, 32)))
                                        mstore(_t38, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t38, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t38
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                    case 1 {
                                      let v___uniq_20_ := or(shl(1, 0), 1)
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t39 := mload(64)
                                        mstore(64, add(_t39, mul(2, 32)))
                                        mstore(_t39, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t39, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t39
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_13_
                                  leave
                                }
                              }
                              case 1 {
                                _ret := v___uniq_11_
                                leave
                              }
                            }
                            case 1 {
                              let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                              let v___uniq_34_ := 1
                              switch lean_obj_tag(v___uniq_34_)
                              case 0 {
                                let v___uniq_28_ := v___uniq_9_
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t40 := mload(64)
                                  mstore(64, add(_t40, mul(2, 32)))
                                  mstore(_t40, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t40, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t40
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_28_ := or(shl(1, 0), 1)
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t41 := mload(64)
                                  mstore(64, add(_t41, mul(2, 32)))
                                  mstore(_t41, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t41, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t41
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                            }
                          }
                        }
                        case 1 {
                          _ret := v___uniq_39_
                          leave
                        }
                      }
                      case 1 {
                        _ret := v___uniq_37_
                        leave
                      }
                    }
                    case 1 {
                      _ret := v___uniq_36_
                      leave
                    }
                  }
                }
              }
              case 1 {
                let v___uniq_65_ := mload(add(v___uniq_45_, mul(1, 32)))
                let v___uniq_72_ := 1
                switch lean_obj_tag(v___uniq_72_)
                case 0 {
                  let v___uniq_66_ := v___uniq_45_
                  let v___uniq_67_ := v___uniq_72_
                  switch lean_obj_tag(v___uniq_67_)
                  case 0 {
                    let v___uniq_68_ := v___uniq_66_
                    _ret := v___uniq_68_
                    leave
                  }
                  case 1 {
                    let _t42 := mload(64)
                    mstore(64, add(_t42, mul(2, 32)))
                    mstore(_t42, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                    mstore(add(_t42, mul(1, 32)), v___uniq_65_)
                    let v___uniq_70_ := _t42
                    let v___uniq_68_ := v___uniq_70_
                    _ret := v___uniq_68_
                    leave
                  }
                }
                case 1 {
                  let v___uniq_66_ := or(shl(1, 0), 1)
                  let v___uniq_67_ := v___uniq_72_
                  switch lean_obj_tag(v___uniq_67_)
                  case 0 {
                    let v___uniq_68_ := v___uniq_66_
                    _ret := v___uniq_68_
                    leave
                  }
                  case 1 {
                    let _t43 := mload(64)
                    mstore(64, add(_t43, mul(2, 32)))
                    mstore(_t43, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                    mstore(add(_t43, mul(1, 32)), v___uniq_65_)
                    let v___uniq_70_ := _t43
                    let v___uniq_68_ := v___uniq_70_
                    _ret := v___uniq_68_
                    leave
                  }
                }
              }
            }
            case 1 {
              let v___uniq_45_ := v___uniq_77_
              switch lean_obj_tag(v___uniq_45_)
              case 0 {
                let v___uniq_46_ := mload(add(v___uniq_45_, mul(1, 32)))
                let v___uniq_47_ := f_Nat_decLe(v___uniq_2_, v___uniq_46_)
                switch lean_obj_tag(v___uniq_47_)
                case 0 {
                  revert(shr(1, v___uniq_6_), shr(1, v___uniq_6_))
                  revert(0, 0)
                  let v___uniq_48_ := or(shl(1, 0), 1)
                  _ret := v___uniq_48_
                  leave
                }
                case 1 {
                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_5_))
                  let v___uniq_49_ := or(shl(1, 0), 1)
                  switch lean_obj_tag(v___uniq_49_)
                  case 0 {
                    let v___uniq_50_ := or(shl(1, 32), 1)
                    mstore(shr(1, v___uniq_50_), shr(1, v___uniq_8_))
                    let v___uniq_51_ := or(shl(1, 0), 1)
                    switch lean_obj_tag(v___uniq_51_)
                    case 0 {
                      let v___uniq_52_ := or(shl(1, 64), 1)
                      let _t44 := mload(64)
                      mstore(64, add(_t44, mul(2, 32)))
                      mstore(_t44, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                      mstore(add(_t44, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_52_))), 1))
                      let v___uniq_53_ := _t44
                      switch lean_obj_tag(v___uniq_53_)
                      case 0 {
                        let v___uniq_54_ := mload(add(v___uniq_53_, mul(1, 32)))
                        let v___uniq_55_ := f_Nat_sub(v___uniq_46_, v___uniq_2_)
                        sstore(shr(1, v___uniq_54_), shr(1, v___uniq_55_))
                        let v___uniq_56_ := or(shl(1, 0), 1)
                        let v___uniq_36_ := v___uniq_56_
                        switch lean_obj_tag(v___uniq_36_)
                        case 0 {
                          mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                          let v___uniq_37_ := or(shl(1, 0), 1)
                          switch lean_obj_tag(v___uniq_37_)
                          case 0 {
                            let v___uniq_38_ := or(shl(1, 32), 1)
                            mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                            let v___uniq_39_ := or(shl(1, 0), 1)
                            switch lean_obj_tag(v___uniq_39_)
                            case 0 {
                              let v___uniq_40_ := or(shl(1, 64), 1)
                              let _t45 := mload(64)
                              mstore(64, add(_t45, mul(2, 32)))
                              mstore(_t45, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                              mstore(add(_t45, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                              let v___uniq_41_ := _t45
                              switch lean_obj_tag(v___uniq_41_)
                              case 0 {
                                let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                                let _t46 := mload(64)
                                mstore(64, add(_t46, mul(2, 32)))
                                mstore(_t46, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                mstore(add(_t46, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                                let v___uniq_43_ := _t46
                                let v___uniq_9_ := v___uniq_43_
                                switch lean_obj_tag(v___uniq_9_)
                                case 0 {
                                  let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                  let v___uniq_11_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_11_)
                                  case 0 {
                                    let v___uniq_12_ := or(shl(1, 32), 1)
                                    mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                    let v___uniq_13_ := or(shl(1, 0), 1)
                                    switch lean_obj_tag(v___uniq_13_)
                                    case 0 {
                                      let v___uniq_14_ := or(shl(1, 64), 1)
                                      let _t47 := mload(64)
                                      mstore(64, add(_t47, mul(2, 32)))
                                      mstore(_t47, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t47, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                      let v___uniq_15_ := _t47
                                      switch lean_obj_tag(v___uniq_15_)
                                      case 0 {
                                        let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                        sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                        let v___uniq_18_ := or(shl(1, 0), 1)
                                        _ret := v___uniq_18_
                                        leave
                                      }
                                      case 1 {
                                        let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_26_ := 1
                                        switch lean_obj_tag(v___uniq_26_)
                                        case 0 {
                                          let v___uniq_20_ := v___uniq_15_
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t48 := mload(64)
                                            mstore(64, add(_t48, mul(2, 32)))
                                            mstore(_t48, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t48, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t48
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                        case 1 {
                                          let v___uniq_20_ := or(shl(1, 0), 1)
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t49 := mload(64)
                                            mstore(64, add(_t49, mul(2, 32)))
                                            mstore(_t49, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t49, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t49
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                      }
                                    }
                                    case 1 {
                                      _ret := v___uniq_13_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_11_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  let v___uniq_34_ := 1
                                  switch lean_obj_tag(v___uniq_34_)
                                  case 0 {
                                    let v___uniq_28_ := v___uniq_9_
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t50 := mload(64)
                                      mstore(64, add(_t50, mul(2, 32)))
                                      mstore(_t50, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t50, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t50
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    let v___uniq_28_ := or(shl(1, 0), 1)
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t51 := mload(64)
                                      mstore(64, add(_t51, mul(2, 32)))
                                      mstore(_t51, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t51, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t51
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                }
                              }
                              case 1 {
                                let v___uniq_9_ := v___uniq_41_
                                switch lean_obj_tag(v___uniq_9_)
                                case 0 {
                                  let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                  let v___uniq_11_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_11_)
                                  case 0 {
                                    let v___uniq_12_ := or(shl(1, 32), 1)
                                    mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                    let v___uniq_13_ := or(shl(1, 0), 1)
                                    switch lean_obj_tag(v___uniq_13_)
                                    case 0 {
                                      let v___uniq_14_ := or(shl(1, 64), 1)
                                      let _t52 := mload(64)
                                      mstore(64, add(_t52, mul(2, 32)))
                                      mstore(_t52, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t52, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                      let v___uniq_15_ := _t52
                                      switch lean_obj_tag(v___uniq_15_)
                                      case 0 {
                                        let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                        sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                        let v___uniq_18_ := or(shl(1, 0), 1)
                                        _ret := v___uniq_18_
                                        leave
                                      }
                                      case 1 {
                                        let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                        let v___uniq_26_ := 1
                                        switch lean_obj_tag(v___uniq_26_)
                                        case 0 {
                                          let v___uniq_20_ := v___uniq_15_
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t53 := mload(64)
                                            mstore(64, add(_t53, mul(2, 32)))
                                            mstore(_t53, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t53, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t53
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                        case 1 {
                                          let v___uniq_20_ := or(shl(1, 0), 1)
                                          let v___uniq_21_ := v___uniq_26_
                                          switch lean_obj_tag(v___uniq_21_)
                                          case 0 {
                                            let v___uniq_22_ := v___uniq_20_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                          case 1 {
                                            let _t54 := mload(64)
                                            mstore(64, add(_t54, mul(2, 32)))
                                            mstore(_t54, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                            mstore(add(_t54, mul(1, 32)), v___uniq_19_)
                                            let v___uniq_24_ := _t54
                                            let v___uniq_22_ := v___uniq_24_
                                            _ret := v___uniq_22_
                                            leave
                                          }
                                        }
                                      }
                                    }
                                    case 1 {
                                      _ret := v___uniq_13_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_11_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                  let v___uniq_34_ := 1
                                  switch lean_obj_tag(v___uniq_34_)
                                  case 0 {
                                    let v___uniq_28_ := v___uniq_9_
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t55 := mload(64)
                                      mstore(64, add(_t55, mul(2, 32)))
                                      mstore(_t55, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t55, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t55
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                  case 1 {
                                    let v___uniq_28_ := or(shl(1, 0), 1)
                                    let v___uniq_29_ := v___uniq_34_
                                    switch lean_obj_tag(v___uniq_29_)
                                    case 0 {
                                      let v___uniq_30_ := v___uniq_28_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                    case 1 {
                                      let _t56 := mload(64)
                                      mstore(64, add(_t56, mul(2, 32)))
                                      mstore(_t56, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                      mstore(add(_t56, mul(1, 32)), v___uniq_27_)
                                      let v___uniq_32_ := _t56
                                      let v___uniq_30_ := v___uniq_32_
                                      _ret := v___uniq_30_
                                      leave
                                    }
                                  }
                                }
                              }
                            }
                            case 1 {
                              _ret := v___uniq_39_
                              leave
                            }
                          }
                          case 1 {
                            _ret := v___uniq_37_
                            leave
                          }
                        }
                        case 1 {
                          _ret := v___uniq_36_
                          leave
                        }
                      }
                      case 1 {
                        let v___uniq_57_ := mload(add(v___uniq_53_, mul(1, 32)))
                        let v___uniq_64_ := 1
                        switch lean_obj_tag(v___uniq_64_)
                        case 0 {
                          let v___uniq_58_ := v___uniq_53_
                          let v___uniq_59_ := v___uniq_64_
                          switch lean_obj_tag(v___uniq_59_)
                          case 0 {
                            let v___uniq_60_ := v___uniq_58_
                            _ret := v___uniq_60_
                            leave
                          }
                          case 1 {
                            let _t57 := mload(64)
                            mstore(64, add(_t57, mul(2, 32)))
                            mstore(_t57, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t57, mul(1, 32)), v___uniq_57_)
                            let v___uniq_62_ := _t57
                            let v___uniq_60_ := v___uniq_62_
                            _ret := v___uniq_60_
                            leave
                          }
                        }
                        case 1 {
                          let v___uniq_58_ := or(shl(1, 0), 1)
                          let v___uniq_59_ := v___uniq_64_
                          switch lean_obj_tag(v___uniq_59_)
                          case 0 {
                            let v___uniq_60_ := v___uniq_58_
                            _ret := v___uniq_60_
                            leave
                          }
                          case 1 {
                            let _t58 := mload(64)
                            mstore(64, add(_t58, mul(2, 32)))
                            mstore(_t58, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t58, mul(1, 32)), v___uniq_57_)
                            let v___uniq_62_ := _t58
                            let v___uniq_60_ := v___uniq_62_
                            _ret := v___uniq_60_
                            leave
                          }
                        }
                      }
                    }
                    case 1 {
                      let v___uniq_36_ := v___uniq_51_
                      switch lean_obj_tag(v___uniq_36_)
                      case 0 {
                        mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                        let v___uniq_37_ := or(shl(1, 0), 1)
                        switch lean_obj_tag(v___uniq_37_)
                        case 0 {
                          let v___uniq_38_ := or(shl(1, 32), 1)
                          mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                          let v___uniq_39_ := or(shl(1, 0), 1)
                          switch lean_obj_tag(v___uniq_39_)
                          case 0 {
                            let v___uniq_40_ := or(shl(1, 64), 1)
                            let _t59 := mload(64)
                            mstore(64, add(_t59, mul(2, 32)))
                            mstore(_t59, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t59, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                            let v___uniq_41_ := _t59
                            switch lean_obj_tag(v___uniq_41_)
                            case 0 {
                              let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                              let _t60 := mload(64)
                              mstore(64, add(_t60, mul(2, 32)))
                              mstore(_t60, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                              mstore(add(_t60, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                              let v___uniq_43_ := _t60
                              let v___uniq_9_ := v___uniq_43_
                              switch lean_obj_tag(v___uniq_9_)
                              case 0 {
                                let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                let v___uniq_11_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_11_)
                                case 0 {
                                  let v___uniq_12_ := or(shl(1, 32), 1)
                                  mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                  let v___uniq_13_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_13_)
                                  case 0 {
                                    let v___uniq_14_ := or(shl(1, 64), 1)
                                    let _t61 := mload(64)
                                    mstore(64, add(_t61, mul(2, 32)))
                                    mstore(_t61, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t61, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                    let v___uniq_15_ := _t61
                                    switch lean_obj_tag(v___uniq_15_)
                                    case 0 {
                                      let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                      sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                      let v___uniq_18_ := or(shl(1, 0), 1)
                                      _ret := v___uniq_18_
                                      leave
                                    }
                                    case 1 {
                                      let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_26_ := 1
                                      switch lean_obj_tag(v___uniq_26_)
                                      case 0 {
                                        let v___uniq_20_ := v___uniq_15_
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t62 := mload(64)
                                          mstore(64, add(_t62, mul(2, 32)))
                                          mstore(_t62, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t62, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t62
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                      case 1 {
                                        let v___uniq_20_ := or(shl(1, 0), 1)
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t63 := mload(64)
                                          mstore(64, add(_t63, mul(2, 32)))
                                          mstore(_t63, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t63, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t63
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_13_
                                    leave
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_11_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                let v___uniq_34_ := 1
                                switch lean_obj_tag(v___uniq_34_)
                                case 0 {
                                  let v___uniq_28_ := v___uniq_9_
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t64 := mload(64)
                                    mstore(64, add(_t64, mul(2, 32)))
                                    mstore(_t64, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t64, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t64
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_28_ := or(shl(1, 0), 1)
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t65 := mload(64)
                                    mstore(64, add(_t65, mul(2, 32)))
                                    mstore(_t65, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t65, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t65
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                              }
                            }
                            case 1 {
                              let v___uniq_9_ := v___uniq_41_
                              switch lean_obj_tag(v___uniq_9_)
                              case 0 {
                                let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                                mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                                let v___uniq_11_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_11_)
                                case 0 {
                                  let v___uniq_12_ := or(shl(1, 32), 1)
                                  mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                  let v___uniq_13_ := or(shl(1, 0), 1)
                                  switch lean_obj_tag(v___uniq_13_)
                                  case 0 {
                                    let v___uniq_14_ := or(shl(1, 64), 1)
                                    let _t66 := mload(64)
                                    mstore(64, add(_t66, mul(2, 32)))
                                    mstore(_t66, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t66, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                    let v___uniq_15_ := _t66
                                    switch lean_obj_tag(v___uniq_15_)
                                    case 0 {
                                      let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                      sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                      let v___uniq_18_ := or(shl(1, 0), 1)
                                      _ret := v___uniq_18_
                                      leave
                                    }
                                    case 1 {
                                      let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                      let v___uniq_26_ := 1
                                      switch lean_obj_tag(v___uniq_26_)
                                      case 0 {
                                        let v___uniq_20_ := v___uniq_15_
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t67 := mload(64)
                                          mstore(64, add(_t67, mul(2, 32)))
                                          mstore(_t67, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t67, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t67
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                      case 1 {
                                        let v___uniq_20_ := or(shl(1, 0), 1)
                                        let v___uniq_21_ := v___uniq_26_
                                        switch lean_obj_tag(v___uniq_21_)
                                        case 0 {
                                          let v___uniq_22_ := v___uniq_20_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                        case 1 {
                                          let _t68 := mload(64)
                                          mstore(64, add(_t68, mul(2, 32)))
                                          mstore(_t68, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                          mstore(add(_t68, mul(1, 32)), v___uniq_19_)
                                          let v___uniq_24_ := _t68
                                          let v___uniq_22_ := v___uniq_24_
                                          _ret := v___uniq_22_
                                          leave
                                        }
                                      }
                                    }
                                  }
                                  case 1 {
                                    _ret := v___uniq_13_
                                    leave
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_11_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                                let v___uniq_34_ := 1
                                switch lean_obj_tag(v___uniq_34_)
                                case 0 {
                                  let v___uniq_28_ := v___uniq_9_
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t69 := mload(64)
                                    mstore(64, add(_t69, mul(2, 32)))
                                    mstore(_t69, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t69, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t69
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                                case 1 {
                                  let v___uniq_28_ := or(shl(1, 0), 1)
                                  let v___uniq_29_ := v___uniq_34_
                                  switch lean_obj_tag(v___uniq_29_)
                                  case 0 {
                                    let v___uniq_30_ := v___uniq_28_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                  case 1 {
                                    let _t70 := mload(64)
                                    mstore(64, add(_t70, mul(2, 32)))
                                    mstore(_t70, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                    mstore(add(_t70, mul(1, 32)), v___uniq_27_)
                                    let v___uniq_32_ := _t70
                                    let v___uniq_30_ := v___uniq_32_
                                    _ret := v___uniq_30_
                                    leave
                                  }
                                }
                              }
                            }
                          }
                          case 1 {
                            _ret := v___uniq_39_
                            leave
                          }
                        }
                        case 1 {
                          _ret := v___uniq_37_
                          leave
                        }
                      }
                      case 1 {
                        _ret := v___uniq_36_
                        leave
                      }
                    }
                  }
                  case 1 {
                    let v___uniq_36_ := v___uniq_49_
                    switch lean_obj_tag(v___uniq_36_)
                    case 0 {
                      mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                      let v___uniq_37_ := or(shl(1, 0), 1)
                      switch lean_obj_tag(v___uniq_37_)
                      case 0 {
                        let v___uniq_38_ := or(shl(1, 32), 1)
                        mstore(shr(1, v___uniq_38_), shr(1, v___uniq_8_))
                        let v___uniq_39_ := or(shl(1, 0), 1)
                        switch lean_obj_tag(v___uniq_39_)
                        case 0 {
                          let v___uniq_40_ := or(shl(1, 64), 1)
                          let _t71 := mload(64)
                          mstore(64, add(_t71, mul(2, 32)))
                          mstore(_t71, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                          mstore(add(_t71, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_40_))), 1))
                          let v___uniq_41_ := _t71
                          switch lean_obj_tag(v___uniq_41_)
                          case 0 {
                            let v___uniq_42_ := mload(add(v___uniq_41_, mul(1, 32)))
                            let _t72 := mload(64)
                            mstore(64, add(_t72, mul(2, 32)))
                            mstore(_t72, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                            mstore(add(_t72, mul(1, 32)), or(shl(1, sload(shr(1, v___uniq_42_))), 1))
                            let v___uniq_43_ := _t72
                            let v___uniq_9_ := v___uniq_43_
                            switch lean_obj_tag(v___uniq_9_)
                            case 0 {
                              let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                              mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                              let v___uniq_11_ := or(shl(1, 0), 1)
                              switch lean_obj_tag(v___uniq_11_)
                              case 0 {
                                let v___uniq_12_ := or(shl(1, 32), 1)
                                mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                let v___uniq_13_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_13_)
                                case 0 {
                                  let v___uniq_14_ := or(shl(1, 64), 1)
                                  let _t73 := mload(64)
                                  mstore(64, add(_t73, mul(2, 32)))
                                  mstore(_t73, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t73, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                  let v___uniq_15_ := _t73
                                  switch lean_obj_tag(v___uniq_15_)
                                  case 0 {
                                    let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                    sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                    let v___uniq_18_ := or(shl(1, 0), 1)
                                    _ret := v___uniq_18_
                                    leave
                                  }
                                  case 1 {
                                    let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_26_ := 1
                                    switch lean_obj_tag(v___uniq_26_)
                                    case 0 {
                                      let v___uniq_20_ := v___uniq_15_
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t74 := mload(64)
                                        mstore(64, add(_t74, mul(2, 32)))
                                        mstore(_t74, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t74, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t74
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                    case 1 {
                                      let v___uniq_20_ := or(shl(1, 0), 1)
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t75 := mload(64)
                                        mstore(64, add(_t75, mul(2, 32)))
                                        mstore(_t75, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t75, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t75
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_13_
                                  leave
                                }
                              }
                              case 1 {
                                _ret := v___uniq_11_
                                leave
                              }
                            }
                            case 1 {
                              let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                              let v___uniq_34_ := 1
                              switch lean_obj_tag(v___uniq_34_)
                              case 0 {
                                let v___uniq_28_ := v___uniq_9_
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t76 := mload(64)
                                  mstore(64, add(_t76, mul(2, 32)))
                                  mstore(_t76, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t76, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t76
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_28_ := or(shl(1, 0), 1)
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t77 := mload(64)
                                  mstore(64, add(_t77, mul(2, 32)))
                                  mstore(_t77, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t77, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t77
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                            }
                          }
                          case 1 {
                            let v___uniq_9_ := v___uniq_41_
                            switch lean_obj_tag(v___uniq_9_)
                            case 0 {
                              let v___uniq_10_ := mload(add(v___uniq_9_, mul(1, 32)))
                              mstore(shr(1, v___uniq_6_), shr(1, v___uniq_1_))
                              let v___uniq_11_ := or(shl(1, 0), 1)
                              switch lean_obj_tag(v___uniq_11_)
                              case 0 {
                                let v___uniq_12_ := or(shl(1, 32), 1)
                                mstore(shr(1, v___uniq_12_), shr(1, v___uniq_8_))
                                let v___uniq_13_ := or(shl(1, 0), 1)
                                switch lean_obj_tag(v___uniq_13_)
                                case 0 {
                                  let v___uniq_14_ := or(shl(1, 64), 1)
                                  let _t78 := mload(64)
                                  mstore(64, add(_t78, mul(2, 32)))
                                  mstore(_t78, or(or(or(0, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t78, mul(1, 32)), or(shl(1, keccak256(shr(1, v___uniq_6_), shr(1, v___uniq_14_))), 1))
                                  let v___uniq_15_ := _t78
                                  switch lean_obj_tag(v___uniq_15_)
                                  case 0 {
                                    let v___uniq_16_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_17_ := f_Nat_add(v___uniq_10_, v___uniq_2_)
                                    sstore(shr(1, v___uniq_16_), shr(1, v___uniq_17_))
                                    let v___uniq_18_ := or(shl(1, 0), 1)
                                    _ret := v___uniq_18_
                                    leave
                                  }
                                  case 1 {
                                    let v___uniq_19_ := mload(add(v___uniq_15_, mul(1, 32)))
                                    let v___uniq_26_ := 1
                                    switch lean_obj_tag(v___uniq_26_)
                                    case 0 {
                                      let v___uniq_20_ := v___uniq_15_
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t79 := mload(64)
                                        mstore(64, add(_t79, mul(2, 32)))
                                        mstore(_t79, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t79, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t79
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                    case 1 {
                                      let v___uniq_20_ := or(shl(1, 0), 1)
                                      let v___uniq_21_ := v___uniq_26_
                                      switch lean_obj_tag(v___uniq_21_)
                                      case 0 {
                                        let v___uniq_22_ := v___uniq_20_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                      case 1 {
                                        let _t80 := mload(64)
                                        mstore(64, add(_t80, mul(2, 32)))
                                        mstore(_t80, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                        mstore(add(_t80, mul(1, 32)), v___uniq_19_)
                                        let v___uniq_24_ := _t80
                                        let v___uniq_22_ := v___uniq_24_
                                        _ret := v___uniq_22_
                                        leave
                                      }
                                    }
                                  }
                                }
                                case 1 {
                                  _ret := v___uniq_13_
                                  leave
                                }
                              }
                              case 1 {
                                _ret := v___uniq_11_
                                leave
                              }
                            }
                            case 1 {
                              let v___uniq_27_ := mload(add(v___uniq_9_, mul(1, 32)))
                              let v___uniq_34_ := 1
                              switch lean_obj_tag(v___uniq_34_)
                              case 0 {
                                let v___uniq_28_ := v___uniq_9_
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t81 := mload(64)
                                  mstore(64, add(_t81, mul(2, 32)))
                                  mstore(_t81, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t81, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t81
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                              case 1 {
                                let v___uniq_28_ := or(shl(1, 0), 1)
                                let v___uniq_29_ := v___uniq_34_
                                switch lean_obj_tag(v___uniq_29_)
                                case 0 {
                                  let v___uniq_30_ := v___uniq_28_
                                  _ret := v___uniq_30_
                                  leave
                                }
                                case 1 {
                                  let _t82 := mload(64)
                                  mstore(64, add(_t82, mul(2, 32)))
                                  mstore(_t82, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                                  mstore(add(_t82, mul(1, 32)), v___uniq_27_)
                                  let v___uniq_32_ := _t82
                                  let v___uniq_30_ := v___uniq_32_
                                  _ret := v___uniq_30_
                                  leave
                                }
                              }
                            }
                          }
                        }
                        case 1 {
                          _ret := v___uniq_39_
                          leave
                        }
                      }
                      case 1 {
                        _ret := v___uniq_37_
                        leave
                      }
                    }
                    case 1 {
                      _ret := v___uniq_36_
                      leave
                    }
                  }
                }
              }
              case 1 {
                let v___uniq_65_ := mload(add(v___uniq_45_, mul(1, 32)))
                let v___uniq_72_ := 1
                switch lean_obj_tag(v___uniq_72_)
                case 0 {
                  let v___uniq_66_ := v___uniq_45_
                  let v___uniq_67_ := v___uniq_72_
                  switch lean_obj_tag(v___uniq_67_)
                  case 0 {
                    let v___uniq_68_ := v___uniq_66_
                    _ret := v___uniq_68_
                    leave
                  }
                  case 1 {
                    let _t83 := mload(64)
                    mstore(64, add(_t83, mul(2, 32)))
                    mstore(_t83, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                    mstore(add(_t83, mul(1, 32)), v___uniq_65_)
                    let v___uniq_70_ := _t83
                    let v___uniq_68_ := v___uniq_70_
                    _ret := v___uniq_68_
                    leave
                  }
                }
                case 1 {
                  let v___uniq_66_ := or(shl(1, 0), 1)
                  let v___uniq_67_ := v___uniq_72_
                  switch lean_obj_tag(v___uniq_67_)
                  case 0 {
                    let v___uniq_68_ := v___uniq_66_
                    _ret := v___uniq_68_
                    leave
                  }
                  case 1 {
                    let _t84 := mload(64)
                    mstore(64, add(_t84, mul(2, 32)))
                    mstore(_t84, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
                    mstore(add(_t84, mul(1, 32)), v___uniq_65_)
                    let v___uniq_70_ := _t84
                    let v___uniq_68_ := v___uniq_70_
                    _ret := v___uniq_68_
                    leave
                  }
                }
              }
            }
          }
          case 1 {
            _ret := v___uniq_75_
            leave
          }
        }
        case 1 {
          _ret := v___uniq_7_
          leave
        }
      }
      case 1 {
        let v___uniq_80_ := mload(add(v___uniq_4_, mul(1, 32)))
        let v___uniq_87_ := 1
        switch lean_obj_tag(v___uniq_87_)
        case 0 {
          let v___uniq_81_ := v___uniq_4_
          let v___uniq_82_ := v___uniq_87_
          switch lean_obj_tag(v___uniq_82_)
          case 0 {
            let v___uniq_83_ := v___uniq_81_
            _ret := v___uniq_83_
            leave
          }
          case 1 {
            let _t85 := mload(64)
            mstore(64, add(_t85, mul(2, 32)))
            mstore(_t85, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t85, mul(1, 32)), v___uniq_80_)
            let v___uniq_85_ := _t85
            let v___uniq_83_ := v___uniq_85_
            _ret := v___uniq_83_
            leave
          }
        }
        case 1 {
          let v___uniq_81_ := or(shl(1, 0), 1)
          let v___uniq_82_ := v___uniq_87_
          switch lean_obj_tag(v___uniq_82_)
          case 0 {
            let v___uniq_83_ := v___uniq_81_
            _ret := v___uniq_83_
            leave
          }
          case 1 {
            let _t86 := mload(64)
            mstore(64, add(_t86, mul(2, 32)))
            mstore(_t86, or(or(or(1, shl(8, 1)), shl(16, 0)), shl(32, 1)))
            mstore(add(_t86, mul(1, 32)), v___uniq_80_)
            let v___uniq_85_ := _t86
            let v___uniq_83_ := v___uniq_85_
            _ret := v___uniq_83_
            leave
          }
        }
      }
      leave
    }
    function f_SimpleToken_transfer___boxed(v___uniq_1_, v___uniq_2_, v___uniq_3_) -> _ret {
      let v___uniq_4_ := f_SimpleToken_transfer(v___uniq_1_, v___uniq_2_)
      _ret := v___uniq_4_
      leave
      leave
    }
  }
}
