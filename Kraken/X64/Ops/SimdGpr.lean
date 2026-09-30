module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

@[expose] public section

/-- Helper to convert decoded float to signed integer of `bits` width with saturation to indefinite. -/
def cvtFpToInt (sign : Bool) (v : Nat) (e : Int) (trunc : Bool) (bits : Nat) : BitVec bits :=
  let indefinite : BitVec bits := BitVec.ofInt bits (-(2 ^ (bits - 1) : Int))
  if v == 0 then 0
  else
    let i : Int :=
      if e >= 0 then (v * 2 ^ e.toNat : Nat)
      else
        let s := (-e).toNat
        let q := v / 2 ^ s
        let rem := v % 2 ^ s
        let half := 2 ^ (s - 1)
        if trunc then q
        else if rem > half || (rem == half && q % 2 == 1) then q + 1
        else q
    let res : Int := if sign then -i else i
    let minVal : Int := -(2 ^ (bits - 1) : Int)
    let maxVal : Int := (2 ^ (bits - 1) : Int) - 1
    if res < minVal || res > maxVal then indefinite
    else BitVec.ofInt bits res

def cvtFloat32ToInt (x : BitVec 32) (trunc : Bool) (bits : Nat) : BitVec bits :=
  let f := FpFmt.f32
  if f.isNaN x || f.isInf x then BitVec.ofInt bits (-(2 ^ (bits - 1) : Int))
  else
    let (sign, v, e) := f.decode x
    cvtFpToInt sign v e trunc bits

def cvtFloat64ToInt (x : BitVec 64) (trunc : Bool) (bits : Nat) : BitVec bits :=
  let f := FpFmt.f64
  if f.isNaN x || f.isInf x then BitVec.ofInt bits (-(2 ^ (bits - 1) : Int))
  else
    let (sign, v, e) := f.decode x
    cvtFpToInt sign v e trunc bits

inductive SimdToGprOp
  | pmovmskb | movmskps | movmskpd
  | cvtss2si | cvttss2si | cvtsd2si | cvttsd2si
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdToGprOp := ⟨mnemonics% SimdToGprOp⟩

def SimdToGprOp.interp {n} (op : SimdToGprOp) (bits : Nat) (src : BitVec n) : BitVec bits :=
  match op with
  | .pmovmskb =>
    let mask : Nat := (List.range (n / 8)).foldl (fun acc i =>
      if (src.lane 8 i).msb then acc ||| (1 <<< i) else acc) 0
    BitVec.ofNat bits mask
  | .movmskps =>
    let mask : Nat := (List.range (n / 32)).foldl (fun acc i =>
      if (src.lane 32 i).msb then acc ||| (1 <<< i) else acc) 0
    BitVec.ofNat bits mask
  | .movmskpd =>
    let mask : Nat := (List.range (n / 64)).foldl (fun acc i =>
      if (src.lane 64 i).msb then acc ||| (1 <<< i) else acc) 0
    BitVec.ofNat bits mask
  | .cvtss2si => cvtFloat32ToInt (src.lane 32 0) false bits
  | .cvttss2si => cvtFloat32ToInt (src.lane 32 0) true bits
  | .cvtsd2si => cvtFloat64ToInt (src.lane 64 0) false bits
  | .cvttsd2si => cvtFloat64ToInt (src.lane 64 0) true bits

def SimdToGprOp.memBytes? : SimdToGprOp → Option Nat
  | .cvtss2si | .cvttss2si => some 4
  | .cvtsd2si | .cvttsd2si => some 8
  | .pmovmskb | .movmskps | .movmskpd => none

inductive SimdExtractOp
  | pextrb | pextrw | pextrd | pextrq
  | extractps
  | movd | movq
  | movlps | movhps | movlpd | movhpd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdExtractOp := ⟨mnemonics% SimdExtractOp⟩

def SimdExtractOp.hasImm : SimdExtractOp → Bool
  | .pextrb | .pextrw | .pextrd | .pextrq | .extractps => true
  | .movd | .movq | .movlps | .movhps | .movlpd | .movhpd => false

def SimdExtractOp.memBits (op : SimdExtractOp) : Nat :=
  match op with
  | .pextrb => 8
  | .pextrw => 16
  | .pextrd | .extractps | .movd => 32
  | .pextrq | .movq | .movlps | .movhps | .movlpd | .movhpd => 64

def SimdExtractOp.interp {n} (op : SimdExtractOp) (bits : Nat) (src : BitVec n) (imm : BitVec 8) : BitVec bits :=
  let immNat := imm.toNat
  match op with
  | .pextrb =>
    let idx := immNat % (n / 8)
    (src.lane 8 idx).zeroExtend bits
  | .pextrw =>
    let idx := immNat % (n / 16)
    (src.lane 16 idx).zeroExtend bits
  | .pextrd =>
    let idx := immNat % (n / 32)
    (src.lane 32 idx).zeroExtend bits
  | .pextrq =>
    let idx := immNat % (n / 64)
    (src.lane 64 idx).zeroExtend bits
  | .extractps =>
    let idx := immNat % (n / 32)
    (src.lane 32 idx).zeroExtend bits
  | .movd | .movq =>
    let extractBits := min bits 64
    (src.extractLsb' 0 extractBits).zeroExtend bits
  | .movlps | .movlpd => (src.lane 64 0).zeroExtend bits
  | .movhps | .movhpd => (src.lane 64 1).zeroExtend bits

inductive SimdInsertOp
  | pinsrb | pinsrw | pinsrd | pinsrq
  | cvtsi2ss | cvtsi2sd
  | movlps | movhps | movlpd | movhpd
  | movd | movq
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdInsertOp := ⟨mnemonics% SimdInsertOp⟩

def SimdInsertOp.hasImm : SimdInsertOp → Bool
  | .pinsrb | .pinsrw | .pinsrd | .pinsrq => true
  | .cvtsi2ss | .cvtsi2sd | .movlps | .movhps | .movlpd | .movhpd | .movd | .movq => false

def SimdInsertOp.memBits (op : SimdInsertOp) : Nat :=
  match op with
  | .pinsrb => 8
  | .pinsrw => 16
  | .pinsrd | .cvtsi2ss | .movd => 32
  | .pinsrq | .cvtsi2sd | .movq | .movlps | .movhps | .movlpd | .movhpd => 64

def SimdInsertOp.twoOperand : SimdInsertOp → Bool
  | .movd | .movq => true
  | _ => false

def SimdInsertOp.interp {n} (op : SimdInsertOp) (old : BitVec n) (bits : Nat) (src : BitVec bits) (imm : BitVec 8) : BitVec n :=
  let immNat := imm.toNat
  match op with
  | .pinsrb =>
    let idx := immNat % (n / 8)
    .ofLanes n 8 fun i => if i == idx then (src.extractLsb' 0 8) else old.lane 8 i
  | .pinsrw =>
    let idx := immNat % (n / 16)
    .ofLanes n 16 fun i => if i == idx then (src.extractLsb' 0 16) else old.lane 16 i
  | .pinsrd =>
    let idx := immNat % (n / 32)
    .ofLanes n 32 fun i => if i == idx then (src.extractLsb' 0 32) else old.lane 32 i
  | .pinsrq =>
    let idx := immNat % (n / 64)
    .ofLanes n 64 fun i => if i == idx then (src.extractLsb' 0 64) else old.lane 64 i
  | .cvtsi2ss =>
    let fp := FpFmt.f32.ofInt (BitVec.toInt src)
    old.replaceLow fp
  | .cvtsi2sd =>
    let fp := FpFmt.f64.ofInt (BitVec.toInt src)
    old.replaceLow fp
  | .movlps | .movlpd =>
    let low64 : BitVec 64 := src.extractLsb' 0 64
    old.replaceLow low64
  | .movhps | .movhpd =>
    let low64 : BitVec 64 := src.extractLsb' 0 64
    .ofLanes n 64 fun i => if i == 1 then low64 else old.lane 64 i
  | .movd | .movq =>
    let insertBits := min bits 64
    (src.extractLsb' 0 insertBits).zeroExtend n

