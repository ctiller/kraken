module

/-
  Parser and printer round-trip tests for (`jrcxz`, `jecxz`, `loop`,
  `loope`/`loopz`, `loopne`/`loopnz`, `xlat`/`xlatb`).
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

/-- `s` parsed and printed, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

def loopXlatCorpus : List String := [
  "xlatb", "xlatb (%ebx)",
  "jrcxz foo", "jecxz foo",
  "loop foo", "loope foo", "loopne foo"
]

/-- info: [] -/
#guard_msgs in
#eval loopXlatCorpus.filter (!roundtrips ·)

/-- Accepted aliases that parse and round-trip via their canonical AT&T spelling. -/
def loopXlatAccepted : List String := [
  "xlat", "xlat (%rbx)", "xlat (%ebx)",
  "loopz foo", "loopnz foo"
]

/-- info: [] -/
#guard_msgs in
#eval loopXlatAccepted.filter (!roundtrips ·)

#guard [("xlat", "xlatb"),
  ("xlat (%rbx)", "xlatb"),
  ("xlat (%ebx)", "xlatb (%ebx)"),
  ("loopz foo", "loope foo"),
  ("loopnz foo", "loopne foo")].all
  fun (s, e) => reprinted s == some e
