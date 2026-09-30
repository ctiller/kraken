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
  | bextr
  | bzhi
  | pdep
  | pext
  | sarx
  | shlx
  | shrx
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic GprBinOp := ⟨mnemonics% GprBinOp⟩

/-- Whether AT&T syntax lists `src2` first (`op src2, src1, dst`) rather than `op src1, src2, dst`. -/
def GprBinOp.src2First : GprBinOp → Bool
  | .andn | .pdep | .pext => true
  | .bextr | .bzhi | .sarx | .shlx | .shrx => false

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
  | .pdep, a, b =>
    let (r, _) := (List.range n).foldl (fun (r, k) m =>
      if b.getLsbD m then (if a.getLsbD k then r ||| ((1 : BitVec n) <<< m) else r, k + 1)
      else (r, k)) ((0 : BitVec n), 0)
    (r, {})
  | .pext, a, b =>
    let (r, _) := (List.range n).foldl (fun (r, k) m =>
      if b.getLsbD m then (if a.getLsbD m then r ||| ((1 : BitVec n) <<< k) else r, k + 1)
      else (r, k)) ((0 : BitVec n), 0)
    (r, {})
  | .sarx, a, b => (b.sshiftRight (a.toNat &&& if n == 64 then 0x3f else 0x1f), {})
  | .shlx, a, b => (b <<< (a.toNat &&& if n == 64 then 0x3f else 0x1f), {})
  | .shrx, a, b => (b.ushiftRight (a.toNat &&& if n == 64 then 0x3f else 0x1f), {})

