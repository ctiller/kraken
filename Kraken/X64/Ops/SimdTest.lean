module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Flags
public import Kraken.X64.Ops.Lanes
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX operations that only set status flags: `op src2, src1` (`AvxOperation.sseTest`, and
`.vexTest` for the `v` forms). -/

@[expose] public section

inductive SimdTestOp
  | ptest | testps | testpd | ucomiss | ucomisd | comiss | comisd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdTestOp := ⟨mnemonics% SimdTestOp⟩

/-- Flags of an ordered compare: unordered → ZF PF CF = 111, greater → 000, less → 001,
equal → 100; OF SF AF cleared. -/
def FlagsOut.compare (unordered lt eq : Bool) : FlagsOut :=
  { zf := unordered || eq, pf := unordered, cf := unordered || lt, of := false, sf := false,
    af := false }

/-- ZF := (a AND b) = 0 and CF := (NOT a AND b) = 0 over the bits selected by `mask`. -/
def FlagsOut.test {n} (mask a b : BitVec n) : FlagsOut :=
  { zf := a &&& b &&& mask == 0, cf := ~~~a &&& b &&& mask == 0, of := false, sf := false,
    af := false, pf := false }

/-- The status flags set for operands `(src1, src2)`. -/
def SimdTestOp.interp {n} : SimdTestOp → BitVec n → BitVec n → FlagsOut
  | .ptest, a, b => .test (.allOnes n) a b
  | .testps, a, b => .test (.ofLanes n 32 fun _ => .twoPow 32 31) a b
  | .testpd, a, b => .test (.ofLanes n 64 fun _ => .twoPow 64 63) a b
  | .ucomiss, a, b | .comiss, a, b =>
    let (x, y) := ((a.lane 32 0).toFloat32, (b.lane 32 0).toFloat32)
    .compare (x.isNaN || y.isNaN) (x < y) (x == y)
  | .ucomisd, a, b | .comisd, a, b =>
    let (x, y) := ((a.lane 64 0).toFloat, (b.lane 64 0).toFloat)
    .compare (x.isNaN || y.isNaN) (x < y) (x == y)

/-- The size in bytes of a memory operand, if smaller than the vector (scalar operations). -/
def SimdTestOp.memBytes? : SimdTestOp → Option Nat
  | .ucomiss | .comiss => some 4
  | .ucomisd | .comisd => some 8
  | .ptest | .testps | .testpd => none
