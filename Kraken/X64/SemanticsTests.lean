module

import Kraken.X64.Semantics
meta import Kraken.X64.Semantics

/-! Concrete-evaluation tests of semantics that the native asm tests can't observe (e.g. zmm
registers, which `asm_tests.py` doesn't compare). -/

/-- Runs `e`, granting every access check; `none` on a fault, an access outside the data memory,
`undefined`, or anything unimplemented. -/
private partial def run : Effects → Option MachineData
  | .done (s, _) => some s
  | .require_read_access _ _ ok | .require_write_access _ _ ok | .require_exec_access _ ok => run (ok ())
  | _ => none

/-- The value that the SIMD source operand `(%rsp)` with `bytes?` bytes gives a zmm destination,
where `stack` (at `rsp`) is the only mapped memory. -/
private def loadZmm (bytes? : Option Nat) (stack : List UInt8) : Option (BitVec 512) :=
  let : Labels := ⟨fun _ => 0⟩
  let : AddressSize := ⟨.W64⟩
  let rsp : UInt64 := 0x7ffecafee000
  let s : MachineData := { regs := { rsp }, dmem := stack.At rsp.toBitVec }
  let src : AvxRegOrMem .W512 := .mem { base := some (.reg .rsp), idx := none }
  (run (src.interpSimd bytes? s ⟨0, 0⟩ (legacy := false) fun v s =>
    .done (s.setAvxReg (.zmm .mm0) v, 0))).map (·.zmms.zmm0)

/-- The `n`-bit value whose `bits`-bit lanes are `f 0, f 1, ...`. -/
private def lanes (n bits count : Nat) (f : Nat → Nat) : BitVec n :=
  (List.range count).foldl (fun acc i => acc ||| (BitVec.ofNat n (f i) <<< (bits * i))) 0

/-- Bytes 1, 2, ..., 32. -/
private def bytes32 : List UInt8 := (List.range 32).map (·.toUInt8 + 1)

/-- The widening operations, whose memory source is half as wide as the destination. -/
private def widening : List SimdUnOp :=
  [.pmovzxbw, .pmovsxbw, .pmovzxwd, .pmovsxwd, .pmovzxdq, .pmovsxdq, .cvtdq2pd, .cvtps2pd, .cvtph2ps]

-- With a zmm destination, their memory source (e.g. `vpmovzxbw (%rsp), %zmm0`) is 32 bytes; it
-- used to be read as 8.
#guard widening.all fun op => loadZmm (op.memBytes? 64) bytes32 == some (lanes 512 8 32 (· + 1))
-- ... so a 31-byte mapping doesn't suffice.
#guard widening.all fun op => loadZmm (op.memBytes? 64) (bytes32.take 31) == none
-- The other sizes.
#guard [1, 2, 4, 8, 16].all fun n => loadZmm (some n) bytes32 == some (lanes 512 8 n (· + 1))
#guard loadZmm (some 3) bytes32 == none

/-! dpps/dppd: the SDM leaves which NaNs propagate, and where they land, implementation
dependent, so any NaN in a lane's sum makes the result undefined. -/

private def f32s (xs : List Nat) : BitVec 128 := lanes 128 32 xs.length (xs.getD · 0)
private def f64s (xs : List Nat) : BitVec 128 := lanes 128 64 xs.length (xs.getD · 0)
private def one32 := 0x3f800000
private def inf32 := 0x7f800000
private def one64 := 0x3ff0000000000000

-- One NaN product.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00001, one32, one32, one32]) (f32s [one32, one32, one32, one32]) 0xf1
#guard SimdBinImmOp.dppd.resultUndefined (f64s [0x7ff8000000000001, one64]) (f64s [one64, one64]) 0x31
-- No NaN product, but `+inf + -inf`.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [inf32, inf32 + 0x80000000, 0, 0]) (f32s [one32, one32, one32, one32]) 0x31
-- `inf * 0`.
#guard SimdBinImmOp.dppd.resultUndefined (f64s [0x7ff0000000000000, 0]) (f64s [0, 0]) 0x11
-- In the upper 128-bit lane only.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00000] ++ f32s [one32]) (f32s [one32] ++ f32s [one32]) 0xf1
-- Defined: no NaN, the NaN is not selected, or no destination element is written.
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [inf32, one32, 0, 0]) (f32s [one32, one32, one32, one32]) 0xf1
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [one32, 0x7fc00000]) (f32s [one32, one32]) 0x11
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00000]) (f32s [one32]) 0xf0
