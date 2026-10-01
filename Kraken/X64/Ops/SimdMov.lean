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

/-- Whether the source is memory and the destination a register (`some true`: the loads `lddqu`
and `movntdqa`), the other way round (`some false`: the non-temporal stores), or either. -/
def SimdMov.memSrc? : SimdMov → Option Bool
  | .lddqu | .movntdqa => some true
  | .movntps | .movntpd | .movntdq => some false
  | .movups | .movupd | .movdqu | .movaps | .movapd | .movdqa => none

/-- Whether the model has the EVEX form of the `v` instruction, which can name the registers
`%zmm0`-`%zmm31`, `%xmm16`-`%xmm31` and `%ymm16`-`%ymm31`. -/
def SimdMov.evex (op : SimdMov) : Bool := op == .movups
