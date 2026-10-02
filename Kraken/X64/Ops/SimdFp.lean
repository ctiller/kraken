module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdFp
  | addps | addpd | subps | subpd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFp := ⟨mnemonics% SimdFp⟩

/-- The operation on one 128-bit lane. -/
def SimdFp.interp : SimdFp → BitVec 128 → BitVec 128 → BitVec 128
  -- Packed single precision
  | .addps => .map2 32 (sseBinOp (· + ·))
  | .subps => .map2 32 (sseBinOp (· - ·))
  -- Packed double precision
  | .addpd => .map2 64 (sseBinOp64 (· + ·))
  | .subpd => .map2 64 (sseBinOp64 (· - ·))
