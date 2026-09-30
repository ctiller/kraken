module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

@[expose] public section

inductive SimdExtract128Op
  | extracti128 | extractf128
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdExtract128Op := ⟨mnemonics% SimdExtract128Op⟩

inductive SimdInsert128Op
  | inserti128 | insertf128
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInsert128Op := ⟨mnemonics% SimdInsert128Op⟩
