module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Packed integer SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section
instance instMinBitVecCompat {n : Nat} : Min (BitVec n) := minOfLe
instance instMaxBitVecCompat {n : Nat} : Max (BitVec n) := maxOfLe

inductive SimdInt
  | paddb | paddw | paddd | paddq
  | paddsb | paddsw | paddusb | paddusw
  | psubb | psubw | psubd | psubq
  | psubsb | psubsw | psubusb | psubusw
  | pmullw | pmulhw | pmulhuw | pmulld
  | pmuludq | pmuldq
  | pmaddwd | pmaddubsw | pmulhrsw
  | pavgb | pavgw
  | pminub | pminuw | pminud | pminsb | pminsw | pminsd
  | pmaxub | pmaxuw | pmaxud | pmaxsb | pmaxsw | pmaxsd
  | psadbw
  | psignb | psignw | psignd
  | phaddw | phaddd | phaddsw
  | phsubw | phsubd | phsubsw
  | psllvd | psllvq | psrlvd | psrlvq | psravd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInt := ⟨mnemonics% SimdInt⟩

/-- Signed minimum and maximum (`min`/`max` on `BitVec` are unsigned). -/
def smin {k} (a b : BitVec k) : BitVec k := if a.sle b then a else b
def smax {k} (a b : BitVec k) : BitVec k := if a.sle b then b else a

/-- `a` negated, zeroed, or kept, as `b` is negative, zero, or positive. -/
def psign {k} (a b : BitVec k) : BitVec k := if b.toInt < 0 then -a else if b == 0 then 0 else a

/-- The operation on one 128-bit lane. -/
def SimdInt.interp : SimdInt → BitVec 128 → BitVec 128 → BitVec 128
  | .paddb => .map2 8 (· + ·) | .paddw => .map2 16 (· + ·)
  | .paddd => .map2 32 (· + ·) | .paddq => .map2 64 (· + ·)
  | .paddsb => .map2 8 fun a b => .satS 8 (a.toInt + b.toInt)
  | .paddsw => .map2 16 fun a b => .satS 16 (a.toInt + b.toInt)
  | .paddusb => .map2 8 fun a b => .satU 8 (a.toNat + b.toNat)
  | .paddusw => .map2 16 fun a b => .satU 16 (a.toNat + b.toNat)
  | .psubb => .map2 8 (· - ·) | .psubw => .map2 16 (· - ·)
  | .psubd => .map2 32 (· - ·) | .psubq => .map2 64 (· - ·)
  | .psubsb => .map2 8 fun a b => .satS 8 (a.toInt - b.toInt)
  | .psubsw => .map2 16 fun a b => .satS 16 (a.toInt - b.toInt)
  | .psubusb => .map2 8 fun a b => .satU 8 ((a.toNat : Int) - (b.toNat : Int))
  | .psubusw => .map2 16 fun a b => .satU 16 ((a.toNat : Int) - (b.toNat : Int))
  | .pmullw => .map2 16 (· * ·)
  | .pmulhw => .map2 16 fun a b => BitVec.extractLsb' 16 16 (BitVec.ofInt 32 (a.toInt * b.toInt))
  | .pmulhuw => .map2 16 fun a b => BitVec.extractLsb' 16 16 (BitVec.ofNat 32 (a.toNat * b.toNat))
  | .pmulld => .map2 32 (· * ·)
  | .pmuludq => fun a b => .ofLanes 128 64 fun i =>
      BitVec.ofNat 64 ((a.lane 32 (2 * i)).toNat * (b.lane 32 (2 * i)).toNat)
  | .pmuldq => fun a b => .ofLanes 128 64 fun i =>
      BitVec.ofInt 64 ((a.lane 32 (2 * i)).toInt * (b.lane 32 (2 * i)).toInt)
  | .pmaddwd => fun a b => .ofLanes 128 32 fun i =>
      BitVec.ofInt 32 ((a.lane 16 (2 * i)).toInt * (b.lane 16 (2 * i)).toInt +
                       (a.lane 16 (2 * i + 1)).toInt * (b.lane 16 (2 * i + 1)).toInt)
  | .pmaddubsw => fun a b => .ofLanes 128 16 fun i =>
      .satS 16 ((a.lane 8 (2 * i)).toNat * (b.lane 8 (2 * i)).toInt +
                (a.lane 8 (2 * i + 1)).toNat * (b.lane 8 (2 * i + 1)).toInt)
  | .pmulhrsw => .map2 16 fun a b =>
      let prod := a.toInt * b.toInt
      .extractLsb' 1 16 (BitVec.ofInt 32 ((prod >>> 14) + 1))
  | .pavgb => .map2 8 fun a b => .ofNat 8 ((a.toNat + b.toNat + 1) / 2)
  | .pavgw => .map2 16 fun a b => .ofNat 16 ((a.toNat + b.toNat + 1) / 2)
  | .pminub => .map2 8 min | .pminuw => .map2 16 min | .pminud => .map2 32 min
  | .pminsb => .map2 8 smin | .pminsw => .map2 16 smin | .pminsd => .map2 32 smin
  | .pmaxub => .map2 8 max | .pmaxuw => .map2 16 max | .pmaxud => .map2 32 max
  | .pmaxsb => .map2 8 smax | .pmaxsw => .map2 16 smax | .pmaxsd => .map2 32 smax
  | .psadbw => fun a b => .ofLanes 128 64 fun i =>
      let sum := (List.range 8).foldl (fun acc j =>
        let diff : Int := (a.lane 8 (i * 8 + j)).toNat - (b.lane 8 (i * 8 + j)).toNat
        acc + diff.natAbs) 0
      BitVec.ofNat 64 sum
  | .psignb => .map2 8 psign | .psignw => .map2 16 psign | .psignd => .map2 32 psign
  | .phaddw => .hop 16 (· + ·)
  | .phaddd => .hop 32 (· + ·)
  | .phaddsw => .hop 16 fun a b => .satS 16 (a.toInt + b.toInt)
  | .phsubw => .hop 16 (· - ·)
  | .phsubd => .hop 32 (· - ·)
  | .phsubsw => .hop 16 fun a b => .satS 16 (a.toInt - b.toInt)
  -- Counts are bounded: shifting left by a huge `Nat` would build a huge intermediate number.
  | .psllvd => .map2 32 fun a b => a <<< min b.toNat 32
  | .psllvq => .map2 64 fun a b => a <<< min b.toNat 64
  | .psrlvd => .map2 32 fun a b => a >>> b.toNat
  | .psrlvq => .map2 64 fun a b => a >>> b.toNat
  | .psravd => .map2 32 fun a b => a.sshiftRight b.toNat
