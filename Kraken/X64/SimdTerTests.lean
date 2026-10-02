module

/-
  Parser and AT&T/Intel printer round-trip tests for `SimdBlendvOp` (`pblendvb`,
  `blendvps`, `blendvpd`, `sha256rnds2`) and `SimdFmaOp` (`vfmadd*`, `vfmsub*`,
  `vfnmadd*`, `vfnmsub*`, `vfmaddsub*`, `vfmsubadd*`).
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

#guard let ns := (Mnemonic.names (α := SimdBlendvOp)).toList.map (·.2); ns.eraseDups == ns
#guard let ns := (Mnemonic.names (α := SimdFmaOp)).toList.map (·.2); ns.eraseDups == ns

/-- info: [] -/
#guard_msgs in
#eval failing SimdBlendvOp (fun _ mn => [
    s!"{mn} %xmm0, (%rsp), %xmm1",
    s!"{mn} (%rsp), %xmm1",
    s!"v{mn} %xmm1, (%rsp), %xmm2, %xmm3",
    s!"v{mn} %ymm1, %ymm2, %ymm3, %ymm4"
  ]) ++
  failing SimdFmaOp (fun _ mn => [
    s!"v{mn} (%rsp), %xmm1, %xmm2",
    s!"v{mn} %xmm1, %xmm2, %xmm3"
  ])

/-- Two-operand and explicit `%xmm0` forms, plus VEX blendv and FMA forms. -/
def simdTerAccepted : List String := [
  "sha256rnds2 %xmm1, %xmm2", "sha256rnds2 (%rax), %xmm2", "blendvps %xmm1, %xmm2",
  "blendvps (%rax), %xmm2", "blendvpd %xmm1, %xmm2", "blendvpd (%rax), %xmm2",
  "pblendvb %xmm1, %xmm2", "pblendvb (%rax), %xmm2", "sha256rnds2 %xmm0, %xmm1, %xmm2",
  "blendvps %xmm0, %xmm1, %xmm2", "blendvps %xmm0, %xmm2", "sha256rnds2 %xmm0, %xmm2",
  "pblendvb %xmm0, 16(%rsp), %xmm1", "blendvpd %xmm0, 16(%rsp), %xmm1",
  "vpblendvb %xmm3, 16(%rsp), %xmm2, %xmm1", "vpblendvb %ymm3, %ymm2, %ymm1, %ymm0",
  "vblendvps %xmm3, %xmm2, %xmm1, %xmm0", "vblendvpd %ymm3, 32(%rsp), %ymm2, %ymm1",
  "vfmadd132ps %ymm3, %ymm2, %ymm1", "vfmsub213pd 32(%rsp), %ymm2, %ymm1",
  "vfnmadd231ss 4(%rsp), %xmm2, %xmm1", "vfnmsub132sd 8(%rsp), %xmm2, %xmm1",
  "vfmaddsub132ps %xmm3, %xmm2, %xmm1", "vfmsubadd231pd %ymm3, %ymm2, %ymm1"
]

/-- info: [] -/
#guard_msgs in
#eval simdTerAccepted.filter (!roundtrips ·)

/-- Programs the parser rejects. -/
def simdTerRejected : List String := [
  -- Three-operand legacy blendv requires %xmm0 mask
  "blendvps %xmm3, %xmm1, %xmm2",
  "pblendvb %xmm1, %xmm2, %xmm3",
  "sha256rnds2 %xmm1, %xmm2, %xmm3",
  -- Alternating FMA kinds have no scalar forms
  "vfmaddsub132ss %xmm1, %xmm2, %xmm3",
  "vfmsubadd231sd %xmm1, %xmm2, %xmm3",
  -- VEX blendv requires matching operand widths
  "vblendvps %xmm1, %ymm2, %ymm3, %ymm4"
]

/-- info: [] -/
#guard_msgs in
#eval simdTerRejected.filter (parse · matches .ok _)

#guard match
    parse "pblendvb 16(%rsp), %xmm1",
    parse "vpblendvb %ymm4, 32(%rsp), %ymm2, %ymm1",
    parse "vfmadd231ps 16(%rsp), %xmm2, %xmm1",
    parse "vfnmsub213sd 8(%rsp), %xmm2, %xmm1",
    parse "vfmadd132ss 4(%rsp), %xmm2, %xmm1" with
  | .ok [d1], .ok [d2], .ok [d3], .ok [d4], .ok [d5] =>
    toString d1 == "pblendvb xmm1, XMMWORD PTR [rsp+16], xmm0" &&
    toString d2 == "vpblendvb ymm1, ymm2, YMMWORD PTR [rsp+32], ymm4" &&
    toString d3 == "vfmadd231ps xmm1, xmm2, XMMWORD PTR [rsp+16]" &&
    toString d4 == "vfnmsub213sd xmm1, xmm2, QWORD PTR [rsp+8]" &&
    toString d5 == "vfmadd132ss xmm1, xmm2, DWORD PTR [rsp+4]"
  | _, _, _, _, _ => false
