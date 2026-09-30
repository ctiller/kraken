module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Packed integer SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

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
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInt := ⟨mnemonics% SimdInt⟩

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
  | .pminub => .map2 8 fun a b => if a.toNat ≤ b.toNat then a else b
  | .pminuw => .map2 16 fun a b => if a.toNat ≤ b.toNat then a else b
  | .pminud => .map2 32 fun a b => if a.toNat ≤ b.toNat then a else b
  | .pminsb => .map2 8 fun a b => if a.toInt ≤ b.toInt then a else b
  | .pminsw => .map2 16 fun a b => if a.toInt ≤ b.toInt then a else b
  | .pminsd => .map2 32 fun a b => if a.toInt ≤ b.toInt then a else b
  | .pmaxub => .map2 8 fun a b => if a.toNat ≥ b.toNat then a else b
  | .pmaxuw => .map2 16 fun a b => if a.toNat ≥ b.toNat then a else b
  | .pmaxud => .map2 32 fun a b => if a.toNat ≥ b.toNat then a else b
  | .pmaxsb => .map2 8 fun a b => if a.toInt ≥ b.toInt then a else b
  | .pmaxsw => .map2 16 fun a b => if a.toInt ≥ b.toInt then a else b
  | .pmaxsd => .map2 32 fun a b => if a.toInt ≥ b.toInt then a else b
  | .psadbw => fun a b => .ofLanes 128 64 fun i =>
      let sum := (List.range 8).foldl (fun acc j =>
        let diff : Int := (a.lane 8 (i * 8 + j)).toNat - (b.lane 8 (i * 8 + j)).toNat
        acc + diff.natAbs) 0
      BitVec.ofNat 64 sum
  | .psignb => .map2 8 fun a b => if b.toInt < 0 then -a else if b == 0 then 0 else a
  | .psignw => .map2 16 fun a b => if b.toInt < 0 then -a else if b == 0 then 0 else a
  | .psignd => .map2 32 fun a b => if b.toInt < 0 then -a else if b == 0 then 0 else a
  | .phaddw => fun a b => .ofLanes 128 16 fun i =>
      if i < 4 then a.lane 16 (2 * i) + a.lane 16 (2 * i + 1)
      else b.lane 16 (2 * (i - 4)) + b.lane 16 (2 * (i - 4) + 1)
  | .phaddd => fun a b => .ofLanes 128 32 fun i =>
      if i < 2 then a.lane 32 (2 * i) + a.lane 32 (2 * i + 1)
      else b.lane 32 (2 * (i - 2)) + b.lane 32 (2 * (i - 2) + 1)
  | .phaddsw => fun a b => .ofLanes 128 16 fun i =>
      let (v1, v2) := if i < 4
        then ((a.lane 16 (2 * i)).toInt, (a.lane 16 (2 * i + 1)).toInt)
        else ((b.lane 16 (2 * (i - 4))).toInt, (b.lane 16 (2 * (i - 4) + 1)).toInt)
      .satS 16 (v1 + v2)
  | .phsubw => fun a b => .ofLanes 128 16 fun i =>
      if i < 4 then a.lane 16 (2 * i) - a.lane 16 (2 * i + 1)
      else b.lane 16 (2 * (i - 4)) - b.lane 16 (2 * (i - 4) + 1)
  | .phsubd => fun a b => .ofLanes 128 32 fun i =>
      if i < 2 then a.lane 32 (2 * i) - a.lane 32 (2 * i + 1)
      else b.lane 32 (2 * (i - 2)) - b.lane 32 (2 * (i - 2) + 1)
  | .phsubsw => fun a b => .ofLanes 128 16 fun i =>
      let (v1, v2) := if i < 4
        then ((a.lane 16 (2 * i)).toInt, (a.lane 16 (2 * i + 1)).toInt)
        else ((b.lane 16 (2 * (i - 4))).toInt, (b.lane 16 (2 * (i - 4) + 1)).toInt)
      .satS 16 (v1 - v2)
