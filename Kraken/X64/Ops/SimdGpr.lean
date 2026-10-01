module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! SSE/AVX conversions between vector registers and GPRs/memory:
`SimdToGprOp` (vector to GPR/mask), `SimdExtractOp` (lane extract to GPR/mem),
and `SimdInsertOp` (lane insert from GPR/mem). -/

@[expose] public section

inductive SimdToGprOp
  | pmovmskb | movmskps | movmskpd
  | cvtss2si | cvttss2si | cvtsd2si | cvttsd2si
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdToGprOp := ⟨mnemonics% SimdToGprOp⟩

/-- Forms a mask from the MSB of each `k`-bit lane of `src`. -/
def msbMask {n} (k : Nat) (src : BitVec n) (bits : Nat) : BitVec bits :=
  let mask : Nat := (List.range (n / k)).foldl (fun acc i =>
    if (src.lane k i).msb then acc ||| (1 <<< i) else acc) 0
  BitVec.ofNat bits mask

def SimdToGprOp.interp {n} (op : SimdToGprOp) (bits : Nat) (src : BitVec n) : BitVec bits :=
  match op with
  | .pmovmskb => msbMask 8 src bits
  | .movmskps => msbMask 32 src bits
  | .movmskpd => msbMask 64 src bits
  | .cvtss2si => FpFmt.f32.toInt bits 0 (src.lane 32 0)
  | .cvttss2si => FpFmt.f32.toInt bits 3 (src.lane 32 0)
  | .cvtsd2si => FpFmt.f64.toInt bits 0 (src.lane 64 0)
  | .cvttsd2si => FpFmt.f64.toInt bits 3 (src.lane 64 0)

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

/-- Whether GNU as takes an `l` or `q` suffix, giving the width of a GPR destination. -/
def SimdExtractOp.sized (op : SimdExtractOp) : Bool := op == .pextrw

def SimdExtractOp.memBits (op : SimdExtractOp) : Nat :=
  match op with
  | .pextrb => 8
  | .pextrw => 16
  | .pextrd | .extractps | .movd => 32
  | .pextrq | .movq | .movlps | .movhps | .movlpd | .movhpd => 64

def SimdExtractOp.interp {n} (op : SimdExtractOp) (bits : Nat) (src : BitVec n) (imm : BitVec 8) : BitVec bits :=
  match op with
  | .pextrb | .pextrw | .pextrd | .pextrq | .extractps =>
    let k := op.memBits
    (src.lane k (imm.toNat % (n / k))).zeroExtend bits
  | .movd | .movq => src.setWidth bits
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

/-- The width of a memory source; for `cvtsi2ss`/`cvtsi2sd`, that of an unsuffixed one, which GNU as
reads as 32 bits (`l`). -/
def SimdInsertOp.memBits (op : SimdInsertOp) : Nat :=
  match op with
  | .pinsrb => 8
  | .pinsrw => 16
  | .pinsrd | .cvtsi2ss | .cvtsi2sd | .movd => 32
  | .pinsrq | .movq | .movlps | .movhps | .movlpd | .movhpd => 64

/-- Whether an `l` or `q` suffix gives the width of a memory source (else `memBits`). -/
def SimdInsertOp.sizedMem (op : SimdInsertOp) : Bool := op matches .cvtsi2ss | .cvtsi2sd

/-- Whether GNU as takes an `l` or `q` suffix, giving the width of a GPR source (or of a memory
source if `sizedMem`). -/
def SimdInsertOp.sized (op : SimdInsertOp) : Bool := op == .pinsrw || op.sizedMem

def SimdInsertOp.twoOperand : SimdInsertOp → Bool
  | .movd | .movq => true
  | _ => false

def SimdInsertOp.interp {n} (op : SimdInsertOp) (old : BitVec n) (bits : Nat) (src : BitVec bits) (imm : BitVec 8) : BitVec n :=
  match op with
  | .pinsrb | .pinsrw | .pinsrd | .pinsrq | .movlps | .movlpd | .movhps | .movhpd =>
    let k := op.memBits
    let idx := match op with | .movlps | .movlpd => 0 | .movhps | .movhpd => 1 | _ => imm.toNat % (n / k)
    .ofLanes n k fun i => if i == idx then src.extractLsb' 0 k else old.lane k i
  | .cvtsi2ss => old.replaceLow (FpFmt.f32.ofInt (BitVec.toInt src))
  | .cvtsi2sd => old.replaceLow (FpFmt.f64.ofInt (BitVec.toInt src))
  | .movd | .movq => src.setWidth 64 |>.setWidth n
