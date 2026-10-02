module

/-
  Round-trip and parser tests for `movbe`, `crc32`, and `rorx`.
-/

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

def corpus : List String := [
  "movbew (%rsp), %ax", "movbel (%rsp), %eax", "movbeq (%rsp), %rax",
  "movbew %ax, (%rsp)", "movbel %eax, (%rsp)", "movbeq %rax, (%rsp)",
  "crc32b (%rsp), %eax", "crc32w (%rsp), %eax", "crc32l (%rsp), %eax", "crc32b (%rsp), %rax", "crc32q (%rsp), %rax",
  "crc32b %bl, %eax", "crc32w %bx, %eax", "crc32l %ebx, %eax", "crc32b %bl, %rax", "crc32q %rbx, %rax",
  "rorxl $5, (%rsp), %eax", "rorxq $13, (%rsp), %rax", "rorxl $7, %ebx, %eax", "rorxq $63, %rbx, %rax"
]

/-- info: [] -/
#guard_msgs in
#eval corpus.filter (!roundtrips ·)

def accepted : List String := [
  -- `crc32` sized by its register source.
  "crc32 %al, %eax",
  -- crc32 width forms
  "crc32b %al, %ebx", "crc32w %ax, %ebx", "crc32l %eax, %ebx", "crc32b %al, %rbx",
  "crc32q %rax, %rbx", "crc32b %ah, %ebx",
  -- rorx edge cases
  "rorx $255, %eax, %ebx", "rorxq $-128, %rax, %rbx"
]

/-- info: [] -/
#guard_msgs in
#eval accepted.filter (!roundtrips ·)

def rejected : List String := [
  -- `crc32` with a memory source needs a size suffix.
  "crc32 (%rsp), %eax"
]

/-- info: [] -/
#guard_msgs in
#eval rejected.filter (parse · matches .ok _)
