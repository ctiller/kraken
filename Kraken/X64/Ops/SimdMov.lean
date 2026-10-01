module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Full-vector SSE/AVX moves `op src, dst` (`AvxOperation.mov`). -/

@[expose] public section

inductive SimdMov
  | movups | movupd | movdqu | lddqu
  | movaps | movapd | movdqa | movntps | movntpd | movntdq | movntdqa
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdMov := ⟨mnemonics% SimdMov⟩

/-- Whether a memory operand must be aligned to the vector size (also in the VEX forms). -/
def SimdMov.aligned : SimdMov → Bool
  | .movups | .movupd | .movdqu | .lddqu => false
  | .movaps | .movapd | .movdqa | .movntps | .movntpd | .movntdq | .movntdqa => true
