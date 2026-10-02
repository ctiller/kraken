module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Unary SSE/AVX operations `op src, dst` (`AvxOperation.un`):
`dst := op(src)` on the whole vector. -/

@[expose] public section

inductive SimdUnOp
  | pabsb | pabsw | pabsd
  | pmovzxbw | pmovzxbd | pmovzxbq | pmovzxwd | pmovzxwq | pmovzxdq
  | pmovsxbw | pmovsxbd | pmovsxbq | pmovsxwd | pmovsxwq | pmovsxdq
  | movshdup | movsldup | movddup
  | sqrtps | sqrtpd
  | cvtdq2ps | cvtps2dq | cvttps2dq
  | cvtdq2pd | cvtps2pd
  | cvtpd2ps | cvtpd2dq | cvttpd2dq
  | cvtph2ps
  | phminposuw
  | pbroadcastb | pbroadcastw | pbroadcastd | pbroadcastq
  | broadcastss | broadcastsd
  | broadcasti128 | broadcastf128
  | aesimc
  | movq | movd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdUnOp := ⟨mnemonics% SimdUnOp⟩

/-- Whether this SIMD unary operation narrows a 64-bit element to a 32-bit element,
writing to an xmm destination (with upper bits zeroed for VEX.256). -/
def SimdUnOp.isNarrowing : SimdUnOp → Bool
  | .cvtpd2ps | .cvtpd2dq | .cvttpd2dq => true
  | _ => false

def SimdUnOp.interp {n} : SimdUnOp → BitVec n → BitVec n
  | .pabsb => .map1 8 BitVec.abs | .pabsw => .map1 16 BitVec.abs | .pabsd => .map1 32 BitVec.abs
  | .pmovzxbw => fun a => .ofLanes n 16 fun i => (a.lane 8 i).zeroExtend 16
  | .pmovzxbd => fun a => .ofLanes n 32 fun i => (a.lane 8 i).zeroExtend 32
  | .pmovzxbq => fun a => .ofLanes n 64 fun i => (a.lane 8 i).zeroExtend 64
  | .pmovzxwd => fun a => .ofLanes n 32 fun i => (a.lane 16 i).zeroExtend 32
  | .pmovzxwq => fun a => .ofLanes n 64 fun i => (a.lane 16 i).zeroExtend 64
  | .pmovzxdq => fun a => .ofLanes n 64 fun i => (a.lane 32 i).zeroExtend 64
  | .pmovsxbw => fun a => .ofLanes n 16 fun i => (a.lane 8 i).signExtend 16
  | .pmovsxbd => fun a => .ofLanes n 32 fun i => (a.lane 8 i).signExtend 32
  | .pmovsxbq => fun a => .ofLanes n 64 fun i => (a.lane 8 i).signExtend 64
  | .pmovsxwd => fun a => .ofLanes n 32 fun i => (a.lane 16 i).signExtend 32
  | .pmovsxwq => fun a => .ofLanes n 64 fun i => (a.lane 16 i).signExtend 64
  | .pmovsxdq => fun a => .ofLanes n 64 fun i => (a.lane 32 i).signExtend 64
  | .movshdup => fun a => .ofLanes n 32 fun i => a.lane 32 (i ||| 1)
  | .movsldup => fun a => .ofLanes n 32 fun i => a.lane 32 (i - i % 2)
  | .movddup => fun a => .ofLanes n 64 fun i => a.lane 64 (i - i % 2)
  | .sqrtps => .map1 32 (sseUnOp Float32.sqrt)
  | .sqrtpd => .map1 64 (sseUnOp64 Float.sqrt)
  | .cvtdq2ps => .map1 32 fun x => FpFmt.f32.ofInt x.toInt
  | .cvtps2dq => .map1 32 (FpFmt.f32.toInt 32 0)
  | .cvttps2dq => .map1 32 (FpFmt.f32.toInt 32 3)
  | .cvtdq2pd => fun a => .ofLanes n 64 fun i => FpFmt.f64.ofInt (a.lane 32 i).toInt
  | .cvtps2pd => fun a => .ofLanes n 64 fun i => FpFmt.f32.convert .f64 0 (a.lane 32 i)
  | .cvtpd2ps => fun a => .ofLanes n 32 fun i => if i < n / 64 then FpFmt.f64.convert .f32 0 (a.lane 64 i) else 0
  | .cvtpd2dq => fun a => .ofLanes n 32 fun i => if i < n / 64 then FpFmt.f64.toInt 32 0 (a.lane 64 i) else 0
  | .cvttpd2dq => fun a => .ofLanes n 32 fun i => if i < n / 64 then FpFmt.f64.toInt 32 3 (a.lane 64 i) else 0
  | .cvtph2ps => fun a => .ofLanes n 32 fun i => f16ToF32 (a.lane 16 i)
  | .phminposuw => fun a =>
    let best := (List.range 8).foldl (fun m i => min m ((a.lane 16 i).toNat * 8 + i)) (0x10000 * 8)
    (BitVec.ofNat 3 (best % 8) ++ BitVec.ofNat 16 (best / 8)).zeroExtend n
  | .aesimc => fun a => .ofLanes n 128 fun i => aesInvMixColumns (a.lane 128 i)
  | .pbroadcastb => fun a => .ofLanes n 8 fun _ => a.lane 8 0
  | .pbroadcastw => fun a => .ofLanes n 16 fun _ => a.lane 16 0
  | .pbroadcastd | .broadcastss => fun a => .ofLanes n 32 fun _ => a.lane 32 0
  | .pbroadcastq | .broadcastsd => fun a => .ofLanes n 64 fun _ => a.lane 64 0
  | .broadcasti128 | .broadcastf128 => fun a => .ofLanes n 128 fun _ => a.lane 128 0
  | .movq => fun a => (a.extractLsb' 0 64).zeroExtend n
  | .movd => fun a => (a.extractLsb' 0 32).zeroExtend n

/-- The size in bytes of a memory operand for a vector of `bytes` bytes, if smaller (e.g. for
widening conversions). -/
def SimdUnOp.memBytes? : SimdUnOp → Nat → Option Nat
  | .pmovzxbw, bytes | .pmovsxbw, bytes => some (bytes / 2)
  | .pmovzxbd, bytes | .pmovsxbd, bytes => some (bytes / 4)
  | .pmovzxbq, bytes | .pmovsxbq, bytes => some (bytes / 8)
  | .pmovzxwd, bytes | .pmovsxwd, bytes => some (bytes / 2)
  | .pmovzxwq, bytes | .pmovsxwq, bytes => some (bytes / 4)
  | .pmovzxdq, bytes | .pmovsxdq, bytes => some (bytes / 2)
  | .cvtdq2pd, bytes | .cvtps2pd, bytes | .cvtph2ps, bytes => some (bytes / 2)
  | .movddup, 16 => some 8
  | .pbroadcastb, _ => some 1
  | .pbroadcastw, _ => some 2
  | .pbroadcastd, _ | .broadcastss, _ => some 4
  | .pbroadcastq, _ | .broadcastsd, _ => some 8
  | .broadcasti128, _ | .broadcastf128, _ => some 16
  | .movq, _ => some 8
  | .movd, _ => some 4
  | _, _ => none
