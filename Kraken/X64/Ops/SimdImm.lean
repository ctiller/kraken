module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX operations with an 8-bit immediate, on the whole vector:
* unary `op $imm, src, dst` (`AvxOperation.sseUnImm`/`.vexUnImm`): `dst := op(src, imm)`;
* binary `op $imm, src, dst` (`AvxOperation.sseImm`: `dst := op(dst, src, imm)`) and
  `vop $imm, src2, src1, dst` (`AvxOperation.vexImm`: `dst := op(src1, src2, imm)`). -/

@[expose] public section

inductive SimdUnImmOp
  | pshufd
  | aeskeygenassist
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdUnImmOp := ⟨mnemonics% SimdUnImmOp⟩

/-- Element `i` of a vector of `k`-bit elements, where `sel` picks among the 4 elements of the group
of 4 containing `i`. -/
def BitVec.pick4 {n} (k : Nat) (x : BitVec n) (i sel : Nat) : BitVec k := x.lane k (i / 4 * 4 + sel % 4)

def aesSubWord (w : BitVec 32) : BitVec 32 :=
  .ofLanes 32 8 fun i => aesSbox.getD (w.lane 8 i).toNat 0#8

def aesRotWord (w : BitVec 32) : BitVec 32 :=
  .ofLanes 32 8 fun
    | 0 => w.lane 8 1
    | 1 => w.lane 8 2
    | 2 => w.lane 8 3
    | _ => w.lane 8 0

def SimdUnImmOp.interp {n} : SimdUnImmOp → BitVec n → BitVec 8 → BitVec n
  | .pshufd, a, imm => .ofLanes n 32 fun i => a.pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .aeskeygenassist, a, imm => .ofLanes n 128 fun laneIdx =>
      let x := a.lane 128 laneIdx
      let x1 := x.lane 32 1
      let x3 := x.lane 32 3
      let rcon : BitVec 32 := imm.zeroExtend 32
      let sw_x1 := aesSubWord x1
      let sw_x3 := aesSubWord x3
      let d0 := sw_x1
      let d1 := aesRotWord sw_x1 ^^^ rcon
      let d2 := sw_x3
      let d3 := aesRotWord sw_x3 ^^^ rcon
      .ofLanes 128 32 fun | 0 => d0 | 1 => d1 | 2 => d2 | _ => d3

inductive SimdBinImmOp
  | shufps
  | sha1rnds4
  | gf2p8affineqb
  | gf2p8affineinvqb
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBinImmOp := ⟨mnemonics% SimdBinImmOp⟩

def parity8 (x : BitVec 8) : BitVec 1 :=
  (List.range 8).foldl (fun acc i => acc ^^^ (x.extractLsb' i 1)) 0#1

def gf2p8Inv : Array (BitVec 8) := #[
  0x00#8, 0x01#8, 0x8d#8, 0xf6#8, 0xcb#8, 0x52#8, 0x7b#8, 0xd1#8, 0xe8#8, 0x4f#8, 0x29#8, 0xc0#8, 0xb0#8, 0xe1#8, 0xe5#8, 0xc7#8,
  0x74#8, 0xb4#8, 0xaa#8, 0x4b#8, 0x99#8, 0x2b#8, 0x60#8, 0x5f#8, 0x58#8, 0x3f#8, 0xfd#8, 0xcc#8, 0xff#8, 0x40#8, 0xee#8, 0xb2#8,
  0x3a#8, 0x6e#8, 0x5a#8, 0xf1#8, 0x55#8, 0x4d#8, 0xa8#8, 0xc9#8, 0xc1#8, 0x0a#8, 0x98#8, 0x15#8, 0x30#8, 0x44#8, 0xa2#8, 0xc2#8,
  0x2c#8, 0x45#8, 0x92#8, 0x6c#8, 0xf3#8, 0x39#8, 0x66#8, 0x42#8, 0xf2#8, 0x35#8, 0x20#8, 0x6f#8, 0x77#8, 0xbb#8, 0x59#8, 0x19#8,
  0x1d#8, 0xfe#8, 0x37#8, 0x67#8, 0x2d#8, 0x31#8, 0xf5#8, 0x69#8, 0xa7#8, 0x64#8, 0xab#8, 0x13#8, 0x54#8, 0x25#8, 0xe9#8, 0x09#8,
  0xed#8, 0x5c#8, 0x05#8, 0xca#8, 0x4c#8, 0x24#8, 0x87#8, 0xbf#8, 0x18#8, 0x3e#8, 0x22#8, 0xf0#8, 0x51#8, 0xec#8, 0x61#8, 0x17#8,
  0x16#8, 0x5e#8, 0xaf#8, 0xd3#8, 0x49#8, 0xa6#8, 0x36#8, 0x43#8, 0xf4#8, 0x47#8, 0x91#8, 0xdf#8, 0x33#8, 0x93#8, 0x21#8, 0x3b#8,
  0x79#8, 0xb7#8, 0x97#8, 0x85#8, 0x10#8, 0xb5#8, 0xba#8, 0x3c#8, 0xb6#8, 0x70#8, 0xd0#8, 0x06#8, 0xa1#8, 0xfa#8, 0x81#8, 0x82#8,
  0x83#8, 0x7e#8, 0x7f#8, 0x80#8, 0x96#8, 0x73#8, 0xbe#8, 0x56#8, 0x9b#8, 0x9e#8, 0x95#8, 0xd9#8, 0xf7#8, 0x02#8, 0xb9#8, 0xa4#8,
  0xde#8, 0x6a#8, 0x32#8, 0x6d#8, 0xd8#8, 0x8a#8, 0x84#8, 0x72#8, 0x2a#8, 0x14#8, 0x9f#8, 0x88#8, 0xf9#8, 0xdc#8, 0x89#8, 0x9a#8,
  0xfb#8, 0x7c#8, 0x2e#8, 0xc3#8, 0x8f#8, 0xb8#8, 0x65#8, 0x48#8, 0x26#8, 0xc8#8, 0x12#8, 0x4a#8, 0xce#8, 0xe7#8, 0xd2#8, 0x62#8,
  0x0c#8, 0xe0#8, 0x1f#8, 0xef#8, 0x11#8, 0x75#8, 0x78#8, 0x71#8, 0xa5#8, 0x8e#8, 0x76#8, 0x3d#8, 0xbd#8, 0xbc#8, 0x86#8, 0x57#8,
  0x0b#8, 0x28#8, 0x2f#8, 0xa3#8, 0xda#8, 0xd4#8, 0xe4#8, 0x0f#8, 0xa9#8, 0x27#8, 0x53#8, 0x04#8, 0x1b#8, 0xfc#8, 0xac#8, 0xe6#8,
  0x7a#8, 0x07#8, 0xae#8, 0x63#8, 0xc5#8, 0xdb#8, 0xe2#8, 0xea#8, 0x94#8, 0x8b#8, 0xc4#8, 0xd5#8, 0x9d#8, 0xf8#8, 0x90#8, 0x6b#8,
  0xb1#8, 0x0d#8, 0xd6#8, 0xeb#8, 0xc6#8, 0x0e#8, 0xcf#8, 0xad#8, 0x08#8, 0x4e#8, 0xd7#8, 0xe3#8, 0x5d#8, 0x50#8, 0x1e#8, 0xb3#8,
  0x5b#8, 0x23#8, 0x38#8, 0x34#8, 0x68#8, 0x46#8, 0x03#8, 0x8c#8, 0xdd#8, 0x9c#8, 0x7d#8, 0xa0#8, 0xcd#8, 0x1a#8, 0x41#8, 0x1c#8
]

def gf2p8AffineByte (tsrc2qw : BitVec 64) (src1byte : BitVec 8) (imm : BitVec 8) : BitVec 8 :=
  .ofLanes 8 1 fun i =>
    let matByte := tsrc2qw.lane 8 (7 - i)
    let p := parity8 (matByte &&& src1byte)
    p ^^^ imm.extractLsb' i 1

def gf2p8AffineInvByte (tsrc2qw : BitVec 64) (src1byte : BitVec 8) (imm : BitVec 8) : BitVec 8 :=
  let invByte := gf2p8Inv.getD src1byte.toNat 0#8
  gf2p8AffineByte tsrc2qw invByte imm

def sha1F (f_sel : Nat) (b c d : BitVec 32) : BitVec 32 :=
  match f_sel with
  | 0 => (b &&& c) ||| (~~~b &&& d)
  | 2 => (b &&& c) ||| (b &&& d) ||| (c &&& d)
  | _ => b ^^^ c ^^^ d

def sha1K (k_sel : Nat) : BitVec 32 :=
  match k_sel with
  | 0 => 0x5a827999#32
  | 1 => 0x6ed9eba1#32
  | 2 => 0x8f1bbcdc#32
  | _ => 0xca62c1d6#32

def SimdBinImmOp.interp {n} : SimdBinImmOp → BitVec n → BitVec n → BitVec 8 → BitVec n
  | .shufps, a, b, imm => .ofLanes n 32 fun i =>
    (if i % 4 < 2 then a else b).pick4 32 i (imm >>> (i % 4 * 2)).toNat
  | .sha1rnds4, a, b, imm => .ofLanes n 128 fun laneIdx =>
      let src1 := a.lane 128 laneIdx
      let src2 := b.lane 128 laneIdx
      let sel := (imm &&& 3#8).toNat
      let f := sha1F sel
      let k := sha1K sel
      let a0 := src1.lane 32 3
      let b0 := src1.lane 32 2
      let c0 := src1.lane 32 1
      let d0 := src1.lane 32 0
      let w0 := src2.lane 32 3
      let w1 := src2.lane 32 2
      let w2 := src2.lane 32 1
      let w3 := src2.lane 32 0
      -- Round 0
      let a1 := f b0 c0 d0 + a0.rotateLeft 5 + w0 + k
      let b1 := a0
      let c1 := b0.rotateLeft 30
      let d1 := c0
      let e1 := d0
      -- Round 1
      let a2 := f b1 c1 d1 + a1.rotateLeft 5 + w1 + e1 + k
      let b2 := a1
      let c2 := b1.rotateLeft 30
      let d2 := c1
      let e2 := d1
      -- Round 2
      let a3 := f b2 c2 d2 + a2.rotateLeft 5 + w2 + e2 + k
      let b3 := a2
      let c3 := b2.rotateLeft 30
      let d3 := c2
      let e3 := d2
      -- Round 3
      let a4 := f b3 c3 d3 + a3.rotateLeft 5 + w3 + e3 + k
      let b4 := a3
      let c4 := b3.rotateLeft 30
      let d4 := c3
      .ofLanes 128 32 fun | 0 => d4 | 1 => c4 | 2 => b4 | _ => a4
  | .gf2p8affineqb, a, b, imm => .ofLanes n 8 fun byteIdx =>
      let qwordIdx := byteIdx / 8
      let tsrc2qw := b.lane 64 qwordIdx
      let src1byte := a.lane 8 byteIdx
      gf2p8AffineByte tsrc2qw src1byte imm
  | .gf2p8affineinvqb, a, b, imm => .ofLanes n 8 fun byteIdx =>
      let qwordIdx := byteIdx / 8
      let tsrc2qw := b.lane 64 qwordIdx
      let src1byte := a.lane 8 byteIdx
      gf2p8AffineInvByte tsrc2qw src1byte imm

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinImmOp.memBytes? : SimdBinImmOp → Option Nat
  | .shufps => none
  | .sha1rnds4 => none
  | .gf2p8affineqb => none
  | .gf2p8affineinvqb => none
