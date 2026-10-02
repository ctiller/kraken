module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! AVX 128-bit extract and insert operations (`vextracti128`, `vextractf128`,
`vinserti128`, `vinsertf128`). -/

@[expose] public section

inductive SimdExtract128Op
  | extracti128 | extractf128
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdExtract128Op := ⟨mnemonics% SimdExtract128Op⟩

inductive SimdInsert128Op
  | inserti128 | insertf128
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInsert128Op := ⟨mnemonics% SimdInsert128Op⟩
