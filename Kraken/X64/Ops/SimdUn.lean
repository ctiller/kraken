module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Unary SSE/AVX operations `op src, dst` (`AvxOperation.sseUn`, and `.vexUn` for the `v` forms):
`dst := op(src)` on the whole vector. -/

@[expose] public section

inductive SimdUnOp
  | pabsb | pabsw | pabsd
  | pmovzxbw
  | aesimc
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdUnOp := ⟨mnemonics% SimdUnOp⟩

def SimdUnOp.interp {n} : SimdUnOp → BitVec n → BitVec n
  | .pabsb => .map1 8 fun x => if x.msb then -x else x
  | .pabsw => .map1 16 fun x => if x.msb then -x else x
  | .pabsd => .map1 32 fun x => if x.msb then -x else x
  | .pmovzxbw => fun a => .ofLanes n 16 fun i => (a.lane 8 i).zeroExtend 16
  | .aesimc => fun a => .ofLanes n 128 fun i => aesInvMixColumns (a.lane 128 i)

/-- The size in bytes of a memory operand for a vector of `bytes` bytes, if smaller (e.g. for
widening conversions). -/
def SimdUnOp.memBytes? : SimdUnOp → Nat → Option Nat
  | .pabsb, _ | .pabsw, _ | .pabsd, _ => none
  | .pmovzxbw, bytes => some (bytes / 2)
  | .aesimc, _ => none
