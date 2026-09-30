module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr
public import Kraken.X64.Ops.Flags

/-! General-purpose VEX-encoded binary operations (BMI) on `n`-bit values: `dst := op(src1, src2)`,
where `src1` is a register (VEX.vvvv) and `src2` a register or memory (ModRM.rm). -/

@[expose] public section

inductive GprBinOp
  | andn
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic GprBinOp := ⟨mnemonics% GprBinOp⟩

/-- Whether AT&T syntax lists `src2` first (`op src2, src1, dst`) rather than `op src1, src2, dst`. -/
def GprBinOp.src2First : GprBinOp → Bool
  | .andn => true

/-- The result and the status flags. -/
def GprBinOp.interp {n} : GprBinOp → BitVec n → BitVec n → BitVec n × FlagsOut
  | .andn, a, b =>
    let r := ~~~a &&& b
    (r, { cf := false, pf := .undef, af := .undef, zf := r == 0, sf := r.msb, of := false })
