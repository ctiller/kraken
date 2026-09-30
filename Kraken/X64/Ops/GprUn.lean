module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr
public import Kraken.X64.Ops.Flags

/-! General-purpose unary operations `op src, %dst` (`AT&T`), `dst := op(src)` on `n`-bit values. -/

@[expose] public section

inductive GprUnOp
  | popcnt | lzcnt | tzcnt | bsf | bsr | blsi | blsmsk | blsr
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic GprUnOp := ⟨mnemonics% GprUnOp⟩

/-- The result (`none` if undefined) and the status flags. -/
def GprUnOp.interp {n} : GprUnOp → BitVec n → Option (BitVec n) × FlagsOut
  | .popcnt, a =>
    let r := BitVec.ofNat n ((List.range n).countP (a.getLsbD ·))
    (r, { cf := false, pf := false, af := false, zf := a == 0, sf := false, of := false })
  | .lzcnt, a =>
    let r := a.clz
    (r, { cf := a == 0, pf := .undef, af := .undef, zf := r == 0, sf := .undef, of := .undef })
  | .tzcnt, a =>
    let r := a.ctz
    (r, { cf := a == 0, pf := .undef, af := .undef, zf := r == 0, sf := .undef, of := .undef })
  | .bsf, a =>
    let r := if a == 0 then none else some a.ctz
    (r, { cf := .undef, pf := .undef, af := .undef, zf := a == 0, sf := .undef, of := .undef })
  | .bsr, a =>
    let r := if a == 0 then none else some (BitVec.ofNat n (n - 1 - a.clz.toNat))
    (r, { cf := .undef, pf := .undef, af := .undef, zf := a == 0, sf := .undef, of := .undef })
  | .blsi, a =>
    let r := -a &&& a
    (r, { cf := a != 0, pf := .undef, af := .undef, zf := r == 0, sf := r.msb, of := false })
  | .blsmsk, a =>
    let r := (a - 1) ^^^ a
    (r, { cf := a == 0, pf := .undef, af := .undef, zf := false, sf := r.msb, of := false })
  | .blsr, a =>
    let r := (a - 1) &&& a
    (r, { cf := a == 0, pf := .undef, af := .undef, zf := r == 0, sf := r.msb, of := false })
