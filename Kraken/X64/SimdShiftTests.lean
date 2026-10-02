module

/-
  Round-trip, parser, and printer tests for `SimdShiftOp` and `SimdCount`
  (`psllw`, `pslld`, `psllq`, `psrlw`, `psrld`, `psrlq`, `psraw`, `psrad`,
  `pslldq`, `psrldq` and VEX forms).
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
#eval failing SimdShiftOp (fun _ mn => [
  s!"{mn} $3, %xmm1",
  s!"{mn} (%rsp), %xmm1",
  s!"v{mn} %xmm2, %ymm3, %ymm4"
])

def simdShiftAccepted : List String := [
  "pslldq $3, %xmm1",
  "vpsrldq $3, %ymm1, %ymm2",
  "psrlq %xmm2, %xmm1",
  "vpsllw (%rsp), %ymm3, %ymm4"
]

/-- info: [] -/
#guard_msgs in
#eval simdShiftAccepted.filter (!roundtrips ·)

#guard simdShiftAccepted.all roundtrips

#guard match parse "pslldq $3, %xmm1", parse "vpsllw (%rsp), %ymm3, %ymm4" with
  | .ok [d1], .ok [d2] =>
    toString d1 == "pslldq xmm1, 3" &&
    toString d2 == "vpsllw ymm4, ymm3, XMMWORD PTR [rsp+0]"
  | _, _ => false
