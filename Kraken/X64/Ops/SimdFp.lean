module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Floating-point SSE/AVX operations `dst := op(src1, src2)` (see `SimdBinOp`). -/

@[expose] public section

inductive SimdFp
  | addps | addpd | subps | subpd | mulps | mulpd | divps | divpd
  | minps | minpd | maxps | maxpd

  | addsubps | addsubpd | haddps | haddpd | hsubps | hsubpd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFp := ⟨mnemonics% SimdFp⟩

/-- SSE `min`: `a` if `a < b`, else `b` (so `b` if either is NaN or both are zeros). -/
def sseMin32 (a b : BitVec 32) : BitVec 32 := if a.toFloat32 < b.toFloat32 then a else b
def sseMin64 (a b : BitVec 64) : BitVec 64 := if a.toFloat < b.toFloat then a else b

/-- SSE `max`: `a` if `a > b`, else `b` (so `b` if either is NaN or both are zeros). -/
def sseMax32 (a b : BitVec 32) : BitVec 32 := if b.toFloat32 < a.toFloat32 then a else b
def sseMax64 (a b : BitVec 64) : BitVec 64 := if b.toFloat < a.toFloat then a else b

/-- The operation on one 128-bit lane. -/
def SimdFp.interp : SimdFp → BitVec 128 → BitVec 128 → BitVec 128
  -- Packed single precision
  | .addps => .map2 32 (sseBinOp (· + ·))
  | .subps => .map2 32 (sseBinOp (· - ·))
  | .mulps => .map2 32 (sseBinOp (· * ·))
  | .divps => .map2 32 (sseBinOp (· / ·))
  | .minps => .map2 32 sseMin32
  | .maxps => .map2 32 sseMax32
  -- Packed double precision
  | .addpd => .map2 64 (sseBinOp64 (· + ·))
  | .subpd => .map2 64 (sseBinOp64 (· - ·))
  | .mulpd => .map2 64 (sseBinOp64 (· * ·))
  | .divpd => .map2 64 (sseBinOp64 (· / ·))
  | .minpd => .map2 64 sseMin64
  | .maxpd => .map2 64 sseMax64

  -- Asymmetric / horizontal ops
  | .addsubps => fun a b => .ofLanes 128 32 fun i =>
    (if i % 2 == 0 then sseBinOp (· - ·) else sseBinOp (· + ·)) (a.lane 32 i) (b.lane 32 i)
  | .addsubpd => fun a b => .ofLanes 128 64 fun i =>
    (if i % 2 == 0 then sseBinOp64 (· - ·) else sseBinOp64 (· + ·)) (a.lane 64 i) (b.lane 64 i)
  | .haddps => .hop 32 (sseBinOp (· + ·))
  | .haddpd => .hop 64 (sseBinOp64 (· + ·))
  | .hsubps => .hop 32 (sseBinOp (· - ·))
  | .hsubpd => .hop 64 (sseBinOp64 (· - ·))
