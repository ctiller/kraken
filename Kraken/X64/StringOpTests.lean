module

/-
  Round-trip and parser tests for (`StringOp`: `movs`, `cmps`, `stos`, `lods`, `scas`
  and `RepPrefix`: `rep`, `repe`/`repz`, `repne`/`repnz`).
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

/-- `s` parsed and printed in AT&T syntax, if it parses. -/
def reprinted (s : String) : Option String := (parse s).toOption.map toATT

def stringOpCorpus : List String := [
  "movsb", "movsw", "movsl", "movsq",
  "rep movsb", "rep movsw", "rep movsl", "rep movsq",
  "stosb", "stosw", "stosl", "stosq",
  "rep stosb", "rep stosw", "rep stosl", "rep stosq",
  "lodsb", "lodsw", "lodsl", "lodsq",
  "rep lodsb", "rep lodsw", "rep lodsl", "rep lodsq",
  "cmpsb", "cmpsw", "cmpsl", "cmpsq",
  "repe cmpsb", "repe cmpsw", "repe cmpsl", "repe cmpsq",
  "repne cmpsb", "repne cmpsw", "repne cmpsl", "repne cmpsq",
  "scasb", "scasw", "scasl", "scasq",
  "repe scasb", "repe scasw", "repe scasl", "repe scasq",
  "repne scasb", "repne scasw", "repne scasl", "repne scasq"
]

#guard stringOpCorpus.all roundtrips

def stringOpAccepted : List String := [
  "repz cmpsb", "repnz scasb", "rep scasb", "rep cmpsb",
  "movsd", "cmpsd", "rep movsd"
]

#guard stringOpAccepted.all roundtrips

#guard [
  ("repz cmpsb", "repe cmpsb"),
  ("repnz scasb", "repne scasb"),
  ("rep scasb", "rep scasb"),
  ("rep cmpsb", "rep cmpsb"),
  ("movsd", "movsl"),
  ("cmpsd", "cmpsl"),
  ("rep movsd", "rep movsl")
].all fun (s, e) => reprinted s == some e

#guard match parse "rep movsl" with
  | .ok [d] => toString d == "rep movsd"
  | _ => false

def stringOpRejected : List String := [
  -- GNU as has no `d` spellings of lods/stos/scas
  "lodsd", "stosd", "scasd", "rep stosd"
]

#guard (stringOpRejected.filter (parse · matches .ok _)).isEmpty
