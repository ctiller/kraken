module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SimdFpCmp
public import Kraken.X64.Ops.SoftFloat
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

def roundImmMode (imm : BitVec 8) : Nat :=
  if imm.getLsbD 2 then 0 else (imm &&& 3).toNat

def SimdUnImmOp.interp {n} : SimdUnImmOp → BitVec n → BitVec 8 → BitVec n
  | .pshufd, a, imm => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .pshuflw, a, imm => .ofLanes n 16 fun i =>
    if i % 8 < 4 then a.pick4 16 i (imm >>> (i % 4 * 2)).toNat else a.lane 16 i
  | .pshufhw, a, imm => .ofLanes n 16 fun i =>
    if i % 8 >= 4 then a.pick4 16 i (imm >>> ((i % 4) * 2)).toNat else a.lane 16 i
  | .permq, a, imm | .permpd, a, imm => .ofLanes n 64 fun i => a.lane 64 (imm >>> (i % 4 * 2) &&& 3).toNat
  | .permilps, a, imm => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .permilpd, a, imm => .ofLanes n 64 fun i => a.lane 64 (i / 2 * 2 + (imm >>> i).toNat % 2)
  | .roundps, a, imm => .map1 32 (FpFmt.f32.roundInt (roundImmMode imm)) a
  | .roundpd, a, imm => .map1 64 (FpFmt.f64.roundInt (roundImmMode imm)) a
  | .aeskeygenassist, a, imm => .map1 128 (aesKeygenAssist imm) a

inductive SimdBinImmOp
  | shufps | shufpd
  | palignr
  | pblendw | blendps | blendpd | pblendd
  | pclmulqdq
  | mpsadbw
  | dpps | dppd
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

def dpp {k : Nat} (mulOp addOp : BitVec k → BitVec k → BitVec k) (count : Nat)
    (imm : BitVec 8) (a b : BitVec 128) : BitVec 128 :=
  let p (i : Nat) : BitVec k :=
    if imm.getLsbD (4 + i) then mulOp (a.lane k i) (b.lane k i) else 0#k
  -- Summed pairwise, as the SDM specifies (this matters for rounding and the sign of zero).
  let sum := if count = 2 then addOp (p 0) (p 1) else addOp (addOp (p 0) (p 1)) (addOp (p 2) (p 3))
  .ofLanes 128 k fun i => if imm.getLsbD i then sum else 0#k

def SimdBinImmOp.interp {n} (op : SimdBinImmOp) (a b : BitVec n) (imm : BitVec 8) (legacy : Bool := false)
    (memSrc : Bool := false) : BitVec n :=
  match op with
  | .shufps => .ofLanes n 32 fun i =>
    (if i % 4 < 2 then a else b).pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .shufpd => .ofLanes n 64 fun i =>
    (if i % 2 == 0 then a else b).lane 64 (i / 2 * 2 + (imm >>> i).toNat % 2)
  | .palignr => .map2 128 (fun a128 b128 => ((a128 ++ b128) >>> (imm.toNat * 8)).truncate 128) a b
  | .pblendw => .ofLanes n 16 fun i =>
    if imm.getLsbD (i % 8) then b.lane 16 i else a.lane 16 i
  | .blendps | .pblendd => .ofLanes n 32 fun i =>
    if imm.getLsbD i then b.lane 32 i else a.lane 32 i
  | .blendpd => .ofLanes n 64 fun i =>
    if imm.getLsbD i then b.lane 64 i else a.lane 64 i
  | .pclmulqdq => .map2 128 (fun a128 b128 =>
    clmul64 (a128.lane 64 (if imm.getLsbD 0 then 1 else 0))
            (b128.lane 64 (if imm.getLsbD 4 then 1 else 0))) a b
  | .mpsadbw => .ofLanes n 128 fun laneIdx =>
    let a128 := a.lane 128 laneIdx
    let b128 := b.lane 128 laneIdx
    let s1_off := if (imm.toNat >>> (laneIdx * 3 + 2)) &&& 1 == 1 then 4 else 0
    let s2_off := ((imm.toNat >>> (laneIdx * 3)) &&& 3) * 4
    .ofLanes 128 16 fun i =>
      let sum := (List.range 4).foldl (fun acc j =>
        let b1 := (a128.lane 8 (s1_off + i + j)).toNat
        let b2 := (b128.lane 8 (s2_off + j)).toNat
        let diff : Int := (b1 : Int) - (b2 : Int)
        acc + diff.natAbs) 0
      BitVec.ofNat 16 sum
  | .dpps => .map2 128 (dpp (sseBinOp (· * ·)) (sseBinOp (· + ·)) 4 imm) a b
  | .dppd => .map2 128 (dpp (sseBinOp64 (· * ·)) (sseBinOp64 (· + ·)) 2 imm) a b
  | .insertps =>
    -- A memory source is the dword itself (in lane 0): COUNT_S is ignored.
    let src_idx := if memSrc then 0 else (imm.toNat >>> 6) &&& 3
    let dst_idx := (imm.toNat >>> 4) &&& 3
    let zmask := imm.toNat &&& 0xf
    let val := b.lane 32 src_idx
    let inserted : BitVec n := .ofLanes n 32 fun i => if i == dst_idx then val else a.lane 32 i
    .ofLanes n 32 fun i => if (zmask >>> i) &&& 1 == 1 then 0#32 else inserted.lane 32 i
  | .roundss =>
    let rounded := FpFmt.f32.roundInt (roundImmMode imm) (b.lane 32 0)
    a.replaceLow rounded
  | .roundsd =>
    let rounded := FpFmt.f64.roundInt (roundImmMode imm) (b.lane 64 0)
    a.replaceLow rounded
  | .cmpps | .cmppd | .cmpss | .cmpsd =>
    let pred := if legacy then imm.toNat &&& 7 else imm.toNat
    match op with
    | .cmpps => .map2 32 (f32cmpPred pred) a b
    | .cmppd => .map2 64 (f64cmpPred pred) a b
    | .cmpss => a.replaceLow (f32cmpPred pred (a.lane 32 0) (b.lane 32 0))
    | .cmpsd => a.replaceLow (f64cmpPred pred (a.lane 64 0) (b.lane 64 0))
    | _ => a
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
