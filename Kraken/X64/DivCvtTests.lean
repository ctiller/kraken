module

/-
  Parser and AT&T/Intel printer round-trip tests for
  (`div`, `idiv`, `cbw`/`cbtw`/`cwtl`/`cltq`, `cwd`/`cwtd`/`cltd`/`cqto`).
-/

import Kraken.X64.PrintATTTests
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

/-- `s` parsed and printed in AT&T syntax, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

def divCvtCorpus : List String := [
  "divb %bl", "divw %bx", "divl %ebx", "divq %rbx",
  "divb (%rsp)", "divw (%rsp)", "divl (%rsp)", "divq (%rsp)",
  "idivb %bl", "idivw %bx", "idivl %ebx", "idivq %rbx",
  "idivb (%rsp)", "idivw (%rsp)", "idivl (%rsp)", "idivq (%rsp)",
  "cbtw", "cwtl", "cltq", "cwtd", "cltd", "cqto"
]

#guard divCvtCorpus.all roundtrips

def divCvtAccepted : List String := [
  "div %bl", "div %bx", "div %ebx", "div %rbx",
  "idiv %bl", "idiv %bx", "idiv %ebx", "idiv %rbx",
  "cbw", "cwde", "cdqe", "cwd", "cdq", "cqo"
]

#guard divCvtAccepted.all roundtrips

#guard [
  ("cbw", "cbtw"),
  ("cwde", "cwtl"),
  ("cdqe", "cltq"),
  ("cwd", "cwtd"),
  ("cdq", "cltd"),
  ("cqo", "cqto")
].all fun (s, e) => reprinted s == some e
