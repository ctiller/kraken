module

public import Kraken.X64.Ops.SimdInt
public import Kraken.X64.Ops.SimdFp
public import Kraken.X64.Ops.SimdLogic

/-! SSE/AVX operations of shape `dst := op(src1, src2)`, as a sum of opcode families (one file each).
In `AvxOperation.sse` the destination is also the first source; in `AvxOperation.vex` (the
`v`-prefixed form) the sources are separate. Most families define their operation on one 128-bit
lane, which wider forms apply to each lane. -/

@[expose] public section

inductive SimdBinOp
  | int (op : SimdInt)
  | fp (op : SimdFp)
  | logic (op : SimdLogic)
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBinOp := ⟨mnemonics% SimdBinOp⟩

def SimdBinOp.interp {n} : SimdBinOp → BitVec n → BitVec n → BitVec n
  | .int op => .map2 128 op.interp
  | .fp op => .map2 128 op.interp
  | .logic op => .map2 128 op.interp

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinOp.memBytes? : SimdBinOp → Option Nat
  | _ => none
