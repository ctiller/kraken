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

/-- The operation on one 128-bit lane. -/
def SimdFpCmp.interp : SimdFpCmp → BitVec 128 → BitVec 128 → BitVec 128
  | .cmpeqps    => .map2 32 (f32cmpPred 0)
  | .cmpltps    => .map2 32 (f32cmpPred 1)
  | .cmpleps    => .map2 32 (f32cmpPred 2)
  | .cmpunordps => .map2 32 (f32cmpPred 3)
  | .cmpneqps   => .map2 32 (f32cmpPred 4)
  | .cmpnltps   => .map2 32 (f32cmpPred 5)
  | .cmpnleps   => .map2 32 (f32cmpPred 6)
  | .cmpordps   => .map2 32 (f32cmpPred 7)
  | .cmpeqpd    => .map2 64 (f64cmpPred 0)
  | .cmpltpd    => .map2 64 (f64cmpPred 1)
  | .cmplepd    => .map2 64 (f64cmpPred 2)
  | .cmpunordpd => .map2 64 (f64cmpPred 3)
  | .cmpneqpd   => .map2 64 (f64cmpPred 4)
  | .cmpnltpd   => .map2 64 (f64cmpPred 5)
  | .cmpnlepd   => .map2 64 (f64cmpPred 6)
  | .cmpordpd   => .map2 64 (f64cmpPred 7)
  | .cmpeqss    => .scalar 32 (f32cmpPred 0)
  | .cmpltss    => .scalar 32 (f32cmpPred 1)
  | .cmpless    => .scalar 32 (f32cmpPred 2)
  | .cmpunordss => .scalar 32 (f32cmpPred 3)
  | .cmpneqss   => .scalar 32 (f32cmpPred 4)
  | .cmpnltss   => .scalar 32 (f32cmpPred 5)
  | .cmpnless   => .scalar 32 (f32cmpPred 6)
  | .cmpordss   => .scalar 32 (f32cmpPred 7)
  | .cmpeqsd    => .scalar 64 (f64cmpPred 0)
  | .cmpltsd    => .scalar 64 (f64cmpPred 1)
  | .cmplesd    => .scalar 64 (f64cmpPred 2)
  | .cmpunordsd => .scalar 64 (f64cmpPred 3)
  | .cmpneqsd   => .scalar 64 (f64cmpPred 4)
  | .cmpnltsd   => .scalar 64 (f64cmpPred 5)
  | .cmpnlesd   => .scalar 64 (f64cmpPred 6)
  | .cmpordsd   => .scalar 64 (f64cmpPred 7)

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFpCmp.memBytes? : SimdFpCmp → Option Nat
  | .cmpeqps | .cmpltps | .cmpleps | .cmpunordps | .cmpneqps | .cmpnltps | .cmpnleps | .cmpordps
  | .cmpeqpd | .cmpltpd | .cmplepd | .cmpunordpd | .cmpneqpd | .cmpnltpd | .cmpnlepd | .cmpordpd => none
  | .cmpeqss | .cmpltss | .cmpless | .cmpunordss | .cmpneqss | .cmpnltss | .cmpnless | .cmpordss => some 4
  | .cmpeqsd | .cmpltsd | .cmplesd | .cmpunordsd | .cmpneqsd | .cmpnltsd | .cmpnlesd | .cmpordsd => some 8
