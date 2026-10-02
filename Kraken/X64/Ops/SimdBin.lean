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

/-- haddps/haddpd with the operands of each addition swapped. The SDM contradicts itself on the
order (pseudocode `SRC1[63:32] + SRC1[31:0]`, figures `xmm1[31:0] + xmm1[63:32]`), which decides
which of two NaNs is returned, so either order is possible. -/
def SimdBinOp.swappedInterp? {n} : SimdBinOp → Option (BitVec n → BitVec n → BitVec n)
  | .fp .haddps => some (.map2 128 (.hop 32 fun x y => sseBinOp (· + ·) y x))
  | .fp .haddpd => some (.map2 128 (.hop 64 fun x y => sseBinOp64 (· + ·) y x))
  | _ => none
