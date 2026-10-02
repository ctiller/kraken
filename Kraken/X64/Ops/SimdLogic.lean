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
  | .pcmpeqb => .map2 8 fun a b => .mask 8 (a == b)
  | .pcmpeqw => .map2 16 fun a b => .mask 16 (a == b)
  | .pcmpeqd => .map2 32 fun a b => .mask 32 (a == b)
  | .pcmpeqq => .map2 64 fun a b => .mask 64 (a == b)
  | .pcmpgtb => .map2 8 fun a b => .mask 8 (a.toInt > b.toInt)
  | .pcmpgtw => .map2 16 fun a b => .mask 16 (a.toInt > b.toInt)
  | .pcmpgtd => .map2 32 fun a b => .mask 32 (a.toInt > b.toInt)
  | .pcmpgtq => .map2 64 fun a b => .mask 64 (a.toInt > b.toInt)
