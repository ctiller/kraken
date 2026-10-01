module

public import Kraken.X64.Ops.SimdInt
public import Kraken.X64.Ops.SimdFp
public import Kraken.X64.Ops.SimdLogic
public import Kraken.X64.Ops.SimdShuf
public import Kraken.X64.Ops.SimdFpCmp
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SimdPerm

/-! SSE/AVX operations of shape `dst := op(src1, src2)`, as a sum of opcode families (one file each).
In `AvxOperation.sse` the destination is also the first source; in `AvxOperation.vex` (the
`v`-prefixed form) the sources are separate. Most families define their operation on one 128-bit
lane, which wider forms apply to each lane. -/

@[expose] public section

inductive SimdBinOp
  | int (op : SimdInt)
  | fp (op : SimdFp)
  | logic (op : SimdLogic)
  | shuf (op : SimdShuf)
  | fpcmp (op : SimdFpCmp)
  | crypto (op : SimdCrypto)
  | perm (op : SimdPerm)
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBinOp := ⟨mnemonics% SimdBinOp⟩

def SimdBinOp.interp {n} : SimdBinOp → BitVec n → BitVec n → BitVec n
  | .int op => .map2 128 op.interp
  | .fp op => .map2 128 op.interp
  | .logic op => .map2 128 op.interp
  | .shuf op => .map2 128 op.interp
  | .fpcmp op => .map2 128 op.interp
  | .crypto op => .map2 128 op.interp
  | .perm op => op.interp

/-- Whether the SDM leaves the result undefined: horizontal adds/subtracts of two NaNs pick one
in an implementation-dependent way. -/
def SimdBinOp.resultUndefined {n} (op : SimdBinOp) (a b : BitVec n) : Bool :=
  let twoNaNs (f : FpFmt) (x : BitVec n) := (List.range (n / f.bits / 2)).any fun i =>
    f.isNaN (x.lane f.bits (2 * i)) && f.isNaN (x.lane f.bits (2 * i + 1))
  match op with
  | .fp .haddps | .fp .hsubps => twoNaNs .f32 a || twoNaNs .f32 b
  | .fp .haddpd | .fp .hsubpd => twoNaNs .f64 a || twoNaNs .f64 b
  | _ => false

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinOp.memBytes? : SimdBinOp → Option Nat
  | .fp op => op.memBytes?
  | .fpcmp op => op.memBytes?
  | _ => none

/-- Whether this operation has a legacy (non-VEX) SSE form. -/
def SimdBinOp.hasLegacy : SimdBinOp → Bool
  | .perm _ => false
  | .int .psllvd | .int .psllvq | .int .psrlvd | .int .psrlvq | .int .psravd => false
  | _ => true

