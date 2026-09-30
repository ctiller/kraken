module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Packed shuffle/pack/unpack SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdShuf
  | packsswb | packssdw | packuswb | packusdw
  | punpcklbw | punpcklwd | punpckldq | punpcklqdq
  | punpckhbw | punpckhwd | punpckhdq | punpckhqdq
  | unpcklps | unpckhps | unpcklpd | unpckhpd
  | pshufb | movlhps | movhlps
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdShuf := ⟨mnemonics% SimdShuf⟩

/-- The operation on one 128-bit lane. -/
def SimdShuf.interp : SimdShuf → BitVec 128 → BitVec 128 → BitVec 128
  | .packsswb => .pack 8 (.satS 8) | .packssdw => .pack 16 (.satS 16)
  | .packuswb => .pack 8 (.satU 8) | .packusdw => .pack 16 (.satU 16)
  | .punpcklbw => .unpckl 8 | .punpcklwd => .unpckl 16
  | .punpckldq | .unpcklps => .unpckl 32
  | .punpcklqdq | .unpcklpd | .movlhps => .unpckl 64
  | .punpckhbw => .unpckh 8 | .punpckhwd => .unpckh 16
  | .punpckhdq | .unpckhps => .unpckh 32
  | .punpckhqdq | .unpckhpd => .unpckh 64
  | .pshufb => .pshufb
  | .movhlps => .movhlps

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdShuf.memBytes? : SimdShuf → Option Nat := fun _ => none
