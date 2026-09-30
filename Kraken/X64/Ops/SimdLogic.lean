module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Logical and comparison SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdLogic
  | pand | pandn | por | pxor
  | andps | andnps | orps | xorps
  | andpd | andnpd | orpd | xorpd
  | pcmpeqb | pcmpeqw | pcmpeqd | pcmpeqq
  | pcmpgtb | pcmpgtw | pcmpgtd | pcmpgtq
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdLogic := ⟨mnemonics% SimdLogic⟩

/-- The operation on one 128-bit lane. -/
def SimdLogic.interp : SimdLogic → BitVec 128 → BitVec 128 → BitVec 128
  | .pand | .andps | .andpd => (· &&& ·)
  | .pandn | .andnps | .andnpd => fun a b => ~~~a &&& b
  | .por | .orps | .orpd => (· ||| ·)
  | .pxor | .xorps | .xorpd => (· ^^^ ·)
  | .pcmpeqb => .map2 8 fun a b => if a == b then -1#8 else 0#8
  | .pcmpeqw => .map2 16 fun a b => if a == b then -1#16 else 0#16
  | .pcmpeqd => .map2 32 fun a b => if a == b then -1#32 else 0#32
  | .pcmpeqq => .map2 64 fun a b => if a == b then -1#64 else 0#64
  | .pcmpgtb => .map2 8 fun a b => if a.toInt > b.toInt then -1#8 else 0#8
  | .pcmpgtw => .map2 16 fun a b => if a.toInt > b.toInt then -1#16 else 0#16
  | .pcmpgtd => .map2 32 fun a b => if a.toInt > b.toInt then -1#32 else 0#32
  | .pcmpgtq => .map2 64 fun a b => if a.toInt > b.toInt then -1#64 else 0#64
