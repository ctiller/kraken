module

public import Kraken.X64.Ops.Lanes

/-! Exact IEEE-754 binary arithmetic on bit patterns, for operations Lean's `Float` can't express
with a single rounding (fused multiply-add, wide integer conversions). Rounding is to nearest
even (the default MXCSR mode). -/

@[expose] public section

/-- An IEEE binary format with `e` exponent bits and `m` explicit mantissa bits. -/
structure FpFmt where (e m : Nat)

namespace FpFmt
def f16 : FpFmt := ⟨5, 10⟩
def f32 : FpFmt := ⟨8, 23⟩
def f64 : FpFmt := ⟨11, 52⟩
abbrev bits (f : FpFmt) : Nat := 1 + f.e + f.m
def bias (f : FpFmt) : Int := 2 ^ (f.e - 1) - 1
/-- The exponent field of `x`. -/
def expField (f : FpFmt) (x : BitVec f.bits) : Nat := (x.extractLsb' f.m f.e).toNat
def isNaN (f : FpFmt) (x : BitVec f.bits) : Bool :=
  f.expField x == 2 ^ f.e - 1 && x.extractLsb' 0 f.m != 0
def isInf (f : FpFmt) (x : BitVec f.bits) : Bool :=
  f.expField x == 2 ^ f.e - 1 && x.extractLsb' 0 f.m == 0
/-- The quiet version of NaN `x`. -/
def quiet (f : FpFmt) (x : BitVec f.bits) : BitVec f.bits := x ||| .twoPow _ (f.m - 1)
/-- The default NaN ("QNaN floating-point indefinite"). -/
def defaultNaN (f : FpFmt) : BitVec f.bits := .ofInt _ (-(2 ^ (f.m - 1) : Int))
def inf (f : FpFmt) (sign : Bool) : BitVec f.bits :=
  .ofNat _ ((if sign then 2 ^ (f.bits - 1) else 0) + (2 ^ f.e - 1) * 2 ^ f.m)
def zero (f : FpFmt) (sign : Bool) : BitVec f.bits := if sign then .twoPow _ (f.bits - 1) else 0

/-- A finite `x` as `(sign, v, e)` with value `(-1)^sign * v * 2^e`. -/
def decode (f : FpFmt) (x : BitVec f.bits) : Bool × Nat × Int :=
  let m := (x.extractLsb' 0 f.m).toNat
  if f.expField x = 0 then (x.msb, m, 1 - f.bias - f.m)
  else (x.msb, m + 2 ^ f.m, f.expField x - f.bias - f.m)

/-- `v / 2^s` rounded with `mode`: 0 nearest-even, 1 down, 2 up, 3 toward zero. -/
def roundShift (sign : Bool) (v s mode : Nat) : Nat :=
  let (r, rem) := (v / 2 ^ s, v % 2 ^ s)
  let inc := match mode with
    | 0 => 2 * rem > 2 ^ s || (2 * rem = 2 ^ s && r % 2 = 1)
    | 1 => rem > 0 && sign
    | 2 => rem > 0 && !sign
    | _ => false
  if inc then r + 1 else r

/-- `(-1)^sign * v * 2^e` rounded with `mode` (`v ≠ 0` precondition):
0 = nearest even, 1 = down (-inf), 2 = up (+inf), 3 = toward zero. -/
def round (f : FpFmt) (sign : Bool) (v : Nat) (e : Int) (mode : Nat := 0) : BitVec f.bits :=
  let emin := 1 - f.bias - f.m  -- the exponent of the smallest subnormal's unit
  let q := max (e + Nat.log2 v - f.m) emin  -- the exponent of the result's unit
  let s := (q - e).toNat
  let r := roundShift sign (v * 2 ^ (e - q + s).toNat) s mode
  -- Rounding up may carry into a new bit.
  let (r, q) := if r = 2 ^ (f.m + 1) then (r / 2, q + 1) else (r, q)
  let biased := if r ≥ 2 ^ f.m then q - emin + 1 else 0
  if biased ≥ 2 ^ f.e - 1 then
    if mode == 3 || (mode == 1 && !sign) || (mode == 2 && sign) then
      .ofNat _ ((if sign then 2 ^ (f.bits - 1) else 0) + (2 ^ f.e - 2) * 2 ^ f.m + (2 ^ f.m - 1))
    else f.inf sign
  else .ofNat _ ((if sign then 2 ^ (f.bits - 1) else 0) + biased.toNat * 2 ^ f.m + r % 2 ^ f.m)

/-- Converts `x` to a signed integer of `w` bits with `mode`. NaN, Inf, or out-of-range -> `1 <<< (w - 1)`. -/
def toInt (f : FpFmt) (w : Nat) (mode : Nat) (x : BitVec f.bits) : BitVec w :=
  let indefinite : BitVec w := .ofInt w (-(2 ^ (w - 1) : Int))
  if f.isNaN x || f.isInf x then indefinite
  else
    let (sign, v, e) := f.decode x
    if v == 0 then 0
    else
      let q := if e ≥ 0 then v * 2 ^ e.toNat else roundShift sign v (-e).toNat mode
      let res : Int := if sign then -(q : Int) else q
      let minVal : Int := -(2 ^ (w - 1) : Int)
      let maxVal : Int := (2 ^ (w - 1) : Int) - 1
      if res < minVal || res > maxVal then indefinite
      else .ofInt w res

/-- Rounds `x` to an integer value in the same format with `mode`.
NaN -> quieted NaN, Inf or already-integer -> x, else rounded integer preserving sign (including -0). -/
def roundInt (f : FpFmt) (mode : Nat) (x : BitVec f.bits) : BitVec f.bits :=
  if f.isNaN x then f.quiet x
  else if f.isInf x then x
  else
    let (sign, v, e) := f.decode x
    if e ≥ 0 || v == 0 then x
    else
      let s := (-e).toNat
      let r := roundShift sign v s mode
      if r == 0 then f.zero sign
      else f.round sign r 0 mode

/-- The signed integer `i` rounded to the format. -/
def ofInt (f : FpFmt) (i : Int) : BitVec f.bits :=
  if i = 0 then 0 else f.round (i < 0) i.natAbs 0

/-- `±(a * b) ± c` with a single rounding (`negP`/`negC` negate the product/addend). A NaN
operand propagates (quieted, the first of `a`, `b`, `c` winning); invalid operations (`∞ * 0`,
`∞ - ∞`) give the default NaN. -/
def fma (f : FpFmt) (negP negC : Bool) (a b c : BitVec f.bits) : BitVec f.bits :=
  if f.isNaN a then f.quiet a else if f.isNaN b then f.quiet b else if f.isNaN c then f.quiet c
  else
    let (sa, va, ea) := f.decode a
    let (sb, vb, eb) := f.decode b
    let (sc, vc, ec) := f.decode c
    let (sp, sc) := ((sa != sb) != negP, sc != negC)
    if f.isInf a || f.isInf b then
      if va = 0 || vb = 0 || (f.isInf c && sc != sp) then f.defaultNaN else f.inf sp
    else if f.isInf c then f.inf sc
    else
      let e := min (ea + eb) ec
      let p : Int := (va * vb * 2 ^ (ea + eb - e).toNat : Nat)
      let r := (if sp then -p else p) + (if sc then -1 else 1) * (vc * 2 ^ (ec - e).toNat : Nat)
      if r = 0 then f.zero (if p = 0 && vc = 0 then sp && sc else false)
      else f.round (r < 0) r.natAbs e

/-- Converts `x` from format `f` to format `g` with rounding `mode`. -/
def convert (f g : FpFmt) (mode : Nat) (x : BitVec f.bits) : BitVec g.bits :=
  let sign := x.msb
  if f.isNaN x then
    let payload := x.extractLsb' 0 f.m
    let gPayload :=
      if g.m ≥ f.m then (payload.zeroExtend g.m) <<< (g.m - f.m)
      else (payload >>> (f.m - g.m)).truncate g.m
    g.quiet ((g.inf sign ||| gPayload.zeroExtend g.bits))
  else if f.isInf x then g.inf sign
  else
    let (s, v, e) := f.decode x
    if v == 0 then g.zero sign
    else g.round s v e mode
end FpFmt

/-- Half precision (binary16) to single precision (binary32) conversion. -/
def f16ToF32 (h : BitVec 16) : BitVec 32 := FpFmt.f16.convert .f32 0 h

/-- Single precision (binary32) to half precision (binary16) conversion. -/
def f32ToF16 (mode : Nat) (x : BitVec 32) : BitVec 16 := FpFmt.f32.convert .f16 mode x
