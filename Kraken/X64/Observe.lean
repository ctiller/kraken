module

public import Kraken.X64.Semantics
import Kraken.X64.Parser

public section

/-!
# Hardware observations

Semantics.lean leaves some results `undefined`; hardware picks one. This module runs a straight-line
instruction sequence with those choices supplied by an *oracle* and reports what a hardware harness
can observe, so that a hardware run becomes the checkable statement "there is an oracle under which
Kraken computes what the hardware did": `∃ o : Oracle, observe o asm = result`.
-/

/-! ## The initial state

The hardware harness (`reset_state` in Kraken/X64/Test/asm_tests.py) sets up exactly this state. -/

/-- The data memory is a stack of `stackSize` bytes below `stackLocation`. -/
def stackSize := 800

/-- The stack is placed high in memory, 256-byte aligned: stack arithmetic then neither overflows
nor underflows (as it would near 0) and, since the low byte of rsp is zero, its PF matches the
hardware's. -/
def stackLocation : UInt64 := 0x7ffecafee200

/-- The lowest stack address, `stackLocation - stackSize`. -/
def stackBase : BitVec 64 := stackLocation.toBitVec - BitVec.ofNat 64 stackSize

def initStack : DataMem := (List.replicate stackSize 0xff).At stackBase

/-- rsp at `stackLocation`, every other register and flag zero, and the stack filled with `0xff`. -/
def initData : MachineData := { regs := { rsp := stackLocation }, dmem := initStack }

/-! ## Oracles -/

/-- An input oracle: the values of an execution's `undefined` choices, in the order they are made,
each read as `NondetSupportingType.decode` does. -/
abbrev Oracle := List Nat

/-! ## Observations -/

/-- The part of a machine state that the hardware harness observes: the general-purpose registers,
the flags, ymm0-15 and the stack. -/
structure Observation where
  regs : Reg64s := {}
  status : StatusFlags := .mk false false false false false false false
  /-- `(i, v)` for each nonzero ymm`i`, in order. -/
  ymms : List (Nat × BitVec 256) := []
  /-- `(offset, byte)` for each stack byte that is not the initial `0xff`, in order; offsets are
  from `stackBase`. -/
  mem : List (Nat × UInt8) := []
  deriving Repr, BEq, DecidableEq

/-- The ymm registers the harness observes. -/
def observedYmms : List RegMm :=
  [.mm0, .mm1, .mm2, .mm3, .mm4, .mm5, .mm6, .mm7, .mm8, .mm9, .mm10, .mm11, .mm12, .mm13, .mm14, .mm15]

def Observation.of (s : MachineData) : Observation where
  regs := s.regs
  status := s.status
  ymms := observedYmms.zipIdx.filterMap fun (r, i) =>
    let v := (s.zmms.get512 r).setWidth 256
    if v == 0 then none else some (i, v)
  mem := (List.range stackSize).filterMap fun i =>
    match s.dmem[stackBase + BitVec.ofNat 64 i]? with
    | some b => if b == 0xff then none else some (i, b)
    | none => none

/-- How a run of a sequence ends. `instr` numbers the sequence's directives (instructions and
labels) from 0. -/
inductive Ending
  /-- Every instruction completed. -/
  | ok
  /-- Instruction `instr` raises `exception` (`Effects.fault`, e.g. `#DE`). -/
  | fault (instr : Nat) (exception : String)
  /-- Instruction `instr` accesses `w` bytes at `addr`, which is not aligned as the instruction
  requires (`Effects.gp_unaligned`, a #GP). -/
  | unaligned (instr : Nat) (addr : BitVec 64) (w : Nat)
  /-- Instruction `instr` accesses `w` bytes at `addr`, outside the data memory
  (`Effects.nonmem_load` or `nonmem_store`). -/
  | unmapped (instr : Nat) (addr : BitVec 64) (w : Nat)
  /-- Instruction `instr` is beyond this module: it jumps or is unimplemented, the oracle has no
  value for one of its choices, or the sequence does not parse (then `instr` is 0 and `msg` the
  parse error). -/
  | unsupported (instr : Nat) (msg : String)
  deriving Repr, BEq, DecidableEq

/-- What a run of a sequence shows: the observable state after the last instruction that completed,
and how the run ended. -/
structure Result where
  state : Observation
  ending : Ending
  deriving Repr, BEq, DecidableEq

/-- `e` run with every access check granted and every `undefined` choice read from `o`: the next
state, or how instruction `i` ends the run; the rest of the oracle is returned too. -/
def Effects.run (i : Nat) (o : Oracle) : Effects → Except Ending MachineData × Oracle
  | .done (s, _) => (.ok s, o)
  | .fault e => (.error (.fault i e), o)
  | .gp_unaligned a w => (.error (.unaligned i a w), o)
  | .nonmem_load _ a w _ => (.error (.unmapped i a w.bytes), o)
  | @Effects.nonmem_store _ a w _ _ => (.error (.unmapped i a w.bytes), o)
  | .unimplemented m => (.error (.unsupported i m), o)
  | @Effects.undefined _ t cont => match o with
    | v :: o => (cont (t.decode v)).run i o
    | [] => (.error (.unsupported i "the oracle has no value for an undefined choice"), o)
  | .require_read_access _ _ ok | .require_write_access _ _ ok | .require_exec_access _ ok =>
    (ok ()).run i o

/-- The effects of directive `dir` at `p` on `s`; jumps are unsupported. -/
def effectsOf [Labels] (dir : Directive) (p : Std.Rco Int64) (s : MachineData) : Effects :=
  dir.interp s p (fun s => .done (s, p.upper)) (fun _ _ => .unimplemented "jump")

/-- Runs `asm` (straight-line AT&T assembly, one instruction per line) from `s` with its choices
made by `o`: the final state, or the state before the instruction that ends the run, and how. -/
def runFrom (o : Oracle) (s : MachineData) (asm : String) : MachineData × Ending :=
  match Kraken.X64.Parser.parse asm with
  | .error e => (s, .unsupported 0 e)
  | .ok prog =>
    let exe := prog.fakeLayout
    let := exe.labels
    go 0 s o exe.withAddresses
where
  go [Labels] (i : Nat) (s : MachineData) (o : Oracle) :
      List (Int64 × Directive × Nat) → MachineData × Ending
    | [] => (s, .ok)
    | (pc, dir, sz) :: rest =>
      match (effectsOf dir (.mk pc (pc + .ofNat sz)) s).run i o with
      | (.ok s, o) => go (i + 1) s o rest
      | (.error e, _) => (s, e)

/-- What `asm` shows when run from `initData` with its choices made by `o`. -/
def observe (o : Oracle) (asm : String) : Result :=
  let (s, e) := runFrom o initData asm
  { state := .of s, ending := e }

/-! ## Printing observations as Lean -/

def hex (n : Nat) : String := "0x" ++ String.ofList (Nat.toDigits 16 n)

/-- `x` as a Lean term. -/
def Observation.toLean (x : Observation) : String :=
  let r := x.regs
  let regs := [("rax", r.rax), ("rbx", r.rbx), ("rcx", r.rcx), ("rdx", r.rdx), ("rsi", r.rsi),
    ("rdi", r.rdi), ("rsp", r.rsp), ("rbp", r.rbp), ("r8", r.r8), ("r9", r.r9), ("r10", r.r10),
    ("r11", r.r11), ("r12", r.r12), ("r13", r.r13), ("r14", r.r14), ("r15", r.r15)]
  let regs := regs.filterMap fun (n, v) => if v == 0 then none else some s!"{n} := {hex v.toNat}"
  let f := x.status
  let flags := [("cf", f.cf), ("pf", f.pf), ("af", f.af), ("zf", f.zf), ("sf", f.sf), ("of", f.of),
    ("df", f.df)].map fun (n, b) => s!"{n} := {b}"
  let fields := [s!"regs := \{ {", ".intercalate regs} }", s!"status := \{ {", ".intercalate flags} }"]
  let fields := fields ++ (if x.ymms.isEmpty then [] else
    [s!"ymms := [{", ".intercalate (x.ymms.map fun (i, v) => s!"({i}, {hex v.toNat}#256)")}]"])
  let fields := fields ++ (if x.mem.isEmpty then [] else
    [s!"mem := [{", ".intercalate (x.mem.map fun (i, b) => s!"({i}, {hex b.toNat})")}]"])
  s!"\{ {", ".intercalate fields} }"

def Ending.toLean : Ending → String
  | .ok => ".ok"
  | .fault i e => s!".fault {i} {e.quote}"
  | .unaligned i a w => s!".unaligned {i} {hex a.toNat}#64 {w}"
  | .unmapped i a w => s!".unmapped {i} {hex a.toNat}#64 {w}"
  | .unsupported i m => s!".unsupported {i} {m.quote}"

def Result.toLean (r : Result) : String :=
  s!"\{ state := {r.state.toLean}, ending := {r.ending.toLean} }"

/-- `s` as a Lean string literal, one line of `s` per line: a `\` ending a line continues the
literal on the next, skipping its indentation (so, should a line of `s` begin with whitespace, the
one-line `s.quote` is used instead). -/
def quoteLines (s : String) : String :=
  let lines := s.splitOn "\n"
  if lines.any (·.front.isWhitespace) then s.quote else
  let escaped := lines.map fun l => l.foldl (· ++ ·.quoteCore (inString := true)) ""
  "\"" ++ "\\n\\\n    ".intercalate escaped ++ "\""

/-- The Lean declaration stating that `asm` run under some oracle shows `r`, with `o` as the
witness, checked by evaluation. -/
def observationDecl (asm : String) (o : Oracle) (r : Result) : String :=
  s!"example : ∃ o : Oracle, observe o {quoteLines asm} = {r.toLean} :=\n  ⟨[{", ".intercalate (o.map hex)}], by native_decide⟩"
