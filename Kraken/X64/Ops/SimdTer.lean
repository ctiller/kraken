module

public import Kraken.X64.Mnemonic
public import Kraken.X64.Ops.Lanes
public import Kraken.X64.Ops.SimdCrypto
public import Kraken.X64.Ops.SoftFloat
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Three-source SSE/AVX operations, on the whole vector:
* variable blends `op %xmm0, src, dst` (`AvxOperation.sseBlendv`: `dst := op(dst, src, xmm0)`) and
  `vop mask, src2, src1, dst` (`.vexBlendv`: `dst := op(src1, src2, mask)`);
* fused multiply-adds `vop src3, src2, dst` (`.fma`: `dst := op(dst, src2, src3)`). -/

@[expose] public section

/-- Operations with an implicit `xmm0` third source: variable blends, and `sha256rnds2`. -/
inductive SimdBlendvOp
  | pblendvb | blendvps | blendvpd
  | sha256rnds2
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic SimdBlendvOp := ⟨mnemonics% SimdBlendvOp⟩

/-- Selects each element of `b` whose corresponding `mask` element has its top bit set, else `a`;
or runs two rounds of SHA256 for `sha256rnds2`. -/
def SimdBlendvOp.interp {n} (op : SimdBlendvOp) (a b mask : BitVec n) : BitVec n :=
  match op with
  | .sha256rnds2 => .ofLanes n 128 fun laneIdx =>
    sha256Rnds2 (a.lane 128 laneIdx) (b.lane 128 laneIdx) (mask.lane 128 laneIdx)
  | _ =>
    let k := match op with | .pblendvb => 8 | .blendvps => 32 | _ => 64
    .ofLanes n k fun i => if (mask.lane k i).msb then b.lane k i else a.lane k i

inductive FmaKind | fmadd | fmsub | fnmadd | fnmsub | fmaddsub | fmsubadd
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr
inductive FmaOrder | «132» | «213» | «231»
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr
instance : Mnemonic FmaKind := ⟨mnemonics% FmaKind⟩
instance : Mnemonic FmaOrder := ⟨mnemonics% FmaOrder⟩

/-- FMA opcodes `v<kind><order><type>`, e.g. `vfmadd231ps`. -/
structure SimdFmaOp where
  kind : FmaKind
  order : FmaOrder
  type : FpType
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

namespace SimdFmaOp
def scalar (op : SimdFmaOp) : Bool := op.type.scalar
def elemBits (op : SimdFmaOp) : Nat := op.type.elemBits

instance : Mnemonic SimdFmaOp where
  names := Id.run do
    let mut r := #[]
    for (k, kn) in Mnemonic.names do for (o, on) in Mnemonic.names do for (t, tn) in Mnemonic.names do
      let op : SimdFmaOp := ⟨k, o, t⟩
      -- The alternating kinds have no scalar forms.
      unless op.scalar && k matches .fmaddsub | .fmsubadd do r := r.push (op, kn ++ on ++ tn)
    return r

/-- `dst := op(dst, src2, src3)`, element by element (only the lowest one for scalar types, the
others coming from `dst`). The order `132` computes `dst * src3 + src2`, `213` `src2 * dst + src3`
and `231` `src2 * src3 + dst`; the kind picks the signs (alternating kinds: `fmaddsub` subtracts
in even elements and adds in odd ones, `fmsubadd` the reverse). -/
def interp {n} (op : SimdFmaOp) (a b c : BitVec n) : BitVec n :=
  let fmt : FpFmt := if op.type matches .ps | .ss then .f32 else .f64
  let k := fmt.bits
  let elem (i : Nat) : BitVec k :=
    let (x, y, z) := match op.order with
      | .«132» => (a.lane k i, c.lane k i, b.lane k i)
      | .«213» => (b.lane k i, a.lane k i, c.lane k i)
      | .«231» => (b.lane k i, c.lane k i, a.lane k i)
    let (negP, negC) := match op.kind with
      | .fmadd => (false, false) | .fmsub => (false, true)
      | .fnmadd => (true, false) | .fnmsub => (true, true)
      | .fmaddsub => (false, i % 2 == 0) | .fmsubadd => (false, i % 2 == 1)
    fmt.fma negP negC x y z
  if op.scalar then a.replaceLow (elem 0) else .ofLanes n k elem

/-- The size in bytes of a memory operand, if smaller than the vector (scalar types). -/
def memBytes? (op : SimdFmaOp) : Option Nat := op.type.memBytes?
end SimdFmaOp

