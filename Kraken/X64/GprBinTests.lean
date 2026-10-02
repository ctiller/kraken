module

/-
  Round-trip, parser, and printer tests for `GprBinOp` (`andn`, `bextr`, `bzhi`,
  `pdep`, `pext`, `sarx`, `shlx`, `shrx`).
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

-- The address size of a memory operand in any position is kept.
#guard match parse "bextr %rbx, -8(%esp), %r15" with
  | .ok p => toATT p == "bextr %rbx, -8(%esp), %r15"
  | .error _ => false

#guard match parse "bextr %eax, (%ebx), %ecx" with
  | .ok p => toATT p == "bextr %eax, (%ebx), %ecx"
  | .error _ => false

def gprBinAccepted : List String := [
  "andn %rax, %rbx, %rcx", "andn (%rsp), %ebx, %ecx",
  "bextr %rax, %rbx, %rcx", "bextr %ebx, 8(%rsp), %ecx",
  "bzhi %rax, %rbx, %rcx", "bzhi %ebx, (%rsp), %ecx",
  "pdep %rax, %rbx, %rcx", "pdep 8(%rsp), %ebx, %ecx",
  "pext %rax, %rbx, %rcx", "pext 8(%rsp), %ebx, %ecx",
  "sarx %rcx, (%rax), %rdx", "shlx %rcx, (%rax), %rdx", "shrx %rcx, (%rax), %rdx"
]

/-- info: [] -/
#guard_msgs in
#eval gprBinAccepted.filter (!roundtrips ·)

-- `src1` (VEX.vvvv) must be a register; memory in `src1` position is rejected.
def gprBinRejected : List String := [
  "andn %rax, (%rbx), %rcx",
  "pdep %rax, (%rbx), %rcx",
  "pext %rax, (%rbx), %rcx",
  "bextr (%rax), %rbx, %rcx",
  "bzhi (%rax), %rbx, %rcx",
  "sarx (%rcx), %rax, %rdx",
  "shlx (%rcx), %rax, %rdx",
  "shrx (%rcx), %rax, %rdx"
]

/-- info: [] -/
#guard_msgs in
#eval gprBinRejected.filter (parse · matches .ok _)

-- Intel syntax operand ordering for `src2First = true` (RVM) and `src2First = false` (RMV).
#guard match parse "andn 8(%rsp), %rbx, %rcx" with
  | .ok [d] => toString d == "andn rcx, rbx, QWORD PTR [rsp+8]"
  | _ => false

#guard match parse "bextr %rbx, 8(%rsp), %rcx" with
  | .ok [d] => toString d == "bextr rcx, QWORD PTR [rsp+8], rbx"
  | _ => false

/-- info: [] -/
#guard_msgs in
#eval failing GprBinOp (fun op mn => [s!"{mn} %rax, %rbx, %rcx",
  if op.src2First then s!"{mn} 8(%rsp), %ebx, %ecx" else s!"{mn} %ebx, 8(%rsp), %ecx"])
