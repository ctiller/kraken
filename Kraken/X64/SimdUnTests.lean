module

/-
  Parser, AT&T/Intel printer round-trip, and semantics tests for `SimdUnOp`.
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel
import all Kraken.X64.PrintATTTests
meta import all Kraken.X64.PrintATTTests
import all Kraken.X64.SemanticsTests
meta import all Kraken.X64.SemanticsTests

open Kraken.X64 Kraken.X64.Parser

/-- info: [] -/
#guard_msgs in
#eval failing SimdUnOp (fun op mn =>
  if op.isNarrowing then
    [s!"{mn} (%rsp), %xmm1", s!"v{mn} %ymm3, %xmm4", s!"v{mn}x (%rsp), %xmm4", s!"v{mn}y (%rsp), %xmm4"]
  else
    [s!"{mn} (%rsp), %xmm1", s!"v{mn} %{if (op.memBytes? 32).isSome then "x" else "y"}mm3, %ymm4"])

def simdUnAccepted : List String := [
  "movq %xmm1, %xmm0", "vmovq %xmm1, %xmm0",
  -- vcvtpd2ps, vcvtpd2dq, vcvttpd2dq narrowing operand and suffix forms
  "vcvtpd2ps %ymm1, %xmm0", "vcvtpd2ps %xmm1, %xmm0", "vcvtpd2psx (%rax), %xmm0",
  "vcvtpd2psy (%rax), %xmm0", "cvtpd2ps (%rax), %xmm0", "vcvtpd2dq %ymm1, %xmm0",
  "vcvtpd2dqy (%rax), %xmm0", "vcvttpd2dq %ymm1, %xmm0", "vcvttpd2dqx (%rax), %xmm0",
  -- broadcasts
  "vbroadcasti128 (%rsp), %ymm1", "vbroadcastss %xmm1, %ymm1"
]

/-- info: [] -/
#guard_msgs in
#eval simdUnAccepted.filter (!roundtrips ·)

def simdUnRejected : List String := [
  -- vcvtpd2ps, vcvtpd2dq, vcvttpd2dq memory operand requires x/y suffix
  "vcvtpd2ps (%rax), %xmm0",
  -- EVEX-only registers
  "vpmovzxbw (%rsp), %zmm3", "vpmovzxbw %xmm0, %zmm3", "vbroadcastss %xmm16, %ymm1"
]

/-- info: [] -/
#guard_msgs in
#eval simdUnRejected.filter (parse · matches .ok _)

#guard match
    parse "pmovzxbw (%rsp), %xmm1",
    parse "vpmovzxbw (%rsp), %ymm1",
    parse "vpmovzxbw %xmm0, %ymm1",
    parse "vcvtpd2ps %ymm1, %xmm0",
    parse "vcvtpd2psy (%rax), %xmm0",
    parse "vbroadcasti128 (%rsp), %ymm1",
    parse "vpbroadcastb (%rsp), %ymm1",
    parse "movddup (%rsp), %xmm1",
    parse "vmovddup (%rsp), %ymm1" with
  | .ok [d1], .ok [d2], .ok [d3], .ok [d4], .ok [d5], .ok [d6], .ok [d7], .ok [d8], .ok [d9] =>
    toString d1 == "pmovzxbw xmm1, QWORD PTR [rsp+0]" &&
    toString d2 == "vpmovzxbw ymm1, XMMWORD PTR [rsp+0]" &&
    toString d3 == "vpmovzxbw ymm1, xmm0" &&
    toString d4 == "vcvtpd2ps xmm0, ymm1" &&
    toString d5 == "vcvtpd2ps xmm0, YMMWORD PTR [rax+0]" &&
    toString d6 == "vbroadcasti128 ymm1, XMMWORD PTR [rsp+0]" &&
    toString d7 == "vpbroadcastb ymm1, BYTE PTR [rsp+0]" &&
    toString d8 == "movddup xmm1, QWORD PTR [rsp+0]" &&
    toString d9 == "vmovddup ymm1, YMMWORD PTR [rsp+0]"
  | _, _, _, _, _, _, _, _, _ => false

/-- The widening operations, whose memory source is half as wide as the destination. -/
private def widening : List SimdUnOp :=
  [.pmovzxbw, .pmovsxbw, .pmovzxwd, .pmovsxwd, .pmovzxdq, .pmovsxdq, .cvtdq2pd, .cvtps2pd, .cvtph2ps]

-- With a zmm destination, their memory source (e.g. `vpmovzxbw (%rsp), %zmm0`) is 32 bytes:
#guard widening.all fun op => loadZmm (op.memBytes? 64) bytes32 == some (lanes 512 8 32 (· + 1))
-- ... so a 31-byte mapping doesn't suffice.
#guard widening.all fun op => loadZmm (op.memBytes? 64) (bytes32.take 31) == none
