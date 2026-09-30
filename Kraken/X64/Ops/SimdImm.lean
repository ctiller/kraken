module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SimdFpCmp
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX operations with an 8-bit immediate, on the whole vector:
* unary `op $imm, src, dst` (`AvxOperation.sseUnImm`/`.vexUnImm`): `dst := op(src, imm)`;
* binary `op $imm, src, dst` (`AvxOperation.sseImm`: `dst := op(dst, src, imm)`) and
  `vop $imm, src2, src1, dst` (`AvxOperation.vexImm`: `dst := op(src1, src2, imm)`). -/

@[expose] public section

inductive SimdUnImmOp
  | pshufd
  | pshufhw | pshuflw
  | permq | permpd
  | permilps | permilpd
  | roundps | roundpd
  | aeskeygenassist
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdUnImmOp := ⟨mnemonics% SimdUnImmOp⟩

/-- Element `i` of a vector of `k`-bit elements, where `sel` picks among the 4 elements of the group
of 4 containing `i`. -/
def BitVec.pick4 {n} (k : Nat) (x : BitVec n) (i sel : Nat) : BitVec k := x.lane k (i / 4 * 4 + sel % 4)

def roundFloat32 (mode : Nat) (a : BitVec 32) : BitVec 32 :=
  if a.extractLsb' 23 8 == 0xff#8 then
    if a.extractLsb' 0 23 != 0#23 then a ||| 0x400000#32
    else a
  else
    let f := a.toFloat32
    let isNeg := a.msb
    let absF := if isNeg then -f else f
    let absFloor := Float32.floor absF
    let absDiff := absF - absFloor
    let absRoundNearestEven :=
      if absDiff < 0.5 then absFloor
      else if absDiff > 0.5 then absFloor + 1.0
      else if Float32.floor (absFloor / 2.0) * 2.0 == absFloor then absFloor
      else absFloor + 1.0
    let r := match mode with
      | 0 => if isNeg then -absRoundNearestEven else absRoundNearestEven
      | 1 => Float32.floor f
      | 2 => Float32.ceil f
      | _ => if isNeg then -absFloor else absFloor
    let res := r.toBitVec
    if res == 0#32 && isNeg then 0x80000000#32 else res

def roundFloat64 (mode : Nat) (a : BitVec 64) : BitVec 64 :=
  if a.extractLsb' 52 11 == 0x7ff#11 then
    if a.extractLsb' 0 52 != 0#52 then a ||| 0x8000000000000#64
    else a
  else
    let f := a.toFloat
    let isNeg := a.msb
    let absF := if isNeg then -f else f
    let absFloor := Float.floor absF
    let absDiff := absF - absFloor
    let absRoundNearestEven :=
      if absDiff < 0.5 then absFloor
      else if absDiff > 0.5 then absFloor + 1.0
      else if Float.floor (absFloor / 2.0) * 2.0 == absFloor then absFloor
      else absFloor + 1.0
    let r := match mode with
      | 0 => if isNeg then -absRoundNearestEven else absRoundNearestEven
      | 1 => Float.floor f
      | 2 => Float.ceil f
      | _ => if isNeg then -absFloor else absFloor
    let res := r.toBitVec
    if res == 0#64 && isNeg then 0x8000000000000000#64 else res

def roundImmMode (imm : BitVec 8) : Nat :=
  if (imm >>> 2).getLsbD 0 then 0 else (imm &&& 3).toNat

def SimdUnImmOp.interp {n} : SimdUnImmOp → BitVec n → BitVec 8 → BitVec n
  | .pshufd, a, imm => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .pshuflw, a, imm => .ofLanes n 16 fun i =>
    if i % 8 < 4 then a.pick4 16 i (imm >>> (i % 4 * 2)).toNat else a.lane 16 i
  | .pshufhw, a, imm => .ofLanes n 16 fun i =>
    if i % 8 >= 4 then a.pick4 16 i (imm >>> ((i % 4) * 2)).toNat else a.lane 16 i
  | .permq, a, imm | .permpd, a, imm => .ofLanes n 64 fun i => a.lane 64 (imm >>> (i % 4 * 2) &&& 3).toNat
  | .permilps, a, imm => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .permilpd, a, imm => .ofLanes n 64 fun i => a.lane 64 (i / 2 * 2 + (imm >>> i).toNat % 2)
  | .roundps, a, imm => .map1 32 (roundFloat32 (roundImmMode imm)) a
  | .roundpd, a, imm => .map1 64 (roundFloat64 (roundImmMode imm)) a
  | .aeskeygenassist, a, imm => .map1 128 (aesKeygenAssist imm) a

inductive SimdBinImmOp
  | shufps | shufpd
  | palignr
  | pblendw | blendps | blendpd | pblendd
  | pclmulqdq
  | mpsadbw
  | insertps
  | roundss | roundsd
  | cmpps | cmppd | cmpss | cmpsd
  | perm2f128 | perm2i128
  | sha1rnds4 | gf2p8affineqb | gf2p8affineinvqb
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBinImmOp := ⟨mnemonics% SimdBinImmOp⟩

def clmul64 (a b : BitVec 64) : BitVec 128 :=
  (List.range 64).foldl (fun acc i =>
    if b.getLsbD i then acc ^^^ ((a.zeroExtend 128) <<< i) else acc) 0#128

def fpPredicateMatch (pred : Nat) (lt eq unord : Bool) : Bool :=
  match pred % 16 with
  | 0 => eq
  | 1 => lt
  | 2 => lt || eq
  | 3 => unord
  | 4 => !eq
  | 5 => !lt
  | 6 => !lt && !eq
  | 7 => !unord
  | 8 => eq || unord
  | 9 => lt || unord
  | 10 => lt || eq || unord
  | 11 => false
  | 12 => !eq && !unord
  | 13 => !lt && !unord
  | 14 => !lt && !eq && !unord
  | _ => true

def f32cmpPred (pred : Nat) (a b : BitVec 32) : BitVec 32 :=
  let fa := a.toFloat32; let fb := b.toFloat32
  let unord := fa.isNaN || fb.isNaN
  let lt := !unord && fa < fb
  let eq := !unord && fa == fb
  if fpPredicateMatch pred lt eq unord then 0xffffffff#32 else 0#32

def f64cmpPred (pred : Nat) (a b : BitVec 64) : BitVec 64 :=
  let fa := a.toFloat; let fb := b.toFloat
  let unord := fa.isNaN || fb.isNaN
  let lt := !unord && fa < fb
  let eq := !unord && fa == fb
  if fpPredicateMatch pred lt eq unord then 0xffffffffffffffff#64 else 0#64

def SimdBinImmOp.interp {n} (op : SimdBinImmOp) (a b : BitVec n) (imm : BitVec 8) (legacy : Bool := false) : BitVec n :=
  match op with
  | .shufps => .ofLanes n 32 fun i =>
    (if i % 4 < 2 then a else b).pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .shufpd => .ofLanes n 64 fun i =>
    (if i % 2 == 0 then a else b).lane 64 (i / 2 * 2 + (imm >>> (i % 2)).toNat % 2)
  | .palignr => .ofLanes n 128 fun laneIdx =>
    let a128 := a.lane 128 laneIdx
    let b128 := b.lane 128 laneIdx
    let concat := a128 ++ b128
    let shift := imm.toNat * 8
    if shift >= 256 then 0#128 else (concat >>> shift).truncate 128
  | .pblendw => .ofLanes n 16 fun i =>
    if (imm >>> (i % 8)).getLsbD 0 then b.lane 16 i else a.lane 16 i
  | .blendps => .ofLanes n 32 fun i =>
    if (imm >>> i).getLsbD 0 then b.lane 32 i else a.lane 32 i
  | .blendpd => .ofLanes n 64 fun i =>
    if (imm >>> i).getLsbD 0 then b.lane 64 i else a.lane 64 i
  | .pblendd => .ofLanes n 32 fun i =>
    if (imm >>> (i % 8)).getLsbD 0 then b.lane 32 i else a.lane 32 i
  | .pclmulqdq => .ofLanes n 128 fun laneIdx =>
    let a128 := a.lane 128 laneIdx
    let b128 := b.lane 128 laneIdx
    let qwordA := a128.lane 64 (if imm.getLsbD 0 then 1 else 0)
    let qwordB := b128.lane 64 (if imm.getLsbD 4 then 1 else 0)
    clmul64 qwordA qwordB
  | .mpsadbw => .ofLanes n 128 fun laneIdx =>
    let a128 := a.lane 128 laneIdx
    let b128 := b.lane 128 laneIdx
    let s1_off := if (imm.toNat >>> (laneIdx * 4 + 2)) &&& 1 == 1 then 4 else 0
    let s2_off := ((imm.toNat >>> (laneIdx * 4)) &&& 3) * 4
    .ofLanes 128 16 fun i =>
      let sum := (List.range 4).foldl (fun acc j =>
        let b1 := (a128.lane 8 (s1_off + i + j)).toNat
        let b2 := (b128.lane 8 (s2_off + j)).toNat
        let diff : Int := (b1 : Int) - (b2 : Int)
        acc + diff.natAbs) 0
      BitVec.ofNat 16 sum
  | .insertps =>
    let src_idx := (imm.toNat >>> 6) &&& 3
    let dst_idx := (imm.toNat >>> 4) &&& 3
    let zmask := imm.toNat &&& 0xf
    let val := b.lane 32 src_idx
    let inserted : BitVec n := .ofLanes n 32 fun i => if i == dst_idx then val else a.lane 32 i
    .ofLanes n 32 fun i => if (zmask >>> i) &&& 1 == 1 then 0#32 else inserted.lane 32 i
  | .roundss =>
    let rounded := roundFloat32 (roundImmMode imm) (b.lane 32 0)
    a.replaceLow rounded
  | .roundsd =>
    let rounded := roundFloat64 (roundImmMode imm) (b.lane 64 0)
    a.replaceLow rounded
  | .cmpps =>
    let pred := if legacy then imm.toNat &&& 7 else imm.toNat &&& 31
    .map2 32 (f32cmpPred pred) a b
  | .cmppd =>
    let pred := if legacy then imm.toNat &&& 7 else imm.toNat &&& 31
    .map2 64 (f64cmpPred pred) a b
  | .cmpss =>
    let pred := if legacy then imm.toNat &&& 7 else imm.toNat &&& 31
    a.replaceLow (f32cmpPred pred (a.lane 32 0) (b.lane 32 0))
  | .cmpsd =>
    let pred := if legacy then imm.toNat &&& 7 else imm.toNat &&& 31
    a.replaceLow (f64cmpPred pred (a.lane 64 0) (b.lane 64 0))
  | .perm2f128 | .perm2i128 => .ofLanes n 128 fun i =>
    let ctrl := (imm.toNat >>> (i * 4))
    if (ctrl >>> 3) &&& 1 == 1 then 0#128
    else
      let src := if (ctrl >>> 1) &&& 1 == 1 then b else a
      src.lane 128 (ctrl &&& 1)
  | .sha1rnds4 => .map2 128 (sha1Rnds4 imm) a b
  | .gf2p8affineqb => .ofLanes n 8 fun i => gf2p8Affine (b.lane 64 (i / 8)) (a.lane 8 i) imm
  | .gf2p8affineinvqb => .ofLanes n 8 fun i => gf2p8Affine (b.lane 64 (i / 8)) (gf2p8Inv (a.lane 8 i)) imm

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinImmOp.memBytes? : SimdBinImmOp → Option Nat
  | .insertps | .roundss | .cmpss => some 4
  | .roundsd | .cmpsd => some 8
  | _ => none
