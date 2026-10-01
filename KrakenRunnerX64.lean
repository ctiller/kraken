module

/-
KrakenRunnerX64 - Run assembly instructions through Kraken Semantics and obtain results as json.

At this point this expects a file only containing a list of assembly instructions, no data block or similar.

Usage: krakenrunner_x64 <assembly.S>
       krakenrunner_x64 --generate <seed> <count> <length> [prefix...]  (random sequences that Kraken deems
        deterministic, optionally drawing only instructions starting with one of the prefixes)
       krakenrunner_x64 --batch < sequences.json              (predict final states for a JSON array of sequences)

Arguments:
- assembly.S: Assembly source file

Output:
- Json formatted Machine state of Kraken after running the assembly.
  See StateSummary for format.
-/

import Kraken.Mem
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

-- Give the program a stack of 800B initially, mapped at a plausible place.
def stackSize := 800
-- Place the stack somewhere high in memory, aligned to 256 bytes. This will
-- help us avoid disagreements with the actual machine: we will avoid over/underflow
-- when we allocate stack memory using arithmetic instructions (which would happen
-- if the stack were at 0), and fixing the last byte of the address at 0 means that
-- we will match PF for these operations (providing that we also align rsp on
-- hardware; fuzz_x64.py uses exactly this rsp).
def stackLocation: UInt64 := 0x7ffecafee200
def initStack : DataMem := (List.replicate stackSize 0xff).At (stackLocation - stackSize)
def initData : MachineData := {regs := {rsp := stackLocation}, dmem := initStack}

def finishCriterion (p: Program) (s: MachineState): Bool :=
  s.2 = p.fakeLayout.labels.label _end

def runKraken (asmCode : String)
    : Except String MachineState := do
  let prog ← Kraken.X64.Parser.parse (_start ++ ":" ++ asmCode ++ "\n" ++ _end ++ ":")
  let initState: MachineState := (initData, prog.fakeLayout.labels.label _start)
  prog.fakeLayout.eval initState (finishCriterion prog)

def numStatusFlags : Nat := 7

/-! ## Determinism checking, with Semantics.lean in the loop

We track which of the seven status flags are currently undefined as a bitmask using the
bit layout of `NondetSupportingType.from_hash` (cf, pf, af, zf, sf, of, df = bits 0..6). -/

def StatusFlags.toMask (f : StatusFlags) : Nat :=
  f.cf.toNat ||| f.pf.toNat <<< 1 ||| f.af.toNat <<< 2 ||| f.zf.toNat <<< 3 ||| f.sf.toNat <<< 4 ||| f.of.toNat <<< 5 ||| f.df.toNat <<< 6

-- Runs `Effects` to completion, resolving every `undefined` choice with `h`. Also returns
-- whether any `undefined` choice was made.
partial def evalEffects (h : UInt64) (sawUndef : Bool) : Effects → Option (MachineData × Bool)
  | .done (s, _) => some (s, sawUndef)
  | .require_read_access _ _ ok | .require_write_access _ _ ok | .require_exec_access _ ok => evalEffects h sawUndef (ok ())
  | @Effects.undefined _ t cont => evalEffects h true (cont (t.from_hash h))
  | _ => none

/-- Executes `asmCode` (straight-line, no jumps) from `d`, where `mask` are the flags currently
undefined. Each instruction is run under every assignment of the undefined flags, and (if it makes
`undefined` choices) with those resolved to all-zeros and to all-ones. Fails unless registers and
memory agree across all runs; returns the resulting state and the new mask of flags that disagree.

Two samples suffice only because of how Semantics.lean uses `undefined` choices. All choices in
a run are resolved from the same `h` (`NondetSupportingType.from_hash`): `h = 0` makes every Bool
false and every bit vector zero, `h = -1` every Bool true and every bit vector all-ones. An
instruction's nondeterminism is therefore caught if its registers or memory differ between these
two resolutions, which holds when its register- or memory-affecting choices are
- bit vectors stored directly into a destination (zero and all-ones differ in every bit), and
- at most one Bool, even if computed with (both values are sampled): e.g. `SimdBinOp.eval`'s
  hadd operand order, or whether a failed 32-bit `cmpxchg` writes its destination.
Choices that only affect flags need no such argument: flags that differ become undefined
(`mask`). The filter would miss an instruction with two register-affecting Bool choices whose
mixed assignments give a different result from both all-false and all-true, or a bit-vector
choice used in a computation that maps zero and all-ones to the same result. None exists today;
adding one would need a hash per choice. -/
def stepDeterministic (d : MachineData) (mask : Nat) (asmCode : String) : Option (MachineData × Nat) := do
  let exe := (← (Kraken.X64.Parser.parse asmCode).toOption).fakeLayout
  let := exe.labels
  let mut (d, mask) := (d, mask)
  for (pc, dir, sz) in exe.withAddresses do
    let p : Std.Rco Int64 := .mk pc (pc + .ofNat sz)
    let fixed := d.status.toMask &&& ((2^numStatusFlags - 1) ^^^ mask)
    let run (m : Nat) (h : UInt64) : Option (MachineData × Bool) :=
      let status : StatusFlags := NondetSupportingType.from_hash (fixed ||| m).toUInt64
      evalEffects h false (dir.interp { d with status } p (fun s => .done (s, p.upper)) (fun _ _ => .unimplemented "jump"))
    let mut outs : Array MachineData := #[]
    for m in (List.range (2^numStatusFlags)).filter (fun m => m &&& mask == m) do
      let (s, sawUndef) ← run m 0
      outs := outs.push s
      if sawUndef then outs := outs.push (← run m (-1)).1
    let s0 ← outs[0]?
    if outs.any ({ · with status := s0.status } != s0) then failure
    (d, mask) := (s0, outs.foldl (fun acc s => acc ||| (s.status.toMask ^^^ s0.status.toMask)) 0)
  return (d, mask)

def predict (asmCode : String) : Json :=
  match stepDeterministic initData 0 asmCode with
  | some (s, 0) => Json.mkObj [("ok", toJson true), ("state", toJson (summarize s))]
  | _ => Json.mkObj [("ok", toJson false), ("error", toJson "unparseable, faulting, jumping, or non-deterministic")]

/-! ## Random instruction sequence generation

Candidate instructions are random `Instr`s: `gen_ctors%` derives generators from the constructors
in Syntax.lean, so every instruction form is covered without being listed here; the hand-written
instances only choose operand values. Each `--generate` draws candidates (5000 unfiltered, 200000
with prefix filter) with `ATT.instr` and keeps those `as` accepts (`genPool`, `assemblable`); every
slot of a sequence then draws from that pool until Semantics.lean deems the candidate deterministic
in the current state (`stepDeterministic`). -/

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
instance : Gen LoopCond := ⟨gen_ctors% LoopCond⟩
instance : Gen RepPrefix := ⟨gen_ctors% RepPrefix⟩
instance : Gen AddrIndex := ⟨gen_ctors% AddrIndex⟩
-- Opcode families: uniformly over their opcodes.
instance {α : Type} [Mnemonic α] : Gen α := ⟨(·.1) <$> pick Mnemonic.names⟩

-- No labels (for `jcc`, `jrcxz`, `loop`), nop lengths or alignments; instructions with label
-- operands are never generated (only asm tests cover them). Other control flow is rejected by
-- `stepDeterministic`.
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
instance : Gen SimdCount := ⟨gen_ctors% SimdCount⟩
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

set_option maxHeartbeats 4000000 in
def genPool (n : Nat) : StateM StdGen (Array String) :=
  (Array.range n).filterMapM fun _ => (Kraken.X64.ATT.instr <$> gen).run

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
    -- A random value that is also spread over one of ymm0-15 as four distinct qwords via the
    -- stack; they start zeroed, so vector ops would otherwise see only zeros.
    do
      let qs ← [32, 24, 16, 8].mapM fun o => do return s!"{← movabs}\nmovq {r}, -{o}(%rsp)"
      return "\n".intercalate qs ++ s!"\nvmovdqu -32(%rsp), %ymm{← nextNat 16}"]

-- Four random register initializations (`genSeed`) followed by `length` instructions from `pool`, each drawn
-- until `stepDeterministic` accepts one. A final `add` makes all flags defined.
def genSequence (pool : Array String) (length : Nat) : StateM StdGen String := do
  let mut (d, mask, lines) := (initData, 0, #[])
  for i in [0 : 4 + length] do
    for _ in [0 : 200] do
      let some cand ← (if i < 4 then genSeed else pick pool).run | continue
      if let some (d', mask') := stepDeterministic d mask cand then
        (d, mask, lines) := (d', mask', lines.push cand)
        break
  if mask != 0 then lines := lines.push "addq %rax, %rax"
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
  | ["--batch"] =>
    let raw ← (← IO.getStdin).readToEnd
    let seqs ← IO.ofExcept (Json.parse raw >>= fromJson? (α := Array String))
    IO.println (toJson (seqs.map predict)).compress
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
