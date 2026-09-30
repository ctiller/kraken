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
  | addsubps | addsubpd | haddps | haddpd | hsubps | hsubpd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdFp := ⟨mnemonics% SimdFp⟩

def sseMin32 (a b : BitVec 32) : BitVec 32 :=
  if a.toFloat32.isNaN || b.toFloat32.isNaN then b
  else if a.toFloat32 == 0 && b.toFloat32 == 0 then b
  else if b.toFloat32 < a.toFloat32 then b else a

def sseMin64 (a b : BitVec 64) : BitVec 64 :=
  if a.toFloat.isNaN || b.toFloat.isNaN then b
  else if a.toFloat == 0 && b.toFloat == 0 then b
  else if b.toFloat < a.toFloat then b else a

def sseMax32 (a b : BitVec 32) : BitVec 32 :=
  if a.toFloat32.isNaN || b.toFloat32.isNaN then b
  else if a.toFloat32 == 0 && b.toFloat32 == 0 then b
  else if a.toFloat32 < b.toFloat32 then b else a

def sseMax64 (a b : BitVec 64) : BitVec 64 :=
  if a.toFloat.isNaN || b.toFloat.isNaN then b
  else if a.toFloat == 0 && b.toFloat == 0 then b
  else if a.toFloat < b.toFloat then b else a

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
  | .addss => fun a b => a.replaceLow (sseBinOp (· + ·) (a.lane 32 0) (b.lane 32 0))
  | .subss => fun a b => a.replaceLow (sseBinOp (· - ·) (a.lane 32 0) (b.lane 32 0))
  | .mulss => fun a b => a.replaceLow (sseBinOp (· * ·) (a.lane 32 0) (b.lane 32 0))
  | .divss => fun a b => a.replaceLow (sseBinOp (· / ·) (a.lane 32 0) (b.lane 32 0))
  | .minss => fun a b => a.replaceLow (sseMin32 (a.lane 32 0) (b.lane 32 0))
  | .maxss => fun a b => a.replaceLow (sseMax32 (a.lane 32 0) (b.lane 32 0))
  | .sqrtss => fun a b => a.replaceLow (sseUnOp Float32.sqrt (b.lane 32 0))
  | .cvtsd2ss => fun a b => a.replaceLow (FpFmt.f64.convert .f32 0 (b.lane 64 0))
  -- Scalar double precision (replaces only lane 0 of a)
  | .addsd => fun a b => a.replaceLow (sseBinOp64 (· + ·) (a.lane 64 0) (b.lane 64 0))
  | .subsd => fun a b => a.replaceLow (sseBinOp64 (· - ·) (a.lane 64 0) (b.lane 64 0))
  | .mulsd => fun a b => a.replaceLow (sseBinOp64 (· * ·) (a.lane 64 0) (b.lane 64 0))
  | .divsd => fun a b => a.replaceLow (sseBinOp64 (· / ·) (a.lane 64 0) (b.lane 64 0))
  | .minsd => fun a b => a.replaceLow (sseMin64 (a.lane 64 0) (b.lane 64 0))
  | .maxsd => fun a b => a.replaceLow (sseMax64 (a.lane 64 0) (b.lane 64 0))
  | .sqrtsd => fun a b => a.replaceLow (sseUnOp64 Float.sqrt (b.lane 64 0))
  | .cvtss2sd => fun a b => a.replaceLow (FpFmt.f32.convert .f64 0 (b.lane 32 0))
  -- Asymmetric / horizontal ops
  | .addsubps => fun a b => .ofLanes 128 32 fun
    | 0 => sseBinOp (· - ·) (a.lane 32 0) (b.lane 32 0)
    | 1 => sseBinOp (· + ·) (a.lane 32 1) (b.lane 32 1)
    | 2 => sseBinOp (· - ·) (a.lane 32 2) (b.lane 32 2)
    | _ => sseBinOp (· + ·) (a.lane 32 3) (b.lane 32 3)
  | .addsubpd => fun a b => .ofLanes 128 64 fun
    | 0 => sseBinOp64 (· - ·) (a.lane 64 0) (b.lane 64 0)
    | _ => sseBinOp64 (· + ·) (a.lane 64 1) (b.lane 64 1)
  | .haddps => fun a b => .ofLanes 128 32 fun
    | 0 => sseBinOp (· + ·) (a.lane 32 0) (a.lane 32 1)
    | 1 => sseBinOp (· + ·) (a.lane 32 2) (a.lane 32 3)
    | 2 => sseBinOp (· + ·) (b.lane 32 0) (b.lane 32 1)
    | _ => sseBinOp (· + ·) (b.lane 32 2) (b.lane 32 3)
  | .haddpd => fun a b => .ofLanes 128 64 fun
    | 0 => sseBinOp64 (· + ·) (a.lane 64 0) (a.lane 64 1)
    | _ => sseBinOp64 (· + ·) (b.lane 64 0) (b.lane 64 1)
  | .hsubps => fun a b => .ofLanes 128 32 fun
    | 0 => sseBinOp (· - ·) (a.lane 32 0) (a.lane 32 1)
    | 1 => sseBinOp (· - ·) (a.lane 32 2) (a.lane 32 3)
    | 2 => sseBinOp (· - ·) (b.lane 32 0) (b.lane 32 1)
    | _ => sseBinOp (· - ·) (b.lane 32 2) (b.lane 32 3)
  | .hsubpd => fun a b => .ofLanes 128 64 fun
    | 0 => sseBinOp64 (· - ·) (a.lane 64 0) (a.lane 64 1)
    | _ => sseBinOp64 (· - ·) (b.lane 64 0) (b.lane 64 1)

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdFp.memBytes? : SimdFp → Option Nat
  | .addss | .subss | .mulss | .divss | .minss | .maxss | .sqrtss | .cvtss2sd => some 4
  | .addsd | .subsd | .mulsd | .divsd | .minsd | .maxsd | .sqrtsd | .cvtsd2ss => some 8
  | _ => none
