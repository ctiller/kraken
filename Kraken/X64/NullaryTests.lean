module

/-
  Round-trip, printer, and semantic tests for `NullaryOp`
  (`ud2`, `int3`, `hlt`, `clc`, `stc`, `cmc`, `lahf`, `sahf`, `cld`, `std`).
-/

import Kraken.X64.Parser
meta import Kraken.X64.Parser
import Kraken.X64.PrintATT
meta import Kraken.X64.PrintATT
import Kraken.X64.PrintIntel
meta import Kraken.X64.PrintIntel
import Kraken.X64.Semantics
meta import Kraken.X64.Semantics

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
#eval failing NullaryOp (fun _ mn => [mn])

def nullaryCorpus : List String := [
  "ud2", "int3", "hlt",
  "clc", "stc", "cmc",
  "lahf", "sahf",
  "cld", "std"
]

#guard nullaryCorpus.all roundtrips

-- Intel syntax printing matches the mnemonic name for every NullaryOp.
#guard nullaryCorpus.all fun mn =>
  match parse mn with
  | .ok p => p.map toString == [mn]
  | .error _ => false

/-- Execute a straight-line assembly snippet from `{}`. -/
def exec (code : String) : Except String MachineData := do
  let exe := (← parse s!"_start:\n{code}\n_end:").fakeLayout
  let (s, _) ← exe.eval ({}, exe.labels.label "_start") (·.2 == exe.labels.label "_end")
  return s

-- Trap and halt instructions raise the expected faults.
#guard exec "ud2" matches .error "#UD: undefined instruction"
#guard exec "int3" matches .error "#BP: breakpoint trap"
#guard exec "hlt" matches .error "HLT: halt instruction"

-- Carry and direction flag manipulation.
#guard (exec "stc").toOption.map (·.status.cf) == some true
#guard (exec "stc\nclc").toOption.map (·.status.cf) == some false
#guard (exec "cmc").toOption.map (·.status.cf) == some true
#guard (exec "stc\ncmc").toOption.map (·.status.cf) == some false
#guard (exec "std").toOption.map (·.status.df) == some true
#guard (exec "std\ncld").toOption.map (·.status.df) == some false

-- lahf/sahf round-trip low status flags through %ah without clobbering %al or OF/DF.
#guard match exec "std\nstc\nlahf\nclc\nsahf" with
  | .ok s => s.status.cf && s.status.df && s.regs.get Reg.ah == 0x03#8
  | .error _ => false
