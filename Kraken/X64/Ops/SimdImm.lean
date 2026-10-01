module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX operations with an 8-bit immediate, on the whole vector:
* unary `op $imm, src, dst` (`AvxOperation.unImm`): `dst := op(src, imm)`;
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

def SimdUnImmOp.interp {n} (op : SimdUnImmOp) (a : BitVec n) (imm : BitVec 8) : BitVec n :=
  match op with
  | .pshufd | .permilps => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .pshuflw | .pshufhw => .ofLanes n 16 fun i =>
    -- Shuffles the low (pshuflw) or high (pshufhw) four words of each 128-bit lane.
    let shuffled := if op == .pshuflw then i % 8 < 4 else i % 8 >= 4
    if shuffled then a.pick4 16 i (imm >>> (i % 4 * 2)).toNat else a.lane 16 i
  | .permq | .permpd => .ofLanes n 64 fun i => a.lane 64 (imm >>> (i % 4 * 2) &&& 3).toNat
  | .permilpd => .ofLanes n 64 fun i => a.lane 64 (i / 2 * 2 + (imm >>> i).toNat % 2)
  | .roundps => .map1 32 (FpFmt.f32.roundInt (roundImmMode imm)) a
  | .roundpd => .map1 64 (FpFmt.f64.roundInt (roundImmMode imm)) a
  | .aeskeygenassist => .map1 128 (aesKeygenAssist imm) a

/-- Whether this operation has a legacy (non-VEX) SSE form. -/
def SimdUnImmOp.hasLegacy : SimdUnImmOp → Bool
  | .permq | .permpd | .permilps | .permilpd => false
  | _ => true

/-- The only vector width (in bits) of the VEX form, if it has just one. -/
def SimdUnImmOp.vexBits? : SimdUnImmOp → Option Nat
  | .aeskeygenassist => some 128
  | .permq | .permpd => some 256
  | _ => none

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

/-- Whether this operation has a legacy (non-VEX) SSE form. -/
def SimdBinImmOp.hasLegacy : SimdBinImmOp → Bool
  | .pblendd | .perm2f128 | .perm2i128 => false
  | _ => true

def clmul64 (a b : BitVec 64) : BitVec 128 :=
  (List.range 64).foldl (fun acc i =>
    if b.getLsbD i then acc ^^^ ((a.zeroExtend 128) <<< i) else acc) 0#128

/-- The sum of the products of the `count` elements of `a` and `b` selected by `imm[7:4]`. -/
def dppSum {k : Nat} (mulOp addOp : BitVec k → BitVec k → BitVec k) (count : Nat)
    (imm : BitVec 8) (a b : BitVec 128) : BitVec k :=
  let p (i : Nat) : BitVec k :=
    if imm.getLsbD (4 + i) then mulOp (a.lane k i) (b.lane k i) else 0#k
  -- Summed pairwise, as the SDM specifies (this matters for rounding and the sign of zero).
  if count = 2 then addOp (p 0) (p 1) else addOp (addOp (p 0) (p 1)) (addOp (p 2) (p 3))

def dpp {k : Nat} (mulOp addOp : BitVec k → BitVec k → BitVec k) (count : Nat)
    (imm : BitVec 8) (a b : BitVec 128) : BitVec 128 :=
  let sum := dppSum mulOp addOp count imm a b
  .ofLanes 128 k fun i => if imm.getLsbD i then sum else 0#k

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

/-- All ones if `pred` holds for single-precision `a` and `b`, else zero. -/
def f32cmpPred (pred : Nat) (a b : BitVec 32) : BitVec 32 :=
  let (unord, lt, eq) := fcmp32 a b; .mask 32 (fpPredicateMatch pred lt eq unord)

/-- `f32cmpPred` for double precision. -/
def f64cmpPred (pred : Nat) (a b : BitVec 64) : BitVec 64 :=
  let (unord, lt, eq) := fcmp64 a b; .mask 64 (fpPredicateMatch pred lt eq unord)

/-- Compares elements of type `t` with predicate `pred` (scalar types: only the lowest element,
the others coming from `a`). -/
def FpType.cmp {n} (t : FpType) (pred : Nat) : BitVec n → BitVec n → BitVec n :=
  match t with
  | .ps => .map2 32 (f32cmpPred pred)
  | .pd => .map2 64 (f64cmpPred pred)
  | .ss => .scalar 32 (f32cmpPred pred)
  | .sd => .scalar 64 (f64cmpPred pred)

def SimdBinImmOp.interp {n} (op : SimdBinImmOp) (a b : BitVec n) (imm : BitVec 8)
    (memSrc : Bool := false) : BitVec n :=
  match op with
  | .shufps => .ofLanes n 32 fun i =>
    (if i % 4 < 2 then a else b).pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .shufpd => .ofLanes n 64 fun i =>
    (if i % 2 == 0 then a else b).lane 64 (i / 2 * 2 + (imm >>> i).toNat % 2)
  | .palignr => .map2 128 (fun a128 b128 => ((a128 ++ b128) >>> (imm.toNat * 8)).truncate 128) a b
  | .pblendw | .blendps | .pblendd | .blendpd =>
    let k := match op with | .pblendw => 16 | .blendpd => 64 | _ => 32
    .ofLanes n k fun i => if imm.getLsbD (i % 8) then b.lane k i else a.lane k i
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
    .ofLanes n 32 fun i =>
      if (zmask >>> i) &&& 1 == 1 then 0#32
      else if i == dst_idx then val
      else a.lane 32 i
  | .roundss => a.replaceLow (FpFmt.f32.roundInt (roundImmMode imm) (b.lane 32 0))
  | .roundsd => a.replaceLow (FpFmt.f64.roundInt (roundImmMode imm) (b.lane 64 0))
  | .cmpps | .cmppd | .cmpss | .cmpsd =>
    let t : FpType := match op with | .cmpps => .ps | .cmppd => .pd | .cmpss => .ss | _ => .sd
    t.cmp imm.toNat a b
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

/-- Whether the SDM leaves the result undefined: for dpps/dppd, when some destination element is
written and the sum in some 128-bit lane is NaN (a selected product is NaN, or a partial sum
such as `+inf + -inf` is). The SDM leaves both which NaNs propagate and where in the destination
they land implementation dependent (it only guarantees at least one NaN). -/
def SimdBinImmOp.resultUndefined {n} (op : SimdBinImmOp) (a b : BitVec n) (imm : BitVec 8) : Bool :=
  let nanSum (f : FpFmt) (count : Nat) (mul add : BitVec f.bits → BitVec f.bits → BitVec f.bits) :=
    imm.toNat % 2 ^ count != 0 && (List.range (n / 128)).any fun l =>
      f.isNaN (dppSum mul add count imm (a.lane 128 l) (b.lane 128 l))
  match op with
  | .dpps => nanSum .f32 4 (sseBinOp (· * ·)) (sseBinOp (· + ·))
  | .dppd => nanSum .f64 2 (sseBinOp64 (· * ·)) (sseBinOp64 (· + ·))
  | _ => false

/-- Whether this operation has a VEX (`v`) form. -/
def SimdBinImmOp.hasVex (op : SimdBinImmOp) : Bool := op != .sha1rnds4

/-- The only vector width (in bits) of the VEX form, if it has just one. -/
def SimdBinImmOp.vexBits? (op : SimdBinImmOp) : Option Nat :=
  if op.memBytes?.isSome || op == .dppd then some 128
  else if op matches .perm2f128 | .perm2i128 then some 256 else none

/-- Whether `imm` sets bits the SDM reserves (round: 7:4). -/
def SimdUnImmOp.reservedImm (op : SimdUnImmOp) (imm : BitVec 8) : Bool :=
  (op matches .roundps | .roundpd) && imm.toNat ≥ 16

/-- Whether `imm` sets bits the SDM reserves (round: 7:4; cmp: 7:3 legacy, 7:5 VEX). -/
def SimdBinImmOp.reservedImm (op : SimdBinImmOp) (imm : BitVec 8) (legacy : Bool) : Bool :=
  match op with
  | .roundss | .roundsd => imm.toNat ≥ 16
  | .cmpps | .cmppd | .cmpss | .cmpsd => imm.toNat ≥ if legacy then 8 else 32
  | _ => false
