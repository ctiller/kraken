module

public import Kraken.X64.Ops.SimdInt
public import Kraken.X64.Ops.SimdFp
public import Kraken.X64.Ops.SimdLogic
public import Kraken.X64.Ops.SimdShuf
public import Kraken.X64.Ops.SimdFpCmp
public import Kraken.X64.Ops.SimdCrypto

/-! SSE/AVX operations of shape `dst := op(src1, src2)`, as a sum of opcode families (one file each).
In `AvxOperation.sse` the destination is also the first source; in `AvxOperation.vex` (the
`v`-prefixed form) the sources are separate. Wider forms apply `interp` to each 128-bit lane. -/

@[expose] public section

inductive SimdBinOp
  | int (op : SimdInt)
  | fp (op : SimdFp)
  | logic (op : SimdLogic)
  | shuf (op : SimdShuf)
  | fpcmp (op : SimdFpCmp)
  | crypto (op : SimdCrypto)
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBinOp := ⟨mnemonics% SimdBinOp⟩

/-- The operation on one 128-bit lane. -/
def SimdBinOp.interp : SimdBinOp → BitVec 128 → BitVec 128 → BitVec 128
  | .int op => op.interp
  | .fp op => op.interp
  | .logic op => op.interp
  | .shuf op => op.interp
  | .fpcmp op => op.interp
  | .crypto op => op.interp

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinOp.memBytes? : SimdBinOp → Option Nat
  | .int _ => none
  | .fp op => op.memBytes?
  | .logic _ => none
  | .shuf _ => none
  | .fpcmp op => op.memBytes?
  | .crypto _ => none
