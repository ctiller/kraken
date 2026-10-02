module

/-
  Parser, AT&T/Intel printer round-trip, and concrete semantics tests for `SimdUnImmOp`,
  `SimdBinImmOp`, and floating-point compare pseudo-ops (`cmp{pred}{ps,pd,ss,sd}`).
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel
import Kraken.X64.Semantics
meta import Kraken.X64.Semantics
import all Kraken.X64.PrintATTTests
meta import all Kraken.X64.PrintATTTests

open Kraken.X64 Kraken.X64.Parser

/-- info: [] -/
#guard_msgs in
#eval failing SimdUnImmOp (fun _ mn => [s!"{mn} $1, (%rsp), %xmm1", s!"v{mn} $255, %ymm3, %ymm4"]) ++
  failing SimdBinImmOp (fun _ mn => [s!"{mn} $1, (%rsp), %xmm1", s!"v{mn} $2, %ymm2, %ymm3, %ymm4"])

def simdImmRejected : List String := [
  -- Legacy compare pseudo-ops only exist for predicates 0-7
  "cmpeq_uqps %xmm1, %xmm2",
  "cmpngepd 16(%rsp), %xmm2",
  "cmpeq_oqps %xmm1, %xmm2"
]

/-- info: [] -/
#guard_msgs in
#eval simdImmRejected.filter (parse · matches .ok _)

def simdImmAccepted : List String := [
  -- VEX compare pseudo-ops for predicates 8-31
  "vcmpeq_uqps %xmm1, %xmm2, %xmm3", "vcmpeq_uqps %ymm1, %ymm2, %ymm3",
  "vcmpeq_uqpd 16(%rsp), %ymm2, %ymm3", "vcmptrue_usps %xmm1, %xmm2, %xmm3",
  "vcmpeq_uqss %xmm1, %xmm2, %xmm3", "vcmpeq_uqsd 16(%rsp), %xmm2, %xmm3",
  "vcmptrue_uspd 16(%rsp), %ymm2, %ymm3",
  -- vpermilps/vpermilpd immediate forms
  "vpermilps $1, %xmm0, %xmm1", "vpermilpd $1, %xmm0, %xmm1"
]

/-- info: [] -/
#guard_msgs in
#eval simdImmAccepted.filter (!roundtrips ·)

/-- `s` parsed and printed, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

-- Compare pseudo-ops `[v]cmp{pred}{type}` are `[v]cmp{type} $pred`, `pred` being the index in
-- `cmpPreds` of any spelling (VEX) or of the first spelling of predicates 0-7 (legacy).
/-- info: [] -/
#guard_msgs in
#eval (cmpPreds.toList.zipIdx.flatMap fun (preds, i) => preds.zipIdx.flatMap fun (p, j) =>
  ["ps", "pd", "ss", "sd"].flatMap fun t =>
    [(s!"vcmp{p}{t} 16(%rsp), %xmm2, %xmm3", some s!"vcmp{t} ${i}, 16(%rsp), %xmm2, %xmm3"),
     (s!"cmp{p}{t} 16(%rsp), %xmm2",
      if i < 8 && j == 0 then some s!"cmp{t} ${i}, 16(%rsp), %xmm2" else none)]
  ).filter fun (s, expected) => reprinted s != expected

#guard [("cmpltss %xmm1, %xmm2", "cmpss $1, %xmm1, %xmm2"),
  ("cmpordpd (%rax), %xmm2", "cmppd $7, (%rax), %xmm2"),
  ("vcmpneq_oqps %xmm1, %xmm2, %xmm3", "vcmpps $12, %xmm1, %xmm2, %xmm3"),
  ("vcmpnge_uqsd %xmm1, %xmm2, %xmm3", "vcmpsd $25, %xmm1, %xmm2, %xmm3"),
  ("vcmptrue_uspd %ymm1, %ymm2, %ymm3", "vcmppd $31, %ymm1, %ymm2, %ymm3")].all
  fun (s, e) => reprinted s == some e

-- Intel syntax formatting for `.unImm`, `.sseImm`, and `.vexImm` (including scalar 4B/8B memory widths).
#guard match
    parse "pshufd $27, 16(%rsp), %xmm1",
    parse "vpermq $78, (%rsp), %ymm2",
    parse "shufps $228, 16(%rsp), %xmm0",
    parse "vshufpd $5, 32(%rsp), %ymm1, %ymm2",
    parse "insertps $16, 4(%rsp), %xmm0",
    parse "vroundss $2, 4(%rsp), %xmm1, %xmm2",
    parse "roundsd $1, 8(%rsp), %xmm0",
    parse "vcmpss $4, 4(%rsp), %xmm1, %xmm2",
    parse "cmpsd $1, 8(%rsp), %xmm0" with
  | .ok [d1], .ok [d2], .ok [d3], .ok [d4], .ok [d5], .ok [d6], .ok [d7], .ok [d8], .ok [d9] =>
    toString d1 == "pshufd xmm1, XMMWORD PTR [rsp+16], 27" &&
    toString d2 == "vpermq ymm2, YMMWORD PTR [rsp+0], 78" &&
    toString d3 == "shufps xmm0, XMMWORD PTR [rsp+16], 228" &&
    toString d4 == "vshufpd ymm2, ymm1, YMMWORD PTR [rsp+32], 5" &&
    toString d5 == "insertps xmm0, DWORD PTR [rsp+4], 16" &&
    toString d6 == "vroundss xmm2, xmm1, DWORD PTR [rsp+4], 2" &&
    toString d7 == "roundsd xmm0, QWORD PTR [rsp+8], 1" &&
    toString d8 == "vcmpss xmm2, xmm1, DWORD PTR [rsp+4], 4" &&
    toString d9 == "cmpsd xmm0, QWORD PTR [rsp+8], 1"
  | _, _, _, _, _, _, _, _, _ => false

/-! dpps/dppd: the SDM leaves which NaNs propagate, and where they land, implementation
dependent, so any NaN in a lane's sum makes the result undefined. -/

private def lanes (n bits count : Nat) (f : Nat → Nat) : BitVec n :=
  (List.range count).foldl (fun acc i => acc ||| (BitVec.ofNat n (f i) <<< (bits * i))) 0

private def f32s (xs : List Nat) : BitVec 128 := lanes 128 32 xs.length (xs.getD · 0)
private def f64s (xs : List Nat) : BitVec 128 := lanes 128 64 xs.length (xs.getD · 0)
private def one32 := 0x3f800000
private def inf32 := 0x7f800000
private def one64 := 0x3ff0000000000000

-- One NaN product.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00001, one32, one32, one32]) (f32s [one32, one32, one32, one32]) 0xf1
#guard SimdBinImmOp.dppd.resultUndefined (f64s [0x7ff8000000000001, one64]) (f64s [one64, one64]) 0x31
-- No NaN product, but `+inf + -inf`.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [inf32, inf32 + 0x80000000, 0, 0]) (f32s [one32, one32, one32, one32]) 0x31
-- `inf * 0`.
#guard SimdBinImmOp.dppd.resultUndefined (f64s [0x7ff0000000000000, 0]) (f64s [0, 0]) 0x11
-- In the upper 128-bit lane only.
#guard SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00000] ++ f32s [one32]) (f32s [one32] ++ f32s [one32]) 0xf1
-- Defined: no NaN, the NaN is not selected, or no destination element is written.
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [inf32, one32, 0, 0]) (f32s [one32, one32, one32, one32]) 0xf1
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [one32, 0x7fc00000]) (f32s [one32, one32]) 0x11
#guard !SimdBinImmOp.dpps.resultUndefined (f32s [0x7fc00000]) (f32s [one32]) 0xf0
