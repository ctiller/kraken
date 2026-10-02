module

/-
  Round-trip and parser tests for (`xchg`, `xadd`, `cmpxchg`, `cmpxchg8b`, `cmpxchg16b`).
-/

import Kraken.X64.PrintATTTests
import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT

open Kraken.X64 Kraken.X64.Parser

/-- `s` parses, and printing the result then re-parsing gives the same program. -/
def roundtrips (s : String) : Bool :=
  match parse s with
  | .ok p => match parse (toATT p) with
    | .ok p' => p' == p
    | .error _ => false
  | .error _ => false

def xchgCorpus : List String := [
  "xchgb %al, %bl", "xchgw %ax, (%rsp)", "xchgl %eax, %ebx", "xchgq %rax, %rbx", "xchgq %rax, 8(%rsp)",
  "xchg (%rax), %rbx", "xchgq (%rax), %rbx",
  "xaddb %al, (%rsp)", "xaddw %ax, %bx", "xaddl %eax, (%rsp)", "xaddq %rax, %rbx",
  "cmpxchgb %bl, (%rsp)", "cmpxchgw %bx, %cx", "cmpxchgl %ebx, (%rsp)", "cmpxchgq %rbx, %rcx",
  "cmpxchg8b (%rsp)", "cmpxchg16b (%rsp)"
]

#guard xchgCorpus.all roundtrips

#guard match parse "xchg (%rax), %rbx", parse "xchgq %rbx, (%rax)" with
  | .ok p1, .ok p2 => p1 == p2
  | _, _ => false

#guard match parse "lock xaddq %rax, (%rsp)", parse "xaddq %rax, (%rsp)" with
  | .ok p1, .ok p2 => p1 == p2
  | _, _ => false
