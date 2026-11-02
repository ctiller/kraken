module

/-
  Parser and AT&T/Intel printer round-trip tests for `SimdTestOp` (`ptest`,
  `vtestps`, `vtestpd`, `ucomiss`, `ucomisd`, `comiss`, `comisd`).
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel
import all Kraken.X64.PrintATTTests
meta import all Kraken.X64.PrintATTTests

open Kraken.X64 Kraken.X64.Parser

/-- info: [] -/
#guard_msgs in
#eval failing SimdTestOp (fun _ mn => [s!"{mn} (%rsp), %xmm1", s!"v{mn} %xmm3, %xmm4"])

def simdTestCorpus : List String := [
  "ptest %xmm0, %xmm1", "ptest 16(%rsp), %xmm2",
  "vptest %xmm0, %xmm1", "vptest 16(%rsp), %xmm2",
  "vptest %ymm0, %ymm1", "vptest 32(%rsp), %ymm2",
  "vtestps %xmm0, %xmm1", "vtestps 16(%rsp), %xmm2",
  "vtestps %ymm0, %ymm1", "vtestps 32(%rsp), %ymm2",
  "vtestpd %xmm0, %xmm1", "vtestpd 16(%rsp), %xmm2",
  "vtestpd %ymm0, %ymm1", "vtestpd 32(%rsp), %ymm2",
  "ucomiss %xmm1, %xmm0", "ucomiss 4(%rsp), %xmm0",
  "vucomiss %xmm1, %xmm0", "vucomiss 4(%rsp), %xmm0",
  "ucomisd %xmm1, %xmm0", "ucomisd 8(%rsp), %xmm0",
  "vucomisd %xmm1, %xmm0", "vucomisd 8(%rsp), %xmm0",
  "comiss %xmm1, %xmm0", "comiss 4(%rsp), %xmm0",
  "vcomiss %xmm1, %xmm0", "vcomiss 4(%rsp), %xmm0",
  "comisd %xmm1, %xmm0", "comisd 8(%rsp), %xmm0",
  "vcomisd %xmm1, %xmm0", "vcomisd 8(%rsp), %xmm0",
  "ucomiss 4(%esp), %xmm0", "vptest 32(%eax), %ymm1"
]

/-- info: [] -/
#guard_msgs in
#eval simdTestCorpus.filter (!roundtrips ·)

#guard match
    parse "ptest (%rsp), %xmm1",
    parse "vptest (%rsp), %ymm1",
    parse "vtestps 32(%rsp), %ymm2",
    parse "vtestpd %xmm1, %xmm2",
    parse "ucomiss 4(%rsp), %xmm0",
    parse "vucomisd 8(%rsp), %xmm1",
    parse "comiss %xmm1, %xmm0",
    parse "vcomisd 16(%rsp), %xmm2" with
  | .ok [d1], .ok [d2], .ok [d3], .ok [d4], .ok [d5], .ok [d6], .ok [d7], .ok [d8] =>
    toString d1 == "ptest xmm1, XMMWORD PTR [rsp+0]" &&
    toString d2 == "vptest ymm1, YMMWORD PTR [rsp+0]" &&
    toString d3 == "vtestps ymm2, YMMWORD PTR [rsp+32]" &&
    toString d4 == "vtestpd xmm2, xmm1" &&
    toString d5 == "ucomiss xmm0, DWORD PTR [rsp+4]" &&
    toString d6 == "vucomisd xmm1, QWORD PTR [rsp+8]" &&
    toString d7 == "comiss xmm0, xmm1" &&
    toString d8 == "vcomisd xmm2, QWORD PTR [rsp+16]"
  | _, _, _, _, _, _, _, _ => false
