module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Pure helpers for SIMD opcode semantics: lanes of bit vectors, saturation, SSE floats, and the
floating-point element types (`FpType`) shared by opcode families. -/

@[expose] public section

namespace BitVec
/-- Lane `i` of `x` viewed as `k`-bit lanes, lane 0 being the least significant. -/
def lane {n} (k i : Nat) (x : BitVec n) : BitVec k := x.extractLsb' (i * k) k

/-- The `n`-bit vector whose `k`-bit lane `i` is `f i`. -/
def ofLanes (n k : Nat) (f : Nat → BitVec k) : BitVec n :=
  (List.range (n / k)).foldl (fun acc i => acc ||| ((f i).setWidth n <<< (i * k))) 0

/-- Applies `f` to each `k`-bit lane. -/
def map1 {n} (k : Nat) (f : BitVec k → BitVec k) (a : BitVec n) : BitVec n :=
  ofLanes n k fun i => f (a.lane k i)

/-- Applies `f` to each pair of corresponding `k`-bit lanes. -/
def map2 {n} (k : Nat) (f : BitVec k → BitVec k → BitVec k) (a b : BitVec n) : BitVec n :=
  ofLanes n k fun i => f (a.lane k i) (b.lane k i)

/-- All ones (-1) if `p` is true, else 0. -/
def mask (k : Nat) (p : Bool) : BitVec k := if p then -1#k else 0#k

def toFloat32 (v : BitVec 32) : Float32 := Float32.ofBits (UInt32.ofBitVec v)
def toFloat (v : BitVec 64) : Float := Float.ofBits (UInt64.ofBitVec v)

/-- Replaces the low `n` bits of `old` with `new`, keeping the upper bits of `old`. -/
def replaceLow {w n} (old : BitVec w) (new : BitVec n) : BitVec w :=
  (BitVec.append (old.extractLsb' n (w - n)) new).setWidth _

/-- Scalar operation replacing lane 0 with `f (a.lane k 0) (b.lane k 0)`. -/
def scalar {n} (k : Nat) (f : BitVec k → BitVec k → BitVec k) (a b : BitVec n) : BitVec n :=
  a.replaceLow (f (a.lane k 0) (b.lane k 0))
end BitVec

def Float32.toBitVec (f : Float32) : BitVec 32 := UInt32.toBitVec (Float32.toBits f)
def Float.toBitVec (f : Float) : BitVec 64 := UInt64.toBitVec (Float.toBits f)

