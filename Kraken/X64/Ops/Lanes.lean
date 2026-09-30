module

/-! Pure helpers for SIMD opcode semantics: lanes of bit vectors, saturation, and SSE floats. -/

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

/-- `v` saturated to the signed range of `k` bits. -/
def satS (k : Nat) (v : Int) : BitVec k := .ofInt k (max (-2 ^ (k - 1)) (min (2 ^ (k - 1) - 1) v))

/-- `v` saturated to the unsigned range of `k` bits. -/
def satU (k : Nat) (v : Int) : BitVec k := .ofInt k (max 0 (min (2 ^ k - 1) v))

def toFloat32 (v : BitVec 32) : Float32 := Float32.ofBits (UInt32.ofBitVec v)
end BitVec

def Float32.toBitVec (f : Float32) : BitVec 32 := UInt32.toBitVec (Float32.toBits f)

/-- An SSE single-precision operation on one lane: a NaN operand propagates (quieted, the first
operand winning), and an invalid operation gives the default NaN ("QNaN floating-point
indefinite"). Lean's `Float32` would instead canonicalize every NaN to `0x7fc00000`. -/
def sseBinOp (op : Float32 → Float32 → Float32) (a b : BitVec 32) : BitVec 32 :=
  if a.toFloat32.isNaN then a ||| 0x400000#32
  else if b.toFloat32.isNaN then b ||| 0x400000#32
  else let r := op a.toFloat32 b.toFloat32; if r.isNaN then 0xffc00000#32 else r.toBitVec
