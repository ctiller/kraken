module

/-
  Parser and AT&T/Intel printer tests for (`HintOp`, `MemHintOp`, `nopm`, `movnti`).
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

/-- `s` parsed and printed in AT&T syntax, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

/-- info: [] -/
#guard_msgs in
#eval failing HintOp (fun _ mn => [mn]) ++
  failing MemHintOp (fun _ mn => [s!"{mn} (%rsp)", s!"{mn} (%eax)"])

def hintCorpus : List String := [
  "movnti %eax, (%rsp)", "movnti %rax, (%rsp)", "movnti %eax, -16(%rbp,%rcx,8)",
  "pause", "lfence", "mfence", "sfence", "endbr64",
  "nopw (%rax)", "nopl (%rax)", "nopq (%rax)", "nopw %ax", "nopl %eax", "nopq %rax",
  "nopl 0(%rax)", "nopw 0(%rax,%rax,1)"
]

/-- info: [] -/
#guard_msgs in
#eval hintCorpus.filter (!roundtrips ·)

#guard [("movnti %eax, (%rsp)", "movnti %eax, (%rsp)"),
  ("movnti %rax, (%rsp)", "movnti %rax, (%rsp)"),
  ("movntil %ebx, 8(%rsp)", "movnti %ebx, 8(%rsp)"),
  ("movntiq %rdx, 24(%rsp)", "movnti %rdx, 24(%rsp)")].all
  fun (s, e) => reprinted s == some e
