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

/-- Packs `2 * k`-bit lanes into `k`-bit lanes with saturation `sat`: the lower half of `a`
followed by the lower half of `b`. -/
def pack {n} (k : Nat) (sat : Int → BitVec k) (a b : BitVec n) : BitVec n :=
  ofLanes n k fun i =>
    let half := n / (2 * k)
    if i < half then sat (a.lane (2 * k) i).toInt
    else sat (b.lane (2 * k) (i - half)).toInt

/-- Unpacks and interleaves the low `k`-bit lanes of `a` and `b`. -/
def unpckl {n} (k : Nat) (a b : BitVec n) : BitVec n :=
  ofLanes n k fun i => if i % 2 == 0 then a.lane k (i / 2) else b.lane k (i / 2)

/-- Unpacks and interleaves the high `k`-bit lanes of `a` and `b`. -/
def unpckh {n} (k : Nat) (a b : BitVec n) : BitVec n :=
  ofLanes n k fun i =>
    let half := n / (2 * k)
    if i % 2 == 0 then a.lane k (half + i / 2) else b.lane k (half + i / 2)

/-- Horizontal operation on one 128-bit lane: first half from pairs of `a`, second half from pairs of `b`. -/
def hop (k : Nat) (f : BitVec k → BitVec k → BitVec k) (a b : BitVec 128) : BitVec 128 :=
  ofLanes 128 k fun i =>
    let half := 128 / (2 * k)
    if i < half then f (a.lane k (2 * i)) (a.lane k (2 * i + 1))
    else f (b.lane k (2 * (i - half))) (b.lane k (2 * (i - half) + 1))

def toFloat32 (v : BitVec 32) : Float32 := Float32.ofBits (UInt32.ofBitVec v)

/-- Replaces the low `n` bits of `old` with `new`, keeping the upper bits of `old`. -/
def replaceLow {w n} (old : BitVec w) (new : BitVec n) : BitVec w :=
  (BitVec.append (old.extractLsb' n (w - n)) new).setWidth _

/-- Scalar operation replacing lane 0 with `f (a.lane k 0) (b.lane k 0)`. -/
def scalar {n} (k : Nat) (f : BitVec k → BitVec k → BitVec k) (a b : BitVec n) : BitVec n :=
  a.replaceLow (f (a.lane k 0) (b.lane k 0))
end BitVec

def Float32.toBitVec (f : Float32) : BitVec 32 := UInt32.toBitVec (Float32.toBits f)

/-- An SSE single-precision operation on one lane: a NaN operand propagates (quieted, the first
operand winning), and an invalid operation gives the default NaN ("QNaN floating-point
indefinite"). Lean's `Float32` would instead canonicalize every NaN to `0x7fc00000`. -/
def sseBinOp (op : Float32 → Float32 → Float32) (a b : BitVec 32) : BitVec 32 :=
  if a.toFloat32.isNaN then a ||| 0x400000#32
  else if b.toFloat32.isNaN then b ||| 0x400000#32
  else let r := op a.toFloat32 b.toFloat32; if r.isNaN then 0xffc00000#32 else r.toBitVec

def BitVec.toFloat (v : BitVec 64) : Float := Float.ofBits (UInt64.ofBitVec v)

def Float.toBitVec (f : Float) : BitVec 64 := UInt64.toBitVec (Float.toBits f)

/-- `sseBinOp` for double precision. -/
def sseBinOp64 (op : Float → Float → Float) (a b : BitVec 64) : BitVec 64 :=
  if a.toFloat.isNaN then a ||| 0x8000000000000#64
  else if b.toFloat.isNaN then b ||| 0x8000000000000#64
  else let r := op a.toFloat b.toFloat; if r.isNaN then 0xfff8000000000000#64 else r.toBitVec

/-- An SSE single-precision unary operation on one lane: a NaN operand propagates (quieted),
and an invalid operation (e.g. sqrt of negative non-zero) gives the default NaN. -/
def sseUnOp (op : Float32 → Float32) (a : BitVec 32) : BitVec 32 :=
  if a.toFloat32.isNaN then a ||| 0x400000#32
  else let r := op a.toFloat32; if r.isNaN then 0xffc00000#32 else r.toBitVec

/-- `sseUnOp` for double precision. -/
def sseUnOp64 (op : Float → Float) (a : BitVec 64) : BitVec 64 :=
  if a.toFloat.isNaN then a ||| 0x8000000000000#64
  else let r := op a.toFloat; if r.isNaN then 0xfff8000000000000#64 else r.toBitVec





