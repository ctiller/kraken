module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX scalar float move operations (`movss`, `movsd`). -/

@[expose] public section

inductive SimdScalarMov
  | movss | movsd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdScalarMov := ⟨mnemonics% SimdScalarMov⟩

def SimdScalarMov.bytes : SimdScalarMov → Nat
  | .movss => 4
  | .movsd => 8
