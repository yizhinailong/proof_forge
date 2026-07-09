/-
Evm.AbiEncode layout smoke: pad32, bytes, Call[], aggregate / aggregate3.
-/
import ProofForge.Backend.Evm.AbiEncode
import ProofForge.Protocols.Evm.Multicall

namespace ProofForge.Tests.AbiEncode

open ProofForge.Backend.Evm.AbiEncode
open ProofForge.Protocols.Evm.Multicall

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def main : IO UInt32 := do
  require (ProofForge.Backend.Evm.AbiEncode.catalogId == "evm.abi_encode") "catalog id"
  require (pad32 0 == 0) "pad32 0"
  require (pad32 1 == 32) "pad32 1"
  require (pad32 32 == 32) "pad32 32"
  require (pad32 33 == 64) "pad32 33"

  -- Empty bytes: length 0 only → size 32
  let (bStores, bEnd) := encodeBytesAt 0 #[]
  require (bEnd == 32) "empty bytes size"
  require (planWordAt? { stores := bStores, size := bEnd } 0 == some 0)
    "empty bytes length word"

  -- Four bytes of data → length + one data word
  let (b2, e2) := encodeBytesAt 0 #[1, 2, 3, 4]
  require (e2 == 64) "4 bytes → 64 total"
  require (planWordAt? { stores := b2, size := e2 } 0 == some 4) "len=4"

  -- Empty aggregate: head 0x20, array len 0 at 0x20 → size 0x40
  let empty := encodeAggregate #[]
  require (planWordAt? empty 0 == some 0x20) "aggregate head offset"
  require (planWordAt? empty 0x20 == some 0) "empty array length"
  require (empty.size == 0x40) s!"empty aggregate size got {empty.size}"

  -- One Call: target=0xab, empty data
  let c1 := mkCall 0xab #[]
  let one := encodeAggregate #[c1]
  require (planWordAt? one 0 == some 0x20) "one head"
  require (planWordAt? one 0x20 == some 1) "one length"
  -- offset table at 0x40: first element offset relative to array base 0x20
  -- first tuple at 0x20+0x20 = 0x40 from region? arrayBase=0x20, offsets at 0x40,
  -- first offset value = (tupleStart - 0x20). tupleStart = 0x20+32+32 = 0x60
  -- offset word at 0x40 should be 0x40 (0x60-0x20)
  require (planWordAt? one 0x40 == some 0x40) s!"call offset got {planWordAt? one 0x40}"
  require (planWordAt? one 0x60 == some 0xab) "call target"
  require (planWordAt? one 0x80 == some 0x40) "bytes rel offset in Call"
  require (planWordAt? one 0xa0 == some 0) "empty bytes len"
  require (one.size >= 0xc0) s!"one call min size {one.size}"

  -- Call with selector-only data (transfer-like 4 bytes)
  let data := innerCallData 0xa9059cbb #[]
  require (data.size == 4) s!"selector-only data len {data.size}"
  require (data[0]! == 0xa9 && data[3]! == 0xbb) "selector bytes order"
  let c2 := mkCall 0x11 data
  let p2 := encodeAggregate #[c2]
  require (planWordAt? p2 0x20 == some 1) "p2 length"
  require (planWordAt? p2 0x60 == some 0x11) "p2 target"
  -- bytes length at call base+0x40
  let callBase := 0x60
  require (planWordAt? p2 (callBase + 0x40) == some 4) "inner data len 4"

  -- aggregate3 empty
  let a3 := encodeAggregate3 #[]
  require (planWordAt? a3 0 == some 0x20) "a3 head"
  require (planWordAt? a3 0x20 == some 0) "a3 empty len"

  -- Call3 with allowFailure
  let c3 := mkCall3 0xcd true #[]
  let p3 := encodeAggregate3 #[c3]
  require (planWordAt? p3 0x20 == some 1) "c3 len"
  require (planWordAt? p3 0x60 == some 0xcd) "c3 target"
  require (planWordAt? p3 0x80 == some 1) "c3 allowFailure true"

  -- Two calls
  let two := encodeAggregate #[mkCall 1 #[], mkCall 2 #[]]
  require (planWordAt? two 0x20 == some 2) "two length"
  require (planWordAt? two 0x40 == some 0x60) "first offset"  -- 0x20+0x40? 
  -- offsetsBase = 0x40, n=2, tuplesStart = 0x40+64 = 0x80
  -- first offset = 0x80-0x20 = 0x60
  require (planWordAt? two 0x40 == some 0x60) "first elem offset"
  require ((planWordAt? two 0x60).isSome) "second offset present"

  IO.println s!"abi-encode: ok (aggregate size empty={empty.size} one={one.size} two={two.size})"
  pure 0

end ProofForge.Tests.AbiEncode

def main : IO UInt32 :=
  ProofForge.Tests.AbiEncode.main
