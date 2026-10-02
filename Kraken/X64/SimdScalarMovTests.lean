module

/-
  Round-trip, parser, and printer tests for `SimdScalarMov` (`movss`, `movsd`,
  `vmovss`, `vmovsd`) and `vzeroupper`/`vzeroall`.
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

#guard roundtrips "vzeroupper"
#guard roundtrips "vzeroall"

/-- info: [] -/
#guard_msgs in
#eval failing SimdScalarMov (fun _ mn => [
  s!"{mn} %xmm1, %xmm0",
  s!"{mn} (%rsp), %xmm0",
  s!"{mn} %xmm0, (%rsp)",
  s!"v{mn} %xmm2, %xmm1, %xmm0",
  s!"v{mn} (%rsp), %xmm0",
  s!"v{mn} %xmm0, (%rsp)"
])

-- Intel syntax formatting checks.
#guard match parse "movss 4(%rsp), %xmm0\nvmovsd %xmm1, 8(%rsp)\nvmovss %xmm2, %xmm1, %xmm0\nvzeroupper\nvzeroall" with
  | .ok [d1, d2, d3, d4, d5] =>
    toString d1 == "movss xmm0, DWORD PTR [rsp+4]" &&
    toString d2 == "vmovsd QWORD PTR [rsp+8], xmm1" &&
    toString d3 == "vmovss xmm0, xmm1, xmm2" &&
    toString d4 == "vzeroupper" &&
    toString d5 == "vzeroall"
  | _ => false

-- 3-operand VEX scalar move destination must be `%xmm`.
#guard parse "vmovss %xmm2, %xmm1, %ymm0" matches .error _
#guard parse "vmovsd %xmm2, %xmm1, %ymm0" matches .error _
