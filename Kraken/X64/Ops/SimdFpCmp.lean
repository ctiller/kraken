module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point comparison SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

/-- The predicates of the compare pseudo-ops, in the order of their SDM codes (`ctorIdx`). -/
inductive FpCmpPred | eq | lt | le | unord | neq | nlt | nle | ord
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic FpCmpPred := ⟨mnemonics% FpCmpPred⟩

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
  op.type.cmp op.pred.ctorIdx

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFpCmp.memBytes? (op : SimdFpCmp) : Option Nat := op.type.memBytes?
