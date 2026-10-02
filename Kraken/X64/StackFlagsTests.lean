module

/-
  Parser and AT&T/Intel printer tests for (`leave`, `pushf`/`pushfq`,
  `popf`/`popfq`, and Intel `pushw $imm` formatting).
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel
import Kraken.X64.PrintATTTests

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

def stackFlagsCorpus : List String := [
  "leave", "pushfq", "popfq"
]

/-- info: [] -/
#guard_msgs in
#eval stackFlagsCorpus.filter (!roundtrips ·)

def stackFlagsAccepted : List String := [
  "leaveq", "pushf", "popf"
]

/-- info: [] -/
#guard_msgs in
#eval stackFlagsAccepted.filter (!roundtrips ·)

#guard [("leave", "leave"),
  ("leaveq", "leave"),
  ("pushf", "pushfq"),
  ("pushfq", "pushfq"),
  ("popf", "popfq"),
  ("popfq", "popfq")].all
  fun (s, e) => reprinted s == some e

#guard match parse "pushw $42" with
  | .ok [d] => toString d == "push word ptr 42"
  | _ => false
