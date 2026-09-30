module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

-- TODO: MXCSR (rounding mode, exception flags)
inductive SimdFp
  | addps | subps
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFp := ⟨mnemonics% SimdFp⟩

/-- The operation on one 128-bit lane. -/
def SimdFp.interp : SimdFp → BitVec 128 → BitVec 128 → BitVec 128
  | .addps => .map2 32 (sseBinOp (· + ·))
  | .subps => .map2 32 (sseBinOp (· - ·))

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFp.memBytes? : SimdFp → Option Nat
  | .addps | .subps => none
