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

def toFloat32 (v : BitVec 32) : Float32 := Float32.ofBits (UInt32.ofBitVec v)

/-- Replaces the low `n` bits of `old` with `new`, keeping the upper bits of `old`. -/
def replaceLow {w n} (old : BitVec w) (new : BitVec n) : BitVec w :=
  (BitVec.append (old.extractLsb' n (w - n)) new).setWidth _
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

/-- cvtss2sd: converts single to double, quieting SNaN. -/
def sseCvtss2sd (a : BitVec 32) : BitVec 64 :=
  let exp := (a.extractLsb' 23 8).toNat
  let frac := (a.extractLsb' 0 23).toNat
  if exp == 255 then
    if frac == 0 then
      BitVec.append (a.extractLsb' 31 1) 0x7ff000000000000#63
    else
      BitVec.append (a.extractLsb' 31 1) (BitVec.append 0x7ff#11 (BitVec.append (a.extractLsb' 22 1 ||| 1#1) (BitVec.append (a.extractLsb' 0 22) 0#29)))
  else
    a.toFloat32.toFloat.toBitVec

/-- cvtsd2ss: converts double to single, quieting SNaN. -/
def sseCvtsd2ss (a : BitVec 64) : BitVec 32 :=
  let exp := (a.extractLsb' 52 11).toNat
  let frac := (a.extractLsb' 0 52).toNat
  if exp == 2047 then
    if frac == 0 then
      BitVec.append (a.extractLsb' 63 1) 0x7f800000#31
    else
      let frac22 := a.extractLsb' 29 22
      BitVec.append (a.extractLsb' 63 1) (BitVec.append 0xff#8 (BitVec.append (a.extractLsb' 51 1 ||| 1#1) frac22))
  else
    a.toFloat.toFloat32.toBitVec

/-- cvtps2dq lane: float32 to int32 with round-to-nearest-even; NaN/overflow -> 0x80000000. -/
def sseCvtps2dqLane (v : BitVec 32) : BitVec 32 :=
  let sign := v.msb
  let exp := (v.extractLsb' 23 8).toNat
  let frac := (v.extractLsb' 0 23).toNat
  if exp == 255 then 0x80000000#32
  else if exp < 126 then 0#32
  else if exp == 126 then
    if frac > 0 then (if sign then (-1#32) else 1#32) else 0#32
  else
    let shift := exp - 127
    if shift > 30 then
      if sign && shift == 31 && frac == 0 then 0x80000000#32
      else 0x80000000#32
    else
      let mant := frac + (1 <<< 23)
      let (intVal, roundBit, sticky) :=
        if shift >= 23 then
          (mant <<< (shift - 23), false, false)
        else
          let drop := 23 - shift
          let iv := mant >>> drop
          let rb := (mant &&& (1 <<< (drop - 1))) != 0
          let st := (mant &&& ((1 <<< (drop - 1)) - 1)) != 0
          (iv, rb, st)
      let inc := roundBit && (sticky || (intVal &&& 1 != 0))
      let intValRounded := if inc then intVal + 1 else intVal
      if sign then
        let res := - (intValRounded : Int)
        if res < -2147483648 || res > 2147483647 then 0x80000000#32 else BitVec.ofInt 32 res
      else
        if intValRounded > 2147483647 then 0x80000000#32 else BitVec.ofNat 32 intValRounded

/-- cvttps2dq lane: float32 to int32 with truncation; NaN/overflow -> 0x80000000. -/
def sseCvttps2dqLane (v : BitVec 32) : BitVec 32 :=
  let sign := v.msb
  let exp := (v.extractLsb' 23 8).toNat
  let frac := (v.extractLsb' 0 23).toNat
  if exp == 255 then 0x80000000#32
  else if exp < 127 then 0#32
  else
    let shift := exp - 127
    if shift > 30 then
      if sign && shift == 31 && frac == 0 then 0x80000000#32
      else 0x80000000#32
    else
      let mant := frac + (1 <<< 23)
      let intVal := if shift >= 23 then mant <<< (shift - 23) else mant >>> (23 - shift)
      if sign then
        let res := - (intVal : Int)
        if res < -2147483648 then 0x80000000#32 else BitVec.ofInt 32 res
      else
        if intVal > 2147483647 then 0x80000000#32 else BitVec.ofNat 32 intVal

/-- cvtpd2dq lane: float64 to int32 with round-to-nearest-even; NaN/overflow -> 0x80000000. -/
def sseCvtpd2dqLane (v : BitVec 64) : BitVec 32 :=
  let sign := v.msb
  let exp := (v.extractLsb' 52 11).toNat
  let frac := (v.extractLsb' 0 52).toNat
  if exp == 2047 then 0x80000000#32
  else if exp < 1022 then 0#32
  else if exp == 1022 then
    if frac > 0 then (if sign then (-1#32) else 1#32) else 0#32
  else
    let shift := exp - 1023
    if shift > 30 then
      if sign && shift == 31 && frac == 0 then 0x80000000#32
      else 0x80000000#32
    else
      let mant := frac + (1 <<< 52)
      let drop := 52 - shift
      let iv := mant >>> drop
      let rb := (mant &&& (1 <<< (drop - 1))) != 0
      let st := (mant &&& ((1 <<< (drop - 1)) - 1)) != 0
      let inc := rb && (st || (iv &&& 1 != 0))
      let intValRounded := if inc then iv + 1 else iv
      if sign then
        let res := - (intValRounded : Int)
        if res < -2147483648 || res > 2147483647 then 0x80000000#32 else BitVec.ofInt 32 res
      else
        if intValRounded > 2147483647 then 0x80000000#32 else BitVec.ofNat 32 intValRounded

/-- cvttpd2dq lane: float64 to int32 with truncation; NaN/overflow -> 0x80000000. -/
def sseCvttpd2dqLane (v : BitVec 64) : BitVec 32 :=
  let sign := v.msb
  let exp := (v.extractLsb' 52 11).toNat
  let frac := (v.extractLsb' 0 52).toNat
  if exp == 2047 then 0x80000000#32
  else if exp < 1023 then 0#32
  else
    let shift := exp - 1023
    if shift > 30 then
      if sign && shift == 31 && frac == 0 then 0x80000000#32
      else 0x80000000#32
    else
      let mant := frac + (1 <<< 52)
      let intVal := mant >>> (52 - shift)
      if sign then
        let res := - (intVal : Int)
        if res < -2147483648 then 0x80000000#32 else BitVec.ofInt 32 res
      else
        if intVal > 2147483647 then 0x80000000#32 else BitVec.ofNat 32 intVal

