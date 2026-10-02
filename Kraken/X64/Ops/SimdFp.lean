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
  | addss | addsd | subss | subsd | mulss | mulsd | divss | divsd
  | minss | minsd | maxss | maxsd
  | sqrtss | sqrtsd | cvtss2sd | cvtsd2ss

  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFp := ⟨mnemonics% SimdFp⟩

/-- SSE `min`: `a` if `a < b`, else `b` (so `b` if either is NaN or both are zeros). -/
def sseMin32 (a b : BitVec 32) : BitVec 32 := if a.toFloat32 < b.toFloat32 then a else b
def sseMin64 (a b : BitVec 64) : BitVec 64 := if a.toFloat < b.toFloat then a else b

/-- SSE `max`: `a` if `a > b`, else `b` (so `b` if either is NaN or both are zeros). -/
def sseMax32 (a b : BitVec 32) : BitVec 32 := if b.toFloat32 < a.toFloat32 then a else b
def sseMax64 (a b : BitVec 64) : BitVec 64 := if b.toFloat < a.toFloat then a else b

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFp.memBytes? : SimdFp → Option Nat
  | .addss | .subss | .mulss | .divss | .minss | .maxss | .sqrtss | .cvtss2sd => some 4
  | .addsd | .subsd | .mulsd | .divsd | .minsd | .maxsd | .sqrtsd | .cvtsd2ss => some 8
  | _ => none

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
  -- Scalar single precision (replaces only lane 0 of a)
  | .addss => .scalar 32 (sseBinOp (· + ·))
  | .subss => .scalar 32 (sseBinOp (· - ·))
  | .mulss => .scalar 32 (sseBinOp (· * ·))
  | .divss => .scalar 32 (sseBinOp (· / ·))
  | .minss => .scalar 32 sseMin32
  | .maxss => .scalar 32 sseMax32
  | .sqrtss => fun a b => a.replaceLow (sseUnOp Float32.sqrt (b.lane 32 0))
  | .cvtsd2ss => fun a b => a.replaceLow (FpFmt.f64.convert .f32 0 (b.lane 64 0))
  -- Scalar double precision (replaces only lane 0 of a)
  | .addsd => .scalar 64 (sseBinOp64 (· + ·))
  | .subsd => .scalar 64 (sseBinOp64 (· - ·))
  | .mulsd => .scalar 64 (sseBinOp64 (· * ·))
  | .divsd => .scalar 64 (sseBinOp64 (· / ·))
  | .minsd => .scalar 64 sseMin64
  | .maxsd => .scalar 64 sseMax64
  | .sqrtsd => fun a b => a.replaceLow (sseUnOp64 Float.sqrt (b.lane 64 0))
  | .cvtss2sd => fun a b => a.replaceLow (FpFmt.f32.convert .f64 0 (b.lane 32 0))

