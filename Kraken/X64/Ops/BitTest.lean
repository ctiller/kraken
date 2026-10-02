module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Bit test instructions `op bit, dst`: CF := the selected bit of `dst`, which is then updated. -/

@[expose] public section

inductive BitTestOp
  | bt | bts | btr | btc
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic BitTestOp := ⟨mnemonics% BitTestOp⟩

/-- The new value of the selected bit, if it is written. -/
def BitTestOp.update : BitTestOp → Bool → Option Bool
  | .bt, _ => none | .bts, _ => true | .btr, _ => false | .btc, b => !b
