module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Variable permutations `dst := op(src1, src2)` on the whole vector (see `SimdBinOp`); unlike the
other `SimdBinOp` families they may move elements across 128-bit lanes. -/

@[expose] public section

inductive SimdPerm
  | permd | permps | permilps | permilpd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdPerm := ⟨mnemonics% SimdPerm⟩

def SimdPerm.interp {n} : SimdPerm → BitVec n → BitVec n → BitVec n
  -- Indices in src1, data in src2.
  | .permd, a, b | .permps, a, b => .ofLanes n 32 fun i => b.lane 32 ((a.lane 32 i).toNat % (n / 32))
  -- Data in src1, per-128-bit-lane selectors in src2.
  | .permilps, a, b => .ofLanes n 32 fun i => a.lane 32 (i / 4 * 4 + (b.lane 32 i).toNat % 4)
  | .permilpd, a, b => .ofLanes n 64 fun i => a.lane 64 (i / 2 * 2 + (b.lane 64 i).toNat / 2 % 2)
