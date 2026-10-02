module

/-
KrakenRunnerX64 - Run assembly instructions through Kraken Semantics and obtain results as json.

At this point this expects a file only containing a list of assembly instructions, no data block or similar.

Usage: krakenrunner_x64 <assembly.S>
       krakenrunner_x64 --generate <seed> <count> <length> [prefix...]  (random sequences that Kraken can run,
        optionally drawing only instructions starting with one of the prefixes)
       krakenrunner_x64 --observe < runs.json   (for each hardware run, the oracle under which Kraken
        reproduces it, as a Lean statement; or why it cannot)

Arguments:
- assembly.S: Assembly source file

Output:
- Json formatted Machine state of Kraken after running the assembly.
  See StateSummary for format.
-/

import Kraken.Mem
import Kraken.X64.Observe
import Kraken.X64.Parser
import Kraken.X64.PrintATT
import Kraken.X64.Semantics
import Lean.Data.Json
public meta import Lean.Elab.Term

open Lean

-- TODO Add memory, for now we only track and compare registers and flags.
structure StateSummary where
  regs : List (String × UInt64)
  zmms : List (String × ZmmValue)
  flags : List (String × Bool)

-- Custom json serialization for the state summary. Registers with zero values
-- are not included.
instance : ToJson StateSummary where
  toJson s :=
    let regs := s.regs.filterMap (fun (k, v) => if v == 0 then none else some (k, Json.num v.toNat))
    let zmms := s.zmms.filterMap (fun (k, v) => if v == 0#512 then none else some (k, Json.str (String.ofList (Nat.toDigits 16 v.toNat))))
    let flags := s.flags.map (fun (k, v) => (k, toJson v))
    Json.mkObj [
      ("regs", Json.mkObj regs),
      ("zmms", Json.mkObj zmms),
      ("flags", Json.mkObj flags)
    ]

def summarize (s : MachineData) : StateSummary :=
  let r := s.regs
  let z := s.zmms
  let f := s.status
  { regs := [("rax", r.rax), ("rbx", r.rbx), ("rcx", r.rcx), ("rdx", r.rdx),
             ("rsi", r.rsi), ("rdi", r.rdi), ("rsp", r.rsp), ("rbp", r.rbp), ("r8", r.r8),
             ("r9", r.r9), ("r10", r.r10), ("r11", r.r11), ("r12", r.r12),
             ("r13", r.r13), ("r14", r.r14), ("r15", r.r15)],
    zmms := [("zmm0", z.zmm0), ("zmm1", z.zmm1), ("zmm2", z.zmm2), ("zmm3", z.zmm3),
             ("zmm4", z.zmm4), ("zmm5", z.zmm5), ("zmm6", z.zmm6), ("zmm7", z.zmm7),
             ("zmm8", z.zmm8), ("zmm9", z.zmm9), ("zmm10", z.zmm10), ("zmm11", z.zmm11),
             ("zmm12", z.zmm12), ("zmm13", z.zmm13), ("zmm14", z.zmm14), ("zmm15", z.zmm15),
             ("zmm16", z.zmm16), ("zmm17", z.zmm17), ("zmm18", z.zmm18), ("zmm19", z.zmm19),
             ("zmm20", z.zmm20), ("zmm21", z.zmm21), ("zmm22", z.zmm22), ("zmm23", z.zmm23),
             ("zmm24", z.zmm24), ("zmm25", z.zmm25), ("zmm26", z.zmm26), ("zmm27", z.zmm27),
             ("zmm28", z.zmm28), ("zmm29", z.zmm29), ("zmm30", z.zmm30), ("zmm31", z.zmm31)],
    flags := [("cf", f.cf), ("pf", f.pf), ("af", f.af),
              ("zf", f.zf), ("sf", f.sf), ("of", f.of), ("df", f.df)] }

def _start: String := "_start"
def _end: String := "_end"

def finishCriterion (p: Program) (s: MachineState): Bool :=
  s.2 = p.fakeLayout.labels.label _end

def runKraken (asmCode : String)
    : Except String MachineState := do
  let prog ← Kraken.X64.Parser.parse (_start ++ ":" ++ asmCode ++ "\n" ++ _end ++ ":")
  let initState: MachineState := (initData, prog.fakeLayout.labels.label _start)
  prog.fakeLayout.eval initState (finishCriterion prog)

/-! ## Oracle extraction from hardware runs

The hardware harness (Kraken/X64/Test/fuzz_x64.py) records the observable state after every
instruction of a sequence, and the signal if one faults. `findOracle` recovers, instruction by
instruction, the values of the `undefined` choices under which Semantics.lean reproduces those states;
`observeHardware` chains them into the witness of `∃ o : Oracle, observe o asm = result`
(Kraken/X64/Observe.lean), or explains the first instruction Kraken gets differently. -/

def NondetSupportingType.width {α} : NondetSupportingType α → Nat
  | .bool => 1 | .statusFlags => 6 | .bitvec w => w.bits | .avx_bitvec w => w.bits

/-- The bit widths of the `undefined` choices `e` makes along the path that `o` resolves. -/
def Effects.choiceWidths (o : Oracle) : Effects → List Nat
  | @Effects.undefined _ t cont => match o with
    | v :: o => t.width :: (cont (t.decode v)).choiceWidths o
    | [] => []
  | .require_read_access _ _ ok | .require_write_access _ _ ok | .require_exec_access _ ok =>
    (ok ()).choiceWidths o
  | _ => []

/-- `x` as a bit string in a fixed order (GPRs, flags, ymms, stack), to locate where a choice lands. -/
def Observation.bits (x : Observation) : Array Bool := Id.run do
  let r := x.regs
  let mut bits : Array Bool := #[]
  for v in [r.rax, r.rbx, r.rcx, r.rdx, r.rsi, r.rdi, r.rsp, r.rbp,
            r.r8, r.r9, r.r10, r.r11, r.r12, r.r13, r.r14, r.r15] do
    for i in [0:64] do bits := bits.push (v.toBitVec.getLsbD i)
  let f := x.status
  bits := bits ++ #[f.cf, f.pf, f.af, f.zf, f.sf, f.of, f.df]
  for i in [0:observedYmms.length] do
    let v := (x.ymms.lookup i).getD 0
    for j in [0:256] do bits := bits.push (v.getLsbD j)
  for i in [0:stackSize] do
    let b := (x.mem.lookup i).getD 0xff
    for j in [0:8] do bits := bits.push (b.toBitVec.getLsbD j)
  return bits

/-- Where Kraken's `k` and the hardware's `h` differ, for reports. -/
def Observation.diff (k h : Observation) : List String := Id.run do
  let mut out := []
  let field (name : String) (a b : Nat) := if a != b then [s!"{name}: Kraken {hex a}, hardware {hex b}"] else []
  for (name, a, b) in List.zip ["rax", "rbx", "rcx", "rdx", "rsi", "rdi", "rsp", "rbp", "r8", "r9", "r10", "r11",
      "r12", "r13", "r14", "r15"] (List.zip (regsOf k.regs) (regsOf h.regs)) do
    out := out ++ field name a.toNat b.toNat
  for (name, a, b) in List.zip ["cf", "pf", "af", "zf", "sf", "of", "df"] (List.zip (flagsOf k.status) (flagsOf h.status)) do
    out := out ++ field name a.toNat b.toNat
  for i in [0:observedYmms.length] do
    out := out ++ field s!"ymm{i}" ((k.ymms.lookup i).getD 0).toNat ((h.ymms.lookup i).getD 0).toNat
  for i in [0:stackSize] do
    out := out ++ field s!"stack[{i}]" ((k.mem.lookup i).getD 0xff).toNat ((h.mem.lookup i).getD 0xff).toNat
  return out
where
  regsOf (r : Reg64s) := [r.rax, r.rbx, r.rcx, r.rdx, r.rsi, r.rdi, r.rsp, r.rbp,
    r.r8, r.r9, r.r10, r.r11, r.r12, r.r13, r.r14, r.r15]
  flagsOf (f : StatusFlags) := [f.cf, f.pf, f.af, f.zf, f.sf, f.of, f.df]

/-- Long enough for any one instruction's choices; all zeros. -/
def zeroOracle : Oracle := List.replicate 64 0

/-- An oracle under which `dir` takes `s` to the hardware's `hw`, with the resulting state. Each
`undefined` choice is located by setting all its bits and seeing which bits of the state move, and
is then read off `hw` there; that is exact because Semantics.lean stores a choice directly into
flags, a register or memory. Should it ever not reproduce `hw`, up to 2^12 assignments are tried
outright. -/
def findOracle [Labels] (dir : Directive) (p : Std.Rco Int64) (s : MachineData) (hw : Observation) :
    Option (Oracle × MachineData) := do
  let e := effectsOf dir p s
  let run (o : Oracle) : Option MachineData := match e.run 0 o with
    | (.ok s, _) => some s | _ => none
  let reproduces (o : Oracle) (s : MachineData) : Option (Oracle × MachineData) := do
    guard (Observation.of s == hw); return (o, s)
  let s0 ← run zeroOracle
  let widths := e.choiceWidths zeroOracle
  if widths.isEmpty then return ← reproduces [] s0
  let base := (Observation.of s0).bits
  let hwBits := hw.bits
  let mut o : Oracle := []
  for (w, k) in widths.zipIdx do
    let flipped := (Observation.of (← run (zeroOracle.set k (2 ^ w - 1)))).bits
    let mut v := 0
    let mut j := 0
    for i in [0:flipped.size] do
      if flipped[i]! != base[i]! then
        if hwBits[i]! then v := v ||| 1 <<< j
        j := j + 1
    o := o.concat v
  (do reproduces o (← run o)) <|> do
    guard (widths.sum ≤ 12)
    (assignments widths).findSome? fun o => do reproduces o (← run o)
where
  /-- Every oracle with values of the given widths. -/
  assignments : List Nat → List Oracle
    | [] => [[]]
    | w :: ws => (assignments ws).flatMap fun o => (List.range (2 ^ w)).map (· :: o)

/-- A hardware run of a sequence: the observable state after each instruction that completed; a
fault stopped the run after them if there are fewer states than instructions. -/
structure HardwareRun where
  seq : String
  states : Array Observation

/-- Why Kraken does not reproduce a hardware run: what happens at instruction `instr`. -/
structure Mismatch where
  instr : Nat
  message : String
  diff : List String := []
  /-- How Kraken ends the run there, when it does. -/
  ending : Option Ending := none

/-- The oracle under which Kraken reproduces `run`, and what it then observes: the hardware's states
one by one, and for an instruction the hardware did not complete, Kraken's ending under the rest of
the oracle, `[]`, just as `observe` computes it (the harness checks it against the signal). -/
def observeHardware (run : HardwareRun) : Except Mismatch (Oracle × Result) := do
  let prog ← (Kraken.X64.Parser.parse run.seq).mapError fun e => { instr := 0, message := s!"parse error: {e}" }
  let exe := prog.fakeLayout
  let := exe.labels
  let mut (s, o) := (initData, ([] : Oracle))
  for ((pc, dir, sz), i) in exe.withAddresses.zipIdx do
    let p : Std.Rco Int64 := .mk pc (pc + .ofNat sz)
    let e := effectsOf dir p s
    match run.states[i]? with
    | some hw =>
      match findOracle dir p s hw, (e.run i zeroOracle).1 with
      | some (oi, s'), _ => (s, o) := (s', o ++ oi)
      | none, .ok k =>
        throw { instr := i, message := "Kraken's state differs from the hardware's", diff := (Observation.of k).diff hw }
      | none, .error e =>
        throw { instr := i, message := "Kraken ends the run here, but the hardware completed the instruction", ending := e }
    | none =>
      match (e.run i []).1 with
      | .ok _ => throw { instr := i, message := "the hardware stopped here, but Kraken completes the instruction" }
      | .error e => return (o, { state := .of s, ending := e })
  return (o, { state := .of s, ending := .ok })

/-- A hardware state as the harness sends it: the GPRs in `Reg64s` order, rflags, each ymm as four
little-endian 64-bit words, and the stack bytes that are not `0xff`. -/
structure HardwareState where
  regs : Array Nat
  rflags : Nat
  ymms : Array (Array Nat)
  mem : Array (Nat × Nat)
  deriving FromJson

structure HardwareRunJson where
  seq : String
  states : Array HardwareState
  deriving FromJson

def HardwareState.toObservation (h : HardwareState) : Observation where
  regs := let g (i : Nat) := h.regs[i]!.toUInt64
    { rax := g 0, rbx := g 1, rcx := g 2, rdx := g 3, rsi := g 4, rdi := g 5, rsp := g 6, rbp := g 7,
      r8 := g 8, r9 := g 9, r10 := g 10, r11 := g 11, r12 := g 12, r13 := g 13, r14 := g 14, r15 := g 15 }
  status := let b := h.rflags.testBit
    { cf := b 0, pf := b 2, af := b 4, zf := b 6, sf := b 7, of := b 11, df := b 10 }
  ymms := h.ymms.toList.zipIdx.filterMap fun (ws, i) =>
    let v := ws.zipIdx.foldl (fun acc (w, j) => acc ||| BitVec.ofNat 256 w <<< (64 * j)) (0 : BitVec 256)
    if v == 0 then none else some (i, v)
  mem := h.mem.toList.map fun (i, b) => (i, b.toUInt8)

/-- Whether an access to `w` bytes at `addr` surely faults on the hardware too: the address is not
canonical or in the kernel half, or it is in the unused middle of user space, above the 4 GiB that
hold the harness binary and below the 0x7000_0000_0000 above which the mmap area, the stacks and the
vDSO lie. Kraken's `nonmem` accesses nearer its stack may hit pages the harness has mapped around
it, so they are not observable. -/
def surelyUnmapped (addr : BitVec 64) (w : Nat) : Bool :=
  2 ^ 32 ≤ addr.toNat && addr.toNat + w ≤ 0x7000_0000_0000 || 2 ^ 47 ≤ addr.toNat

def Ending.toJson : Ending → Json
  | .ok => Json.mkObj [("kind", "ok")]
  | .fault i e => Json.mkObj [("kind", "fault"), ("instr", i), ("exception", e)]
  | .unaligned i a w => Json.mkObj [("kind", "unaligned"), ("instr", i), ("addr", a.toNat), ("w", w)]
  | .unmapped i a w => Json.mkObj [("kind", "unmapped"), ("instr", i), ("addr", a.toNat), ("w", w),
      ("surelyUnmapped", surelyUnmapped a w)]
  | .unsupported i m => Json.mkObj [("kind", "unsupported"), ("instr", i), ("message", m)]

def observeJson (run : HardwareRunJson) : Json :=
  match observeHardware { seq := run.seq, states := run.states.map (·.toObservation) } with
  | .ok (o, r) => Json.mkObj [("ok", true), ("ending", r.ending.toJson), ("lean", observationDecl run.seq o r)]
  | .error m => Json.mkObj [("ok", false), ("instr", m.instr), ("error", m.message), ("diff", toJson m.diff),
      ("ending", match m.ending with | some e => e.toJson | none => Json.null)]

/-! ## Random instruction sequence generation

Candidate instructions are random `Instr`s: `gen_ctors%` derives generators from the constructors
in Syntax.lean, so every instruction form is covered without being listed here; the hand-written
instances only choose operand values. Each `--generate` draws candidates (5000 unfiltered, 200000
with prefix filter) with `ATT.instr` and keeps those `as` accepts (`genPool`, `assemblable`); every
slot of a sequence then draws from that pool until Semantics.lean runs the candidate in the current
state (`genSequence`). -/

abbrev GenM := OptionT (StateM StdGen)
def nextNat (n : Nat) : GenM Nat := modifyGet (randNat · 0 (n - 1))
def oneOf {α : Type} (xs : Array (GenM α)) : GenM α := do xs.getD (← nextNat xs.size) failure
def pick {α : Type} (xs : Array α) : GenM α := oneOf (xs.map pure)

class Gen (α : Type) where gen : GenM α
export Gen (gen)

open Elab Term in
/-- Picks a constructor of inductive type `T` uniformly (inferring `T`'s parameters) and draws each
of its fields from `gen`. -/
elab "gen_ctors% " t:ident : term <= ty => do
  let alts ← (← getConstInfoInduct (← realizeGlobalConstNoOverload t)).ctors.toArray.mapM fun c => do
    let info ← getConstInfoCtor c
    let hole ← `(_)
    let field ← `((← gen))
    `(do return @$(mkIdent c) $(.replicate info.numParams hole)* $(.replicate info.numFields field)*)
  elabTerm (← `(oneOf #[$alts,*])) ty

instance {α : Type} [Gen α] : Gen (Option α) := ⟨gen_ctors% Option⟩
instance : Gen Width := ⟨gen_ctors% Width⟩
instance : Gen AvxWidth := ⟨gen_ctors% AvxWidth⟩
instance : Gen RegMm := ⟨gen_ctors% RegMm⟩
instance : Gen Reg64 := ⟨gen_ctors% Reg64⟩
instance : Gen CondCode := ⟨gen_ctors% CondCode⟩
instance : Gen AddrIndex := ⟨gen_ctors% AddrIndex⟩
-- Opcode families: uniformly over their opcodes.
instance {α : Type} [Mnemonic α] : Gen α := ⟨(·.1) <$> pick Mnemonic.names⟩

-- No labels (for `jcc`), nop lengths or alignments; other control flow is rejected by
-- `genSequence`.
instance : Gen String := ⟨failure⟩
instance : Gen Nat := ⟨failure⟩
-- Small values (below 2^3), the boundaries of each width, and uniformly random values of each width.
instance : Gen Int64 where gen := do
  let n : Int := 2 ^ (← pick #[3, 8, 16, 32, 64])
  return .ofInt (← pick #[0, 1, -1, n / 2 - 1, -(n / 2), n - 1, (← nextNat n.toNat)])
-- Code addresses differ between Kraken's layout and the hardware binary, so no labels, nor
-- `before/after_current_instruction`, nor rip-relative addressing.
instance : Gen ConstExpr := ⟨.int64 <$> gen⟩
instance : Gen RegOrRip := ⟨.reg <$> gen⟩
-- Indexed families, which `gen_ctors%` can't handle.
instance {w} : Gen (Reg w) where gen := match w with
  | .W8 => oneOf #[(.low · .W8) <$> gen, pick #[.ah, .bh, .ch, .dh]] | w => (.low · w) <$> gen
instance {w} : Gen (AvxReg w) where gen := match w with
  | .W128 => .xmm <$> gen | .W256 => .ymm <$> gen | .W512 => .zmm <$> gen
-- Half of all addresses are slots in Kraken's stack mapping [rsp - 800, rsp) (usable when the
-- instruction's address size is 64 bits).
instance : Gen AddrExpr := ⟨oneOf #[gen_ctors% AddrExpr,
  return { base := some (.reg .rsp), idx := none, disp := .int64 (.ofInt (-1 - (← nextNat stackSize))) }]⟩

instance : Gen ShiftCountExpr := ⟨gen_ctors% ShiftCountExpr⟩
instance : Gen RelRegOrMem := ⟨gen_ctors% RelRegOrMem⟩
instance {w} : Gen (RegOrMem w) := ⟨gen_ctors% RegOrMem⟩
instance {w} : Gen (Operand w) := ⟨gen_ctors% Operand⟩
instance {w} : Gen (AvxRegOrMem w) := ⟨gen_ctors% AvxRegOrMem⟩
instance {w} : Gen (Operation w) := ⟨gen_ctors% Operation⟩
instance {w} : Gen (AvxOperation w) := ⟨gen_ctors% AvxOperation⟩
instance : Gen Instr := ⟨gen_ctors% Instr⟩

/-- The candidates that `as` assembles without errors or warnings. APX is excluded because the
hardware lacks it (e.g. `imul %edx, %r12d, %edi`), AVX-512 because the harness only observes
ymm0-15. -/
def assemblable (cands : Array String) : IO (Array String) := IO.FS.withTempFile fun h path => do
  h.putStr ("\n".intercalate cands.toList ++ "\n"); h.flush
  let out ← IO.Process.output { cmd := "as", args := #["-march=+noapx_f+noavx512f", "-o", "/dev/null", path.toString] }
  let pfx := path.toString ++ ":"
  let bad := out.stderr.splitOn "\n" |>.filterMap fun l =>
    (l.dropPrefix? pfx).bind (·.takeWhile Char.isDigit |>.toString.toNat?)
  if out.exitCode != 0 && bad.isEmpty then throw (.userError out.stderr)
  return cands.zipIdx.filterMap fun (c, i) => if bad.contains (i + 1) then none else some c

/-- One random instruction in AT&T syntax. A separate definition so that the `Instr` generator,
which grows with every opcode family, is compiled once rather than specialized into `genPool`. -/
def genInstr : StateM StdGen (Option String) := (Kraken.X64.ATT.instr <$> gen).run

def genPool (n : Nat) : StateM StdGen (Array String) :=
  (Array.range n).filterMapM fun _ => genInstr

-- Initializes a register other than rsp.
def genSeed : GenM String := do
  let r ← gen; guard (r != Reg64.rsp)
  let r := Kraken.X64.ATT.reg (.low r .W64)
  let movabs : GenM String := do return s!"movabsq ${← nextNat (2 ^ 64)}, {r}"
  oneOf #[movabs,
    -- An address in the stack mapping, for memory operands.
    do return s!"leaq -{(← nextNat (stackSize - 300)) + 300}(%rsp), {r}",
    -- A small count (for rep, loop, and shifts by %cl).
    do return s!"movq ${← nextNat 16}, {r}",
    -- Also copy a random value into one of xmm0-15 via the stack; they start zeroed, so SSE ops
    -- would otherwise see only zeros.
    do
      let m ← movabs
      return s!"{m}\nmovq {r}, -16(%rsp)\nmovq {r}, -8(%rsp)\nmovups -16(%rsp), %xmm{← nextNat 16}"]

/-- Whether a sequence may end with `e`: a fault the hardware shows as a signal. -/
def observableEnding : Ending → Bool
  | .fault .. | .unaligned .. => true
  | .unmapped _ a w => surelyUnmapped a w
  | .ok | .unsupported .. => false

-- Four random register initializations (`genSeed`) followed by `length` instructions from `pool`, each drawn
-- until Semantics.lean runs it in the current state (with every `undefined` choice zero); the last
-- one may instead fault (`observableEnding`).
def genSequence (pool : Array String) (length : Nat) : StateM StdGen String := do
  let mut (d, lines) := (initData, #[])
  for i in [0 : 4 + length] do
    for _ in [0 : 200] do
      let some cand ← (if i < 4 then genSeed else pick pool).run | continue
      match runFrom zeroOracle d cand with
      | (d', .ok) => (d, lines) := (d', lines.push cand); break
      | (_, e) => if i == 3 + length && observableEnding e then lines := lines.push cand; break
  return "\n".intercalate lines.toList

public def main (args : List String) : IO UInt32 := do
  match args with
  | "--generate" :: seed :: count :: length :: only =>
    -- Draw more candidates when only instructions starting with one of `only` are wanted.
    let (pool, g) := (genPool (if only.isEmpty then 5000 else 200000)).run (mkStdGen seed.toNat!)
    -- Deduplicated, so that forms with few operand choices (e.g. `vzeroall`) don't dominate.
    let pool := (pool.filter fun l => only.isEmpty || only.any fun o => l.startsWith o).qsort (· < ·)
    let pool ← assemblable pool.toList.eraseReps.toArray
    let gen := (List.range count.toNat!).mapM fun _ => genSequence pool length.toNat!
    IO.println (toJson (gen.run' g).run).compress
    return 0
  | ["--observe"] =>
    let raw ← (← IO.getStdin).readToEnd
    let runs ← IO.ofExcept (Json.parse raw >>= fromJson? (α := Array HardwareRunJson))
    IO.println (toJson (runs.map observeJson)).compress
    return 0
  | _ => pure ()

  if args.isEmpty then return 1

  let asmCode ← IO.FS.readFile args[0]!

  match runKraken asmCode with
  | .ok (state, _) =>
      IO.println (toJson (summarize state)).compress
      return 0
  | .error e =>
      IO.eprintln s!"Kraken Semantic Error: {e}"
      return 1
