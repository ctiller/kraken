module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX shifts by a count (an immediate, or the low 64 bits of an xmm register or memory):
`op count, dst` (`AvxOperation.sseShift`) and `vop count, src, dst` (`.vexShift`). -/

@[expose] public section

inductive SimdShiftOp
  | psllw | pslld | psllq | psrlw | psrld | psrlq | psraw | psrad | pslldq | psrldq
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdShiftOp := ⟨mnemonics% SimdShiftOp⟩

def SimdShiftOp.interp {n} : SimdShiftOp → BitVec n → Nat → BitVec n
  | .psllw, a, c => a.map1 16 (· <<< c) | .pslld, a, c => a.map1 32 (· <<< c)
  | .psllq, a, c => a.map1 64 (· <<< c) | .psrlw, a, c => a.map1 16 (· >>> c)
  | .psrld, a, c => a.map1 32 (· >>> c) | .psrlq, a, c => a.map1 64 (· >>> c)
  | .psraw, a, c => a.map1 16 (·.sshiftRight c) | .psrad, a, c => a.map1 32 (·.sshiftRight c)
  -- Byte shifts of each 128-bit lane.
  | .pslldq, a, c => a.map1 128 (· <<< (c * 8))
  | .psrldq, a, c => a.map1 128 (· >>> (c * 8))

/-- Whether the count must be an immediate (the byte shifts). -/
def SimdShiftOp.immOnly (op : SimdShiftOp) : Bool := op matches .pslldq | .psrldq
