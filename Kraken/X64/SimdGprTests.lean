module

/-
  Round-trip, parser, and printer tests for `SimdToGprOp` (`pmovmskb`, `movmskps`,
  `movmskpd`, `cvtss2si`, `cvttss2si`, `cvtsd2si`, `cvttsd2si`), `SimdExtractOp`
  (`pextrb`, `pextrw`, `pextrd`, `pextrq`, `extractps`, `movd`, `movq`, `movlps`,
  `movhps`, `movlpd`, `movhpd`), and `SimdInsertOp` (`pinsrb`, `pinsrw`, `pinsrd`,
  `pinsrq`, `cvtsi2ss`, `cvtsi2sd`, `movlps`, `movhps`, `movlpd`, `movhpd`,
  `movd`, `movq`).
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
#eval failing SimdToGprOp (fun op mn =>
    if op.memBytes?.isSome then [s!"{mn} (%rsp), %rax", s!"v{mn} %xmm1, %rax"]
    else [s!"{mn} %xmm1, %eax", s!"v{mn} %xmm1, %rax", s!"v{mn} %ymm1, %eax"]) ++
  failing SimdExtractOp (fun op mn =>
    let imm := if op.hasImm then "$1, " else ""
    [s!"{mn} {imm}%xmm1, (%rsp)", s!"v{mn} {imm}%xmm1, %rax"]) ++
  failing SimdInsertOp (fun op mn =>
    let imm := if op.hasImm then "$1, " else ""
    let sfx := if op.sizedMem then "q" else ""
    if op.twoOperand then
      [s!"{mn} %eax, %xmm1", s!"v{mn} %rax, %xmm1"]
    else
      [s!"{mn}{sfx} {imm}(%rsp), %xmm1", s!"v{mn}{sfx} {imm}(%rsp), %xmm1, %xmm2"])

def simdGprAccepted : List String := [
  "pinsrb $0, %eax, %xmm0", "pinsrb $0, %rax, %xmm0", "pextrb $0, %xmm0, %eax",
  "pextrb $0, %xmm0, %rax", "pinsrd $0, %eax, %xmm0", "pinsrq $0, %rax, %xmm0",
  "pextrd $0, %xmm0, %eax", "pextrq $0, %xmm0, %rax", "movq %rax, %xmm0", "movq %xmm0, %rax",
  "pextrwl $1, %xmm1, %eax", "vpextrwq $1, %xmm1, %rax", "pinsrwl $1, %eax, %xmm0",
  "vpinsrwq $1, %rax, %xmm1, %xmm2", "pextrw $1, %xmm1, (%rsp)", "pinsrw $1, (%rsp), %xmm0",
  "cvtsi2sdl (%rsp), %xmm0", "vcvtsi2ssq (%rsp), %xmm1, %xmm2", "cvtsi2sdq %rax, %xmm0",
  "movmskpsq %xmm1, %rax", "vpmovmskbl %ymm1, %eax", "cvttsd2sil (%rsp), %eax", "vcvtss2siq %xmm1, %rax",
  "movlps (%rsp), %xmm2", "vmovhpd %xmm1, (%rsp)", "vmovlpd (%rsp), %xmm1, %xmm2",
  "pmovmskb %xmm1, %eax", "vmovmskpd %ymm1, %rax", "cvtsd2si (%rsp), %eax"
]

/-- info: [] -/
#guard_msgs in
#eval simdGprAccepted.filter (!roundtrips ·)

/-- `s` parsed and printed, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

-- An unsuffixed `cvtsi2ss`/`cvtsi2sd` memory source is 32 bits wide, as GNU as reads it.
#guard [("cvtsi2sd (%rsp), %xmm1", "cvtsi2sdl (%rsp), %xmm1"),
  ("cvtsi2ss (%rsp), %xmm1", "cvtsi2ssl (%rsp), %xmm1"),
  ("vcvtsi2sd 8(%rax), %xmm1, %xmm2", "vcvtsi2sdl 8(%rax), %xmm1, %xmm2"),
  ("vcvtsi2ss 8(%rax), %xmm1, %xmm2", "vcvtsi2ssl 8(%rax), %xmm1, %xmm2"),
  ("cvtsi2sdq (%rsp), %xmm1", "cvtsi2sdq (%rsp), %xmm1")].all
  fun (s, e) => reprinted s == some e

-- Intel syntax formatting checks.
#guard match
    parse "vpmovmskb %ymm1, %eax",
    parse "cvtss2si 4(%rsp), %rax",
    parse "vpextrw $3, %xmm1, 2(%rsp)",
    parse "vmovq %xmm0, %r14",
    parse "pinsrd $2, 8(%rsp), %xmm4",
    parse "vcvtsi2sdq 16(%rsp), %xmm1, %xmm2",
    parse "vmovd %ebx, %xmm7" with
  | .ok [d1], .ok [d2], .ok [d3], .ok [d4], .ok [d5], .ok [d6], .ok [d7] =>
    toString d1 == "vpmovmskb eax, ymm1" &&
    toString d2 == "cvtss2si rax, DWORD PTR [rsp+4]" &&
    toString d3 == "vpextrw WORD PTR [rsp+2], xmm1, 3" &&
    toString d4 == "vmovq r14, xmm0" &&
    toString d5 == "pinsrd xmm4, DWORD PTR [rsp+8], 2" &&
    toString d6 == "vcvtsi2sd xmm2, xmm1, QWORD PTR [rsp+16]" &&
    toString d7 == "vmovd xmm7, ebx"
  | _, _, _, _, _, _, _ => false
