module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr
public import Kraken.X64.Ops.Flags

/-! General-purpose unary operations `op src, %dst` (`AT&T`), `dst := op(src)` on `n`-bit values. -/

@[expose] public section

inductive GprUnOp
  | popcnt
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic GprUnOp := ⟨mnemonics% GprUnOp⟩

/-- The result (`none` if undefined) and the status flags. -/
def GprUnOp.interp {n} : GprUnOp → BitVec n → Option (BitVec n) × FlagsOut
  | .popcnt, a =>
    let r := BitVec.ofNat n ((List.range n).countP (a.getLsbD ·))
    (r, { cf := false, pf := false, af := false, zf := a == 0, sf := false, of := false })
