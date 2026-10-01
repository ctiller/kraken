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

/-- Whether the result of `op` is undefined/implementation-dependent (e.g. horizontal NaN choice in hadd/hsub). -/
def SimdBinOp.resultUndefined {n} (op : SimdBinOp) (a b : BitVec n) : Bool :=
  match op with
  | .fp .haddps | .fp .hsubps =>
    let numLanes := n / 128
    (List.range numLanes).any fun l =>
      let a128 := a.lane 128 l
      let b128 := b.lane 128 l
      let pairsA := [(a128.lane 32 0, a128.lane 32 1), (a128.lane 32 2, a128.lane 32 3)]
      let pairsB := [(b128.lane 32 0, b128.lane 32 1), (b128.lane 32 2, b128.lane 32 3)]
      (pairsA ++ pairsB).any fun (x, y) => FpFmt.f32.isNaN x && FpFmt.f32.isNaN y
  | .fp .haddpd | .fp .hsubpd =>
    let numLanes := n / 128
    (List.range numLanes).any fun l =>
      let a128 := a.lane 128 l
      let b128 := b.lane 128 l
      let pairA := (a128.lane 64 0, a128.lane 64 1)
      let pairB := (b128.lane 64 0, b128.lane 64 1)
      [pairA, pairB].any fun (x, y) => FpFmt.f64.isNaN x && FpFmt.f64.isNaN y
  | _ => false

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdBinOp.memBytes? : SimdBinOp → Option Nat
  | .fp op => op.memBytes?
  | .fpcmp op => op.memBytes?
  | _ => none

