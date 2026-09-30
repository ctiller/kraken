module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point comparison SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdFpCmp
  | cmpeqps | cmpltps | cmpleps | cmpunordps | cmpneqps | cmpnltps | cmpnleps | cmpordps
  | cmpeqpd | cmpltpd | cmplepd | cmpunordpd | cmpneqpd | cmpnltpd | cmpnlepd | cmpordpd
  | cmpeqss | cmpltss | cmpless | cmpunordss | cmpneqss | cmpnltss | cmpnless | cmpordss
  | cmpeqsd | cmpltsd | cmplesd | cmpunordsd | cmpneqsd | cmpnltsd | cmpnlesd | cmpordsd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFpCmp := ⟨mnemonics% SimdFpCmp⟩

def f32cmp (p : Float32 → Float32 → Bool) (a b : BitVec 32) : BitVec 32 :=
  if p a.toFloat32 b.toFloat32 then 0xffffffff#32 else 0#32

def f64cmp (p : Float → Float → Bool) (a b : BitVec 64) : BitVec 64 :=
  if p a.toFloat b.toFloat then 0xffffffffffffffff#64 else 0#64

def isUnord32 (a b : Float32) : Bool := a.isNaN || b.isNaN
def isUnord64 (a b : Float) : Bool := a.isNaN || b.isNaN

/-- The operation on one 128-bit lane. -/
def SimdFpCmp.interp : SimdFpCmp → BitVec 128 → BitVec 128 → BitVec 128
  | .cmpeqps    => .map2 32 (f32cmp (· == ·))
  | .cmpltps    => .map2 32 (f32cmp (· < ·))
  | .cmpleps    => .map2 32 (f32cmp (· <= ·))
  | .cmpunordps => .map2 32 (f32cmp isUnord32)
  | .cmpneqps   => .map2 32 (f32cmp (· != ·))
  | .cmpnltps   => .map2 32 (f32cmp fun a b => !(a < b))
  | .cmpnleps   => .map2 32 (f32cmp fun a b => !(a <= b))
  | .cmpordps   => .map2 32 (f32cmp fun a b => !isUnord32 a b)
  | .cmpeqpd    => .map2 64 (f64cmp (· == ·))
  | .cmpltpd    => .map2 64 (f64cmp (· < ·))
  | .cmplepd    => .map2 64 (f64cmp (· <= ·))
  | .cmpunordpd => .map2 64 (f64cmp isUnord64)
  | .cmpneqpd   => .map2 64 (f64cmp (· != ·))
  | .cmpnltpd   => .map2 64 (f64cmp fun a b => !(a < b))
  | .cmpnlepd   => .map2 64 (f64cmp fun a b => !(a <= b))
  | .cmpordpd   => .map2 64 (f64cmp fun a b => !isUnord64 a b)
  | .cmpeqss    => fun a b => a.replaceLow (f32cmp (· == ·) (a.lane 32 0) (b.lane 32 0))
  | .cmpltss    => fun a b => a.replaceLow (f32cmp (· < ·) (a.lane 32 0) (b.lane 32 0))
  | .cmpless    => fun a b => a.replaceLow (f32cmp (· <= ·) (a.lane 32 0) (b.lane 32 0))
  | .cmpunordss => fun a b => a.replaceLow (f32cmp isUnord32 (a.lane 32 0) (b.lane 32 0))
  | .cmpneqss   => fun a b => a.replaceLow (f32cmp (· != ·) (a.lane 32 0) (b.lane 32 0))
  | .cmpnltss   => fun a b => a.replaceLow (f32cmp (fun x y => !(x < y)) (a.lane 32 0) (b.lane 32 0))
  | .cmpnless   => fun a b => a.replaceLow (f32cmp (fun x y => !(x <= y)) (a.lane 32 0) (b.lane 32 0))
  | .cmpordss   => fun a b => a.replaceLow (f32cmp (fun x y => !isUnord32 x y) (a.lane 32 0) (b.lane 32 0))
  | .cmpeqsd    => fun a b => a.replaceLow (f64cmp (· == ·) (a.lane 64 0) (b.lane 64 0))
  | .cmpltsd    => fun a b => a.replaceLow (f64cmp (· < ·) (a.lane 64 0) (b.lane 64 0))
  | .cmplesd    => fun a b => a.replaceLow (f64cmp (· <= ·) (a.lane 64 0) (b.lane 64 0))
  | .cmpunordsd => fun a b => a.replaceLow (f64cmp isUnord64 (a.lane 64 0) (b.lane 64 0))
  | .cmpneqsd   => fun a b => a.replaceLow (f64cmp (· != ·) (a.lane 64 0) (b.lane 64 0))
  | .cmpnltsd   => fun a b => a.replaceLow (f64cmp (fun x y => !(x < y)) (a.lane 64 0) (b.lane 64 0))
  | .cmpnlesd   => fun a b => a.replaceLow (f64cmp (fun x y => !(x <= y)) (a.lane 64 0) (b.lane 64 0))
  | .cmpordsd   => fun a b => a.replaceLow (f64cmp (fun x y => !isUnord64 x y) (a.lane 64 0) (b.lane 64 0))

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFpCmp.memBytes? : SimdFpCmp → Option Nat
  | .cmpeqps | .cmpltps | .cmpleps | .cmpunordps | .cmpneqps | .cmpnltps | .cmpnleps | .cmpordps
  | .cmpeqpd | .cmpltpd | .cmplepd | .cmpunordpd | .cmpneqpd | .cmpnltpd | .cmpnlepd | .cmpordpd => none
  | .cmpeqss | .cmpltss | .cmpless | .cmpunordss | .cmpneqss | .cmpnltss | .cmpnless | .cmpordss => some 4
  | .cmpeqsd | .cmpltsd | .cmplesd | .cmpunordsd | .cmpneqsd | .cmpnltsd | .cmpnlesd | .cmpordsd => some 8
