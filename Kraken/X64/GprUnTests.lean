module

/-
  Parser and AT&T/Intel printer round-trip tests for (`GprUnOp`:
  `popcnt`, `lzcnt`, `tzcnt`, `bsf`, `bsr`, `blsi`, `blsmsk`, `blsr`).
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel

open Kraken.X64 Kraken.X64.Parser

/-- `s` parses, and printing the result then re-parsing gives the same program. -/
def roundtrips (s : String) : Bool :=
  match parse s with
  | .ok p => match parse (toATT p) with
    | .ok p' => p' == p
    | .error _ => false
  | .error _ => false

/-- The mnemonics of family `α` for which one of `forms` doesn't round-trip. -/
def failing (α) [Mnemonic α] (forms : α → String → List String) : List String :=
  (Mnemonic.names (α := α)).toList.filterMap fun (op, mn) =>
    if (forms op mn).all roundtrips then none else some mn

/-- info: [] -/
#guard_msgs in
#eval failing GprUnOp (fun _ mn => [s!"{mn} (%rsp), %rax", s!"{mn}l %eax, %ebx"])

def gprUnCorpus : List String := [
  "popcntw %ax, %bx", "popcntl %eax, %ebx", "popcntq %rax, %rbx", "popcntq -64(%rsp), %r8",
  "lzcntw %ax, %r10w", "lzcntl %eax, %r9d", "lzcntq %rax, %r8", "lzcntq -48(%rsp), %r11",
  "tzcntw %ax, %r14w", "tzcntl %eax, %r13d", "tzcntq %rax, %r12", "tzcntq -32(%rsp), %r15",
  "bsfw %ax, %dx", "bsfl %eax, %ecx", "bsfq %rax, %rbx", "bsfq (%rsp), %rax",
  "bsrw -32(%rsp), %bp", "bsrl %eax, %edi", "bsrq %rax, %rsi",
  "blsil %eax, %r9d", "blsiq %rax, %r8", "blsiq -48(%rsp), %r10",
  "blsmskl %eax, %r12d", "blsmskq %rax, %r11", "blsmskq -32(%rsp), %r13",
  "blsrl %eax, %r15d", "blsrq %rax, %r14", "blsrq -32(%rsp), %rbx"
]

#guard gprUnCorpus.all roundtrips

def accepted : List String := [
  "popcnt (%rax), %rbx",
  "lzcnt %eax, %ebx",
  "tzcnt %rcx, %rdx",
  "popcnt %ax, %bx",
  "blsi %eax, %ebx",
  "blsmsk (%rsp), %rax",
  "blsr (%eax), %ebx",
  "bsf (%rsp), %ecx",
  "bsr (%rsp), %rdx"
]

#guard accepted.all roundtrips

#guard match parse "popcnt (%rax), %rbx", parse "lzcnt %eax, %ebx" with
  | .ok [d1], .ok [d2] =>
    toString d1 == "popcnt rbx, QWORD PTR [rax+0]" &&
    toString d2 == "lzcnt ebx, eax"
  | _, _ => false
