module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Packed integer SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdInt
  | paddb | paddw | paddd | paddq
  | psubb | psubw | psubd | psubq
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInt := ⟨mnemonics% SimdInt⟩

/-- The operation on one 128-bit lane. -/
def SimdInt.interp : SimdInt → BitVec 128 → BitVec 128 → BitVec 128
  | .paddb => .map2 8 (· + ·) | .paddw => .map2 16 (· + ·)
  | .paddd => .map2 32 (· + ·) | .paddq => .map2 64 (· + ·)
  | .psubb => .map2 8 (· - ·) | .psubw => .map2 16 (· - ·)
  | .psubd => .map2 32 (· - ·) | .psubq => .map2 64 (· - ·)
