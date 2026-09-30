module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point comparison SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive FpCmpPred | eq | lt | le | unord | neq | nlt | nle | ord
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic FpCmpPred := ⟨mnemonics% FpCmpPred⟩

def FpCmpPred.code : FpCmpPred → Nat
  | .eq => 0 | .lt => 1 | .le => 2 | .unord => 3
  | .neq => 4 | .nlt => 5 | .nle => 6 | .ord => 7

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

structure SimdFpCmp where
  pred : FpCmpPred
  type : FpType
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFpCmp where
  names := Id.run do
    let mut r := #[]
    for (t, tn) in Mnemonic.names do
      for (p, pn) in Mnemonic.names do
        r := r.push (⟨p, t⟩, "cmp" ++ pn ++ tn)
    return r

/-- The operation on one 128-bit lane. -/
def SimdFpCmp.interp (op : SimdFpCmp) : BitVec 128 → BitVec 128 → BitVec 128 :=
  let c := op.pred.code
  match op.type with
  | .ps => .map2 32 (f32cmpPred c)
  | .pd => .map2 64 (f64cmpPred c)
  | .ss => .scalar 32 (f32cmpPred c)
  | .sd => .scalar 64 (f64cmpPred c)

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFpCmp.memBytes? (op : SimdFpCmp) : Option Nat := op.type.memBytes?
