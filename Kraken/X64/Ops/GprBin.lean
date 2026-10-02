module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Flags
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! General-purpose VEX-encoded binary operations (BMI) on `n`-bit values: `dst := op(src1, src2)`,
where `src1` is a register (VEX.vvvv) and `src2` a register or memory (ModRM.rm). -/

@[expose] public section

inductive GprBinOp | andn | bextr | bzhi | pdep | pext | sarx | shlx | shrx
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic GprBinOp := ⟨mnemonics% GprBinOp⟩

/-- Whether AT&T syntax lists `src2` first (`op src2, src1, dst`) rather than `op src1, src2, dst`. -/
def GprBinOp.src2First : GprBinOp → Bool
  | .andn | .pdep | .pext => true
  | .bextr | .bzhi | .sarx | .shlx | .shrx => false

/-- `pdep` (`deposit`) scatters the low bits of `a` to the positions of the set bits of the mask
`b`; `pext` gathers the bits of `a` at those positions into the low bits. -/
def GprBinOp.pdepPext {n} (a b : BitVec n) (deposit : Bool) : BitVec n :=
  (List.range n).foldl (fun (r, k) m =>
    if b.getLsbD m then
      let bit := if deposit then a.getLsbD k else a.getLsbD m
      let shift := if deposit then m else k
      (if bit then r ||| ((1 : BitVec n) <<< shift) else r, k + 1)
    else (r, k)) ((0 : BitVec n), 0) |>.1

/-- The result and the status flags. -/
def GprBinOp.interp {n} : GprBinOp → BitVec n → BitVec n → BitVec n × FlagsOut
  | .andn, a, b =>
    let r := ~~~a &&& b
    (r, { cf := false, pf := .undef, af := .undef, zf := r == 0, sf := r.msb, of := false })
  | .bextr, a, b =>
    let r := (b >>> (a.toNat &&& 0xff)) &&& ((1 <<< ((a.toNat >>> 8) &&& 0xff)) - 1)
    (r, { cf := false, pf := .undef, af := .undef, zf := r == 0, sf := .undef, of := false })
  | .bzhi, a, b =>
    let idx := a.toNat &&& 0xff
    let r := b &&& ((1 <<< idx) - 1)
    (r, { cf := decide (idx > n - 1), pf := .undef, af := .undef, zf := r == 0, sf := r.msb, of := false })
  | .pdep, a, b => (pdepPext a b (deposit := true), {})
  | .pext, a, b => (pdepPext a b (deposit := false), {})
  -- The count is masked to 5 or 6 bits (the operands are 32 or 64 bits wide).
  | .sarx, a, b => (b.sshiftRight (a.toNat % n), {})
  | .shlx, a, b => (b <<< (a.toNat % n), {})
  | .shrx, a, b => (b.ushiftRight (a.toNat % n), {})
