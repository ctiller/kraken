module

public import Kraken.X64.Ops.Lanes

/-! Exact IEEE-754 binary arithmetic on bit patterns, for operations Lean's `Float` can't express
with a single rounding (fused multiply-add, wide integer conversions, roundInt, and f16).
Rounding modes: 0 = nearest-even, 1 = down (-inf), 2 = up (+inf), 3 = toward zero. -/

@[expose] public section

/-- An IEEE binary format with `e` exponent bits and `m` explicit mantissa bits. -/
structure FpFmt where (e m : Nat)

namespace FpFmt
def f32 : FpFmt := ⟨8, 23⟩
def f64 : FpFmt := ⟨11, 52⟩
abbrev bits (f : FpFmt) : Nat := 1 + f.e + f.m
/-- The exponent field of `x`. -/
def expField (f : FpFmt) (x : BitVec f.bits) : Nat := (x.extractLsb' f.m f.e).toNat
def isNaN (f : FpFmt) (x : BitVec f.bits) : Bool :=
  f.expField x == 2 ^ f.e - 1 && x.extractLsb' 0 f.m != 0
/-- The quiet version of NaN `x`: the most significant fraction bit set (bit 22, `0x400000`, in
binary32). -/
def quiet (f : FpFmt) (x : BitVec f.bits) : BitVec f.bits := x ||| .twoPow _ (f.m - 1)
/-- The default NaN ("QNaN floating-point indefinite"): sign set, exponent all ones, fraction
`100…0` (`0xffc00000` in binary32). -/
def defaultNaN (f : FpFmt) : BitVec f.bits := .ofInt _ (-(2 ^ (f.m - 1) : Int))

/-- SSE NaN rules around the result `r ()` of an operation on `args`: a NaN operand propagates
(quieted, the first one winning), and an invalid operation gives the default NaN. -/
def sseNaN (f : FpFmt) (args : List (BitVec f.bits)) (r : Unit → BitVec f.bits) : BitVec f.bits :=
  match args.find? f.isNaN with
  | some x => f.quiet x
  | none => let v := r (); if f.isNaN v then f.defaultNaN else v
end FpFmt

/-- An SSE single-precision operation on one lane, with the SSE NaN rules (`FpFmt.sseNaN`). Lean's
`Float32` can't express these: its logical model has a single NaN (all NaNs are equal), so every
NaN result reads back as `0x7fc00000`. -/
def sseBinOp (op : Float32 → Float32 → Float32) (a b : BitVec 32) : BitVec 32 :=
  FpFmt.f32.sseNaN [a, b] fun _ => (op a.toFloat32 b.toFloat32).toBitVec

/-- `sseBinOp` for double precision. -/
def sseBinOp64 (op : Float → Float → Float) (a b : BitVec 64) : BitVec 64 :=
  FpFmt.f64.sseNaN [a, b] fun _ => (op a.toFloat b.toFloat).toBitVec
