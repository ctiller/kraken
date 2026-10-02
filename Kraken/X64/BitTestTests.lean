module

/-
  Parser and AT&T printer round-trip tests for the `BitTestOp` family (`bt`, `bts`, `btr`, `btc`).
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

def accepted : List String :=
  (["bt", "bts", "btr", "btc"].flatMap fun mn => [s!"{mn}q $5, (%rsp)", s!"{mn} %ax, %bx"]) ++ [
  "lock btsq $1, (%rsp)",
  "bt %ax, %bx", "bt %eax, (%rsp)", "btsq %rax, %rbx", "btl $255, (%rsp)", "btcw $0, %ax"
]

/-- info: [] -/
#guard_msgs in
#eval accepted.filter (!roundtrips ·)

def rejected : List String := [
  "bt (%rsp), %eax", "btsq 8(%rax), %rbx", "btc foo, %eax",
  "btq %rax, $1", "btq $1, $2"
]

/-- info: [] -/
#guard_msgs in
#eval rejected.filter (parse · matches .ok _)
