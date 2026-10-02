module

/-
  Round-trip, parser, and printer tests for `SimdExtract128Op` (`vextracti128`, `vextractf128`),
  `SimdInsert128Op` (`vinserti128`, `vinsertf128`), and `vcvtps2ph` (F16C).
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

#guard roundtrips "vcvtps2ph $1, %xmm0, %xmm1"
#guard roundtrips "vcvtps2ph $1, %ymm0, %xmm1"
#guard roundtrips "vcvtps2ph $1, %xmm0, (%rsp)"
#guard roundtrips "vcvtps2ph $1, %ymm0, (%rsp)"

/-- info: [] -/
#guard_msgs in
#eval failing SimdExtract128Op (fun _ mn => [
  s!"v{mn} $1, %ymm0, %xmm1",
  s!"v{mn} $0, %ymm0, (%rsp)"
]) ++
failing SimdInsert128Op (fun _ mn => [
  s!"v{mn} $1, %xmm2, %ymm1, %ymm0",
  s!"v{mn} $0, (%rsp), %ymm1, %ymm0"
])

-- Intel syntax formatting checks.
#guard match parse "vextracti128 $1, %ymm0, %xmm1\nvextractf128 $0, %ymm0, 16(%rsp)\nvinserti128 $1, %xmm2, %ymm1, %ymm0\nvinsertf128 $0, 32(%rsp), %ymm1, %ymm0\nvcvtps2ph $0, %xmm1, %xmm0\nvcvtps2ph $1, %xmm1, 8(%rsp)\nvcvtps2ph $2, %ymm1, 16(%rsp)" with
  | .ok [d1, d2, d3, d4, d5, d6, d7] =>
    toString d1 == "vextracti128 xmm1, ymm0, 1" &&
    toString d2 == "vextractf128 XMMWORD PTR [rsp+16], ymm0, 0" &&
    toString d3 == "vinserti128 ymm0, ymm1, xmm2, 1" &&
    toString d4 == "vinsertf128 ymm0, ymm1, XMMWORD PTR [rsp+32], 0" &&
    toString d5 == "vcvtps2ph xmm0, xmm1, 0" &&
    toString d6 == "vcvtps2ph QWORD PTR [rsp+8], xmm1, 1" &&
    toString d7 == "vcvtps2ph XMMWORD PTR [rsp+16], ymm1, 2"
  | _ => false

-- `vinserti128`/`vinsertf128` require matching widths for `src1` and `dst`.
#guard parse "vinserti128 $0, %xmm2, %ymm1, %xmm0" matches .error _
#guard parse "vinsertf128 $0, %xmm2, %xmm1, %ymm0" matches .error _
