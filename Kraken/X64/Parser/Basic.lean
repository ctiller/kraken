module

/-
Kraken Parser - x86_64 AT&T Assembly Parser

Parses AT&T syntax assembly strings into Kraken's Program type.
Uses Lean's built-in Std.Internal.Parsec library.

The primary reference for the syntax is the GAS manual:
https://sourceware.org/binutils/docs/as/

The parser lives in `Basic.lean` so `Parser.lean` can import it at both the
runtime and `meta` phases.
-/

public import Kraken.X64.Syntax
import Std.Internal.Parsec.String

namespace Kraken.X64.Parser

open Std.Internal.Parsec
open Std.Internal.Parsec.String

-- ============================================================================
-- Data structures for type inference
-- ============================================================================

-- We need to eagerly parse (to move through the syntax), but we may need to
-- defer choosing a width for those operands that are untyped (as in: may have
-- any width).
def MaybeOpWidth (T: Width → Type) :=
  Σ (w: Option Width), match w with | .some w => T w | .none => { w: Width } → T w

def MaybeAvxOpWidth (T: AvxWidth → Type) :=
  Σ (w: Option AvxWidth), match w with | .some w => T w | .none => { w: AvxWidth } → T w

-- Most of our parsing functions return a MaybeAddrWidth × MaybeTyped T, in case
-- the operand we just parsed happens to be a memory operand, which thus allows
-- the assembler to infer the address width used for the instruction (see
-- comments in Syntax).
abbrev MaybeAddrWidth := Option Width

-- This could be Option.mergeM if it existed.
--
-- No x86 assembly instructions take two memory operands: this means that we
-- have at most one address width hint per instruction.
def mergeAddrWidths (w1 w2: MaybeAddrWidth): Parser MaybeAddrWidth :=
  match w1, w2 with
  | .none, .none => pure .none
  | .some w1, .none
  | .none, .some w1 => pure (.some w1)
  | .some _, .some _ => fail "can't have two memory operands"

-- If the context provides a type annotation, this forces a given width, or
-- errors out if an incompatible one has been inferred.
def ascribe {T: Width → Type} (w: Width) (v: MaybeOpWidth T): Parser (T w) := do
  match v with
  | ⟨ .none, v ⟩ => pure v
  | ⟨ .some w2, v ⟩ =>
    if h: w = w2 then
      pure (h ▸ v)
    else
      fail s!"type error: {w} != {w2}"

def ascribeAvx {T: AvxWidth → Type} (w: AvxWidth) (v: MaybeAvxOpWidth T): Parser (T w) := do
match v with
  | ⟨ .none, v ⟩ => pure v
  | ⟨ .some w2, v ⟩ =>
    if h: w = w2 then
          pure (h ▸ v)
    else
          fail s!"type error: {w} != {w2}"

def ascribeOrInfer {T1 T2} (op1: MaybeAddrWidth × MaybeOpWidth T1) (next: Parser (MaybeAddrWidth × MaybeOpWidth T2)): Parser (MaybeAddrWidth × Σ w, T1 w × T2 w) := do
  let (addr_w2, op2) ← next
  let (addr_w1, op1) := op1
  let addr_w ← mergeAddrWidths addr_w1 addr_w2
  match op1 with
  | ⟨ .some w1, op1 ⟩ =>
    let op2 ← ascribe w1 op2
    pure (addr_w, ⟨ w1, op1, op2 ⟩)
  | ⟨ .none, op1 ⟩ =>
    match op2 with
    | ⟨ .some w2, op2 ⟩ =>
      pure (addr_w, ⟨ w2, op1, op2 ⟩)
    | ⟨ .none, _ ⟩ =>
      fail "missing type annotation"

def ascribeOrInferAvx {T1 T2} (op1: MaybeAddrWidth × MaybeAvxOpWidth T1) (next: Parser (MaybeAddrWidth × MaybeAvxOpWidth T2)): Parser (MaybeAddrWidth × Σ w, T1 w × T2 w) := do
  let (addr_w2, op2) ← next
  let (addr_w1, op1) := op1
  let addr_w ← mergeAddrWidths addr_w1 addr_w2
  match op1 with
    | ⟨ .some w1, op1 ⟩ =>
      let op2 ← ascribeAvx w1 op2
      pure (addr_w, ⟨ w1, op1, op2 ⟩)
    | ⟨ .none, op1 ⟩ =>
      match op2 with
      | ⟨ .some w2, op2 ⟩ =>
        pure (addr_w, ⟨ w2, op1, op2 ⟩)
      | ⟨ .none, _ ⟩ =>
        fail "missing type annotation"

-- Naming convention: O = function takes an operand width
def parseO {T1} (op: Parser (MaybeOpWidth T1)) (w: Width): Parser (T1 w) := do
  let op ← op
  ascribe w op

-- Naming convention: A = function also returns an address width
def parseAO {T1} (op: Parser (MaybeAddrWidth × MaybeOpWidth T1)) (w: Width): Parser (MaybeAddrWidth × T1 w) := do
  let (addr_w, op) ← op
  let op ← ascribe w op
  pure (addr_w, op)

def parseAvxAO {T1} (op: Parser (MaybeAddrWidth × MaybeAvxOpWidth T1)) (w: AvxWidth): Parser (MaybeAddrWidth × T1 w) := do
  let (addr_w, op) ← op
  let op ← ascribeAvx w op
  pure (addr_w, op)

-- ============================================================================
-- Lexical Utilities
-- ============================================================================

/-- Skip zero or more horizontal whitespace characters (space, tab). -/
def skipHWs : Parser Unit := do
  let _ ← many (pchar ' ' <|> pchar '\t')

/-- Skip a line comment starting with # or //. -/
def skipLineComment : Parser Unit := do
  -- JP: the '/' below is presumably a dummy value?
  let _ ← pchar '#' <|> (pstring "//" *> pure '/')
  let _ ← many (satisfy fun c => c != '\n')
  pure ()

/-- Skip horizontal whitespace and comments on the same line. -/
def skipHWsAndComments : Parser Unit := do
  skipHWs
  (skipLineComment *> pure ()) <|> pure ()

/-- Parse a single decimal digit. -/
def digit : Parser Char := satisfy fun c => c >= '0' && c <= '9'

/-- Parse a single hex digit. -/
def hexDigit : Parser Char := satisfy fun c =>
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

def hexVal (c : Char) : Int :=
    if c >= '0' && c <= '9' then c.toNat - '0'.toNat
    else if c >= 'a' && c <= 'f' then c.toNat - 'a'.toNat + 10
    else c.toNat - 'A'.toNat + 10

def parseHexOrDec : Parser Int := do
    let c ← peek!
    if c == '0' then do
      skip
      if (← peek?) matches some 'x' | some 'X' then do
        skip
        let digits ← many1 hexDigit
        pure (digits.foldl (fun acc d => acc * 16 + hexVal d) 0)
      else do
        let rest ← many digit
        let allDigits := #['0'] ++ rest
        pure (allDigits.foldl (fun acc d => acc * 10 + (d.toNat - '0'.toNat)) 0)
    else do
      let digits ← many1 digit
      pure (digits.foldl (fun acc d => acc * 10 + (d.toNat - '0'.toNat)) 0)

/-- Parse a signed integer (decimal or hex). -/
def parseInt : Parser Int := do
  skipHWs
  let neg ← (pchar '-' *> pure true) <|> pure false
  let val ← parseHexOrDec
  pure (if neg then -val else val)

/-- Parse a name (identifier or label). -/
def parseName : Parser String := do
  let first ← satisfy fun c => c.isAlpha || c == '_' || c == '.'
  let rest ← many (satisfy fun c => c.isAlphanum || c == '_' || c == '.')
  pure (String.ofList (#[first] ++ rest).toList)

-- ============================================================================
-- Register Parsing
-- ============================================================================

section RegParsing

open Reg

-- Conventions: the *W variants are dependent pairs, and are used for parsing
-- functions that can synthesize (bottom-up) the width information. Parsing
-- functions that cannot synthesize a type take a width as an argument.

/-- Parse a register name. Returns the Reg (may be an alias like eax, ax, al). -/
def parseRegNameW : Parser RegW := do
  let name ← parseName
  match name.toLower with
  -- 64-bit registers
  | "rax" => pure ⟨ .W64, rax ⟩ | "rbx" => pure ⟨ .W64, rbx ⟩ | "rcx" => pure ⟨ .W64, rcx ⟩ | "rdx" => pure ⟨ .W64, rdx ⟩
  | "rsi" => pure ⟨ .W64, rsi ⟩ | "rdi" => pure ⟨ .W64, rdi ⟩ | "rsp" => pure ⟨ .W64, rsp ⟩ | "rbp" => pure ⟨ .W64, rbp ⟩
  | "r8"  => pure ⟨ .W64, r8  ⟩ | "r9"  => pure ⟨ .W64, r9 ⟩  | "r10" => pure ⟨ .W64, r10 ⟩ | "r11" => pure ⟨ .W64, r11 ⟩
  | "r12" => pure ⟨ .W64, r12 ⟩ | "r13" => pure ⟨ .W64, r13 ⟩ | "r14" => pure ⟨ .W64, r14 ⟩ | "r15" => pure ⟨ .W64, r15 ⟩
  -- 32-bit aliases
  | "eax" => pure ⟨ .W32, eax ⟩ | "ebx" => pure ⟨ .W32, ebx ⟩ | "ecx" => pure ⟨ .W32, ecx ⟩ | "edx" => pure ⟨ .W32, edx ⟩
  | "esi" => pure ⟨ .W32, esi ⟩ | "edi" => pure ⟨ .W32, edi ⟩ | "esp" => pure ⟨ .W32, esp ⟩ | "ebp" => pure ⟨ .W32, ebp ⟩
  | "r8d"  => pure ⟨ .W32, r8d ⟩  | "r9d"  => pure ⟨ .W32, r9d ⟩  | "r10d" => pure ⟨ .W32, r10d ⟩ | "r11d" => pure ⟨ .W32, r11d ⟩
  | "r12d" => pure ⟨ .W32, r12d ⟩ | "r13d" => pure ⟨ .W32, r13d ⟩ | "r14d" => pure ⟨ .W32, r14d ⟩ | "r15d" => pure ⟨ .W32, r15d ⟩
  -- 16-bit aliases
  | "ax" => pure ⟨ .W16, ax ⟩ | "bx" => pure ⟨ .W16, bx ⟩ | "cx" => pure ⟨ .W16, cx ⟩ | "dx" => pure ⟨ .W16, dx ⟩
  | "si" => pure ⟨ .W16, si ⟩ | "di" => pure ⟨ .W16, di ⟩ | "sp" => pure ⟨ .W16, sp ⟩ | "bp" => pure ⟨ .W16, bp ⟩
  | "r8w"  => pure ⟨ .W16, r8w ⟩  | "r9w"  => pure ⟨ .W16, r9w ⟩  | "r10w" => pure ⟨ .W16, r10w ⟩ | "r11w" => pure ⟨ .W16, r11w ⟩
  | "r12w" => pure ⟨ .W16, r12w ⟩ | "r13w" => pure ⟨ .W16, r13w ⟩ | "r14w" => pure ⟨ .W16, r14w ⟩ | "r15w" => pure ⟨ .W16, r15w ⟩
  -- 8-bit aliases
  | "al" => pure ⟨ .W8, al ⟩ | "bl" => pure ⟨ .W8, bl ⟩ | "cl" => pure ⟨ .W8, cl ⟩ | "dl" => pure ⟨ .W8, dl ⟩
  | "sil" => pure ⟨ .W8, sil ⟩ | "dil" => pure ⟨ .W8, dil ⟩ | "spl" => pure ⟨ .W8, spl ⟩ | "bpl" => pure ⟨ .W8, bpl ⟩
  | "r8b"  => pure ⟨ .W8, r8b ⟩  | "r9b"  => pure ⟨ .W8, r9b ⟩  | "r10b" => pure ⟨ .W8, r10b ⟩ | "r11b" => pure ⟨ .W8, r11b ⟩
  | "r12b" => pure ⟨ .W8, r12b ⟩ | "r13b" => pure ⟨ .W8, r13b ⟩ | "r14b" => pure ⟨ .W8, r14b ⟩ | "r15b" => pure ⟨ .W8, r15b ⟩
  -- high-byte registers
  | "ah" => pure ⟨ .W8, ah ⟩ | "bh" => pure ⟨ .W8, bh ⟩ | "ch" => pure ⟨ .W8, ch ⟩ | "dh" => pure ⟨ .W8, dh ⟩
  | _ => fail s!"unknown register: {name}"

/-- Safely map a natural number index to its corresponding RegMm constructor. -/
def toRegMm (idx : Nat) : Option RegMm :=
  match idx with
  | 0  => some .mm0  | 1  => some .mm1  | 2  => some .mm2  | 3  => some .mm3
  | 4  => some .mm4  | 5  => some .mm5  | 6  => some .mm6  | 7  => some .mm7
  | 8  => some .mm8  | 9  => some .mm9  | 10 => some .mm10 | 11 => some .mm11
  | 12 => some .mm12 | 13 => some .mm13 | 14 => some .mm14 | 15 => some .mm15
  | 16 => some .mm16 | 17 => some .mm17 | 18 => some .mm18 | 19 => some .mm19
  | 20 => some .mm20 | 21 => some .mm21 | 22 => some .mm22 | 23 => some .mm23
  | 24 => some .mm24 | 25 => some .mm25 | 26 => some .mm26 | 27 => some .mm27
  | 28 => some .mm28 | 29 => some .mm29 | 30 => some .mm30 | 31 => some .mm31
  | _ => none

/-- Parse an AVX register operand (e.g., %xmm0, %ymm15, %zmm31). -/
def parseAvxRegW : Parser AvxRegW := do
  skipHWs
  let _ ← pchar '%'
  -- Match standard or uppercase variants of the AVX prefixes
  let pfx ← (pstring "xmm" <|> pstring "XMM" <|>
             pstring "ymm" <|> pstring "YMM" <|>
             pstring "zmm" <|> pstring "ZMM")
  let idx ← digits
  match toRegMm idx with
  | none => fail s!"invalid AVX register index: {idx} (must be between 0 and 31)"
  | some mm =>
    match pfx.toLower with
    | "xmm" => pure ⟨ .W128, .xmm mm ⟩
    | "ymm" => pure ⟨ .W256, .ymm mm ⟩
    | "zmm" => pure ⟨ .W512, .zmm mm ⟩
    | _ => fail s!"unknown AVX register prefix: {pfx}"
end RegParsing

/-- Parse a register operand: %rax, %eax, %ax, %al, etc. -/
def parseRegW : Parser RegW := do
  skipHWs
  let _ ← pchar '%'
  parseRegNameW

def parseLowRegName: Parser (Width × Reg64) := do
  let ⟨ w, r ⟩ ← parseRegNameW
  match r with
  | .low r64 _ => pure (w, r64)
  | _ => fail s!"high byte register cannot be used for an addrexpr"

def parseLowReg : Parser (Width × Reg64) := do
  skipHWs
  let _ ← pchar '%'
  parseLowRegName

def parseRegOrRipW : Parser (Width × RegOrRip) := do
  skipHWs
  let _ ← pchar '%'
  (do
    let _ ← pstring "rip"
    -- TODO: once we start parsing %eip here, we need to understand what is the
    -- behavior in 64-bit mode when the .S contains %eip -- does the address get
    -- clamped to 32 bits? in that case, Semantics.lean needs to be updated to
    -- process the `.rip` case via `toAddressSize`
    pure (.W64, .rip)
  ) <|>
  (do
    let (w, r) ← parseLowRegName -- WAS: parseRegNameW
    pure (w, .reg r)
  )


-- ============================================================================
-- Operand Parsing
-- ============================================================================

/-- Parse an immediate operand: $42, $-17, $0xff.
    Accepts any 64-bit value (0 to 2^64-1) as a bit pattern.
    Values like $0xFFFFFFFFFFFFFFFF are interpreted as -1 in two's complement. -/
def parseInt64 : Parser ConstExpr := do
  let _ ← pchar '$'
  let v ← parseInt
  -- JP: why not simply Int64.ofInt? Would that not implement the behavior
  -- below?

  -- Accept any value that fits in 64 bits
  -- Negative values: must be >= Int64.min (-2^63)
  -- Positive values: must be < 2^64 (allows unsigned representation like 0xFFFFFFFFFFFFFFFF)
  if v < -9223372036854775808 || v >= 18446744073709551616 then
    fail s!"immediate {v} out of 64-bit range"
  -- Convert to Int64: values > Int64.max are reinterpreted as negative (two's complement)
  let i64 := if v > 9223372036854775807 then
    -- Reinterpret large positive value as negative two's complement
    Int64.ofInt (v - 18446744073709551616)
  else
    Int64.ofInt v
  pure (.int64 i64)

-- parseName allows for dots
def parseLabelRaw : Parser Label := parseName

def parseLabel : Parser ConstExpr := do
  let n ← parseLabelRaw
  pure (.label n)

/-- Parse a memory operand (a.k.a. "address expression"): disp(%base),
  (%base,%idx,scale), etc. Just like `as`, we enforce consistency at the level
  of operands. For instance, we also error out on this:

  test3.S:1:13: error: base register is 64-bit, but index register is not
  movq %rax, (%rcx, %ebx)
              ^
-/
def parseMemory : Parser (Width × AddrExpr) := do
  skipHWs
  -- Optional displacement; TODO: parse ConstExpr generally
  let disp ← (do let i ← parseInt; pure (.int64 (Int64.ofInt i))) <|> parseLabel <|> pure (.int64 0)
  skipHWs
  let _ ← pchar '('

  skipHWs
  let (w1, base) ← parseRegOrRipW
  -- Check for index register
  let idx ← (do
    skipHWs
    let _ ← pchar ','
    skipHWs
    let r ← parseLowReg
    pure (some r)) <|> pure none
  -- Check for scale
  let scale ← match idx with
    | some _ => (do
        skipHWs
        let _ ← pchar ','
        skipHWs
        let s ← parseInt
        pure s.toNat) <|> pure 1
    | none => pure 1
  let scale ← match scale with
              | 1 => pure Width.W8
              | 2 => pure Width.W16
              | 4 => pure Width.W32
              | 8 => pure Width.W64
              | s => fail s!"invalid scale {s}, must be 1, 2, 4, or 8"
  -- JP: this is slightly inexact, in that we allow parsing a scale without an
  -- index, but not a big deal
  skipHWs
  let _ ← pchar ')'
  -- Some adapters between the parsed components and the expected dependent
  -- pairs:
  let w ← match w1, idx with
    | w1, .some (w2, _) =>
      if w1 ≠ w2 then
        fail "type mismatch in memory addressing operands: base ({w1}) and index ({w2}) have different widths"
      else
        .pure w1
    | w1, .none =>
      .pure w1
  let idx := Option.map (fun (_, idx) => ⟨idx, scale⟩) idx

  -- Handle rip-relative addressing (like parseRelRegOrMem below).
  let disp := match base, disp with
    | .rip, .label l => .sub (.label l) .after_current_instruction
    | _, _ => disp

  pure (w, { base, idx, disp })

def parseImm w : Parser (Operand w) := do
  skipHWs
  let c ← peek!
  let i ←
    match c with
    | '$' => parseInt64
    | _ => parseLabel
  pure (.imm i)

/-- Parse any operand: register, immediate, or memory. -/
def parseOperand: Parser (MaybeAddrWidth × MaybeOpWidth Operand) := do
  skipHWs
  let c ← peek!
  match c with
  | '%' =>
    let ⟨ w, r ⟩ ← parseRegW
    pure (.none, ⟨ w, .reg r ⟩)
  | '$' =>
    let i ← parseInt64
    pure (.none, ⟨ .none, .imm i ⟩)
  | _ =>
    if c == '(' || c == '-' || c.isDigit then
      let (w, m) ← parseMemory
      pure (w, ⟨ .none, .mem m ⟩)
    else
      let i ← parseLabel
      pure (.none, ⟨ .none, .imm i ⟩)

/-- Parse a register or memory operand (not immediate). -/
def parseRegOrMem: Parser (MaybeAddrWidth × MaybeOpWidth RegOrMem) := do
  skipHWs
  let c ← peek!
  if c == '%' then
    let ⟨ w, r ⟩ ← parseRegW
    pure (.none, ⟨ .some w, .reg r ⟩)
  else if c == '(' || c == '-' || c.isDigit then
    let (w, m) ← parseMemory
    pure (w, ⟨ .none, .mem m ⟩)
  else
    fail s!"expected register or memory operand, got {c}"

def parseAvxRegOrMem: Parser (MaybeAddrWidth × MaybeAvxOpWidth AvxRegOrMem) := do
  skipHWs
  let c ← peek!
  if c == '%' then
    let ⟨ w, r ⟩ ← parseAvxRegW
    pure (.none, ⟨ .some w, .avx r ⟩)
  else if c == '(' || c == '-' || c.isDigit then
    let (w, m) ← parseMemory
    pure (w, ⟨ .none, .mem m ⟩)
  else
      fail s!"expected AVX register or memory operand, got {c}"

def parseRelRegOrMem: Parser (MaybeAddrWidth × RelRegOrMem) := do
  skipHWs
  (do
    let ⟨ w, r ⟩ ← parseRegW
    if h: w = .W64 then
      pure (.none, (.reg (h ▸ r)))
    else
      fail "expected a 64-bit register in relative addressing position"
  ) <|> (do
    -- FIXME: allow more cases in the syntax; for now, we only parse labels, and
    -- assume that all jumps are relative, in that this seems to be the behavior
    -- of the assembler
    let e ← parseLabel
    pure (.none, (.rel (.sub e .after_current_instruction)))
  ) <|> (do
    let (w, m) ← parseMemory
    pure (w, (.mem m))
  )

/-- TODO: this ought to be able to parse more in the ConstExpr category, just
  like many of the other functions above -/
def parseShiftExpr: Parser ShiftCountExpr := do
  skipHWs
  (do
    let i ← parseInt64
    pure (.imm8 i))
  <|> (do
    let _ ← pstring "%cl"
    pure .cl)


-- ============================================================================
-- Condition Code Parsing
-- ============================================================================

/-- Parse a condition code from a string slice, returning `none` if not recognized. -/
def parseCondCode? (suffix : String.Slice) : Option CondCode :=
  match suffix.copy.toLower with
  | "o" => some .o
  | "no" => some .no
  | "b" | "c" | "nae" => some .b
  | "ae" | "nc" | "nb" => some .ae
  | "z" | "e" => some .z
  | "nz" | "ne" => some .nz
  | "be" | "na" => some .be
  | "a" | "nbe" => some .a
  | "s" => some .s
  | "ns" => some .ns
  | "p" | "pe" => some .p
  | "np" | "po" => some .np
  | "l" | "nge" => some .l
  | "ge" | "nl" => some .ge
  | "le" | "ng" => some .le
  | "g" | "nle" => some .g
  | _ => none

/-- Parse a condition code from a conditional jump mnemonic suffix. -/
def parseCondCode (suffix : String.Slice) : Parser CondCode :=
  match parseCondCode? suffix with
  | some cc => .pure cc
  | none => .fail s!"unknown condition code: {suffix}"

-- ============================================================================
-- Instruction Parsing
-- ============================================================================

/-- Helper to construct an Instr from an Operation, defaulting address size to .W64 -/
def toInstr (addr : MaybeAddrWidth) {w : Width} (op : Operation w) : Instr :=
  let _ : AddressSize := { address_size := addr.getD .W64 }
  ↑op

/-- Helper to construct an Instr from an AvxOperation, defaulting address size to .W64 -/
def toAvxInstr (addr : MaybeAddrWidth) {w : AvxWidth} (op : AvxOperation w) : Instr :=
  let _ : AddressSize := { address_size := addr.getD .W64 }
  ↑op

/-- Parse a comma separator. -/
def parseComma : Parser Unit := do
  skipHWs
  let _ ← pchar ','
  skipHWs

/-- Try to parse a shift count followed by a comma; if that fails, default to 1. -/
def parseOptionalShiftAndComma : Parser ShiftCountExpr :=
  (attempt do let cnt ← parseShiftExpr; parseComma; pure cnt) <|> pure (.imm8 (.int64 1))

def parseReg : Parser (MaybeOpWidth Reg) := do
  let p ← parseRegW; pure ⟨ .some p.1, p.2 ⟩

def parseRegO := parseO parseReg

-- For compatibility with commaSeparated -- registers can never provide an
-- inference hint about instruction address width.
def parseRegA : Parser (MaybeAddrWidth × MaybeOpWidth Reg) := do
  let p ← parseRegW; pure (.none, ⟨ .some p.1, p.2 ⟩)

def parseOperandAO := parseAO parseOperand
def parseRegOrMemAO := parseAO parseRegOrMem

-- TODO: why is the dot notation not working here?
def Char.toWidth? (c: Char): Option Width :=
  match c with
  | 'b' => some .W8
  | 'w' => some .W16
  | 'l' => some .W32
  | 'q' => some .W64
  | _ => none

def Char.toWidth (c: Char): Parser Width :=
  match Char.toWidth? c with
  | some w => pure w
  | none => fail "impossible: unknown suffix"

def instrWidth (s: String): Parser Width :=
  match s.back? with
  | .none => fail "impossible: empty instruction"
  | .some c => Char.toWidth c

/-- Strip a width suffix ('b', 'w', 'l', 'q') from `mn` if present. -/
def splitWidthSuffix (mn : String) : String × Option Width :=
  match mn.back?.bind Char.toWidth? with
  | some w => ((mn.dropEnd 1).copy, some w)
  | none => (mn, none)

def commaSeparated {T1 T2} (op_w: Option Width) (p1: Parser (MaybeAddrWidth × MaybeOpWidth T1)) (p2: Parser (MaybeAddrWidth × MaybeOpWidth T2))
  (mk: {op_w: Width} → T2 op_w → T1 op_w → Operation op_w): Parser Instr := do
    match op_w with
    | .none =>
      let src ← p1; parseComma
      let (addr_w, ⟨ _w, src, dst ⟩) ← ascribeOrInfer src p2
      pure (toInstr addr_w (mk dst src))
    | .some w =>
      let (addr_w1, src) ← parseAO p1 w
      parseComma
      let (addr_w2, dst) ← parseAO p2 w
      let addr_w ← mergeAddrWidths addr_w1 addr_w2
      pure (toInstr addr_w (mk dst src))

def commaSeparatedAvx {T1 T2} (op_w: Option AvxWidth) (p1: Parser (MaybeAddrWidth × MaybeAvxOpWidth T1)) (p2: Parser (MaybeAddrWidth × MaybeAvxOpWidth T2))
  (mk: {op_w: AvxWidth} → T2 op_w → T1 op_w → AvxOperation op_w): Parser Instr := do
  match op_w with
  | .none =>
    let src ← p1; parseComma
    let (addr_w, ⟨ _w, src, dst ⟩) ← ascribeOrInferAvx src p2
    pure (toAvxInstr addr_w (mk dst src))
  | .some w =>
    let (addr_w1, src) ← parseAvxAO p1 w
    parseComma
    let (addr_w2, dst) ← parseAvxAO p2 w
    let addr_w ← mergeAddrWidths addr_w1 addr_w2
    pure (toAvxInstr addr_w (mk dst src))

def assertW {T} (v: MaybeOpWidth T): Parser (Σ w: Width, T w) :=
  match v with
  | ⟨ .none, _ ⟩ => fail "missing type annotation"
  | ⟨ .some w, T ⟩ => pure ⟨ w, T ⟩

def Option.toParser {T} (self: Option T): Parser T :=
  match self with
  | .some v => pure v
  | .none => fail "empty option"

instance {T} : Coe (Option T) (Parser T) where coe := Option.toParser

def parseBinaryRegOrMem (op_w : Option Width) : Parser (MaybeAddrWidth × Σ w, RegOrMem w × RegOrMem w) := do
  match op_w with
  | some w =>
    let (addr_w1, a) ← parseAO parseRegOrMem w
    parseComma
    let (addr_w2, b) ← parseAO parseRegOrMem w
    let addr_w ← mergeAddrWidths addr_w1 addr_w2
    pure (addr_w, ⟨w, a, b⟩)
  | none =>
    let a ← parseRegOrMem; parseComma
    ascribeOrInfer a parseRegOrMem

def parseUnaryRegOrMem (op_w : Option Width) : Parser (MaybeAddrWidth × Σ w, RegOrMem w) := do
  match op_w with
  | some w =>
    let (addr_w, src) ← parseRegOrMemAO w
    pure (addr_w, ⟨w, src⟩)
  | none =>
    let (addr_w, src) ← parseRegOrMem
    let ⟨w, src⟩ ← assertW src
    pure (addr_w, ⟨w, src⟩)

def parseXchg (op_w : Option Width) : Parser Instr := do
  let (addr_w, ⟨_w, a, b⟩) ← parseBinaryRegOrMem op_w
  match a, b with
  | .reg r, dst => pure (toInstr addr_w (.xchg dst r))
  | dst, .reg r => pure (toInstr addr_w (.xchg dst r))
  | .mem _, .mem _ => fail "xchg cannot have two memory operands"

def parseMovbe (op_w : Option Width) : Parser Instr := do
  let (addr_w, ⟨w, a, b⟩) ← parseBinaryRegOrMem op_w
  if w == .W8 then fail "movbe requires 16-, 32-, or 64-bit operand"
  match a, b with
  | .mem a, .reg r => pure (toInstr addr_w (.movbe (.reg r) (.mem a)))
  | .reg r, .mem a => pure (toInstr addr_w (.movbe (.mem a) (.reg r)))
  | _, _ => fail "movbe requires one register and one memory operand"

/-- If `mn` names a string operation (e.g. `movsb`, `cmpsl`), return the instruction. -/
def stringOp? (mn : String) (repPfx : RepPrefix := .none) : Option Instr := do
  guard (mn.length == 5)
  let w ← match mn.back with
    | 'b' => some Width.W8 | 'w' => some .W16 | 'l' | 'd' => some .W32 | 'q' => some .W64
    | _ => none
  let op : {w : Width} → Operation w ← match (mn.take 4).copy with
    | "movs" => some (.movs repPfx)
    | "stos" => some (.stos repPfx)
    | "lods" => some (.lods repPfx)
    | "cmps" => some (.cmps repPfx)
    | "scas" => some (.scas repPfx)
    | _ => none
  pure (toInstr .none (w := w) op)

/-- The 24 VEX comparison pseudo-op predicates 8-31 (SDM Table 3-4). -/
def vexCmpPred8To31? : String → Option Nat
  | "eq_uq" => some 8
  | "nge" => some 9
  | "ngt" => some 10
  | "false" => some 11
  | "neq_oq" => some 12
  | "ge" => some 13
  | "gt" => some 14
  | "true" => some 15
  | "eq_os" => some 16
  | "lt_oq" => some 17
  | "le_oq" => some 18
  | "unord_s" => some 19
  | "neq_us" => some 20
  | "nlt_uq" => some 21
  | "nle_uq" => some 22
  | "ord_s" => some 23
  | "eq_us" => some 24
  | "nge_uq" => some 25
  | "ngt_uq" => some 26
  | "false_os" => some 27
  | "neq_os" => some 28
  | "ge_oq" => some 29
  | "gt_oq" => some 30
  | "true_us" => some 31
  | _ => none

/-- Matches `vcmp{pred}{type}` for predicates 8-31 and types `ps`, `pd`, `ss`, `sd`. -/
def parseVexCmpPseudo? (mn : String) : Option (SimdBinImmOp × Nat × Bool) := do
  guard (mn.startsWith "vcmp")
  let rest := (mn.drop 4).copy
  let (op, isScalar) ←
    if rest.endsWith "ps" then some (.cmpps, false)
    else if rest.endsWith "pd" then some (.cmppd, false)
    else if rest.endsWith "ss" then some (.cmpss, true)
    else if rest.endsWith "sd" then some (.cmpsd, true)
    else none
  let predStr := (rest.dropEnd 2).copy
  let code ← vexCmpPred8To31? predStr
  some (op, code, isScalar)

/-- The family opcode named `mn`, or named `mn` without a width suffix, together with that width. -/
def lookupSized (α) [Mnemonic α] (mn : String) : Option (α × Option Width) :=
  (Mnemonic.ofName? mn).map (·, none) <|> do
    let (stem, some w) := splitWidthSuffix mn | none
    return (← Mnemonic.ofName? stem, some w)

/-- Checks an operand's width against a mnemonic's width suffix. -/
def checkSuffix (w? : Option Width) (w : Width) : Parser Unit :=
  if w?.all (· == w) then pure () else fail "operand width contradicts suffix"

/-- `src, %dst` with AVX operands. -/
def parseAvxSrcDst : Parser (MaybeAddrWidth × Σ w, AvxRegOrMem w × AvxReg w) := do
  let (addr_w, src) ← parseAvxRegOrMem; parseComma
  let ⟨w, dst⟩ ← parseAvxRegW
  pure (addr_w, ⟨w, ← ascribeAvx w src, dst⟩)

/-- `src, %dst` where the source has `memBytes? dst.bytes` bytes if that is `some`; a register
source is then named at 128 bits (`%xmm`) whatever the destination width. -/
def parseAvxNarrowSrcDst (memBytes? : Nat → Option Nat) :
    Parser (MaybeAddrWidth × Σ w, AvxRegOrMem w × AvxReg w) := do
  let (addr_w, src) ← parseAvxRegOrMem; parseComma
  let ⟨w, dst⟩ ← parseAvxRegW
  match src, memBytes? w.bytes with
  | ⟨some .W128, .avx r⟩, some _ => pure (addr_w, ⟨w, .avx (r.as w), dst⟩)
  | ⟨some _, _⟩, some _ => fail "expected an xmm register or memory"
  | _, _ => pure (addr_w, ⟨w, ← ascribeAvx w src, dst⟩)

/-- `src2, %src1, %dst` with AVX operands. -/
def parseAvxSrc2Src1Dst : Parser (MaybeAddrWidth × Σ w, AvxRegOrMem w × AvxReg w × AvxReg w) := do
  let (addr_w, src2) ← parseAvxRegOrMem; parseComma
  let ⟨w, src1⟩ ← parseAvxRegW; parseComma
  let dst ← parseAvxRegW
  if h : dst.w = w then pure (addr_w, ⟨w, ← ascribeAvx w src2, src1, h ▸ dst.reg⟩)
  else fail "AVX operand widths differ"

/-- `$imm,` -/
def parseImmComma : Parser ConstExpr := do
  skipHWs; let i ← parseInt64; parseComma; pure i

/-- `$imm,` or `src,` where `src` is an xmm register or memory. -/
def parseSimdCount : Parser (MaybeAddrWidth × SimdCount) :=
  (attempt do pure (none, .imm (← parseImmComma))) <|> do
    let (addr_w, src) ← parseAvxRegOrMem; parseComma
    pure (addr_w, .reg (← ascribeAvx .W128 src))

/-- Optional `$imm,` for extract/insert operations. -/
def parseOptImmComma (hasImm : Bool) : Parser (Option ConstExpr) :=
  if hasImm then some <$> parseImmComma else pure none

/-- The parsers for the operands of the family opcodes (see Kraken/X64/Ops) named `mn`. A mnemonic
may belong to several families with different operand shapes. -/
def familyParsers (mn : String) : Array (Parser Instr) := Id.run do
  -- The base name of a `v` form.
  let v := if mn.startsWith "v" then (mn.drop 1).copy else ""
  let mut ps := #[]
  if let some op := Mnemonic.ofName? (α := HintOp) mn then ps := ps.push do
    pure (toInstr .none (w := .W64) (.hint op))
  if let some op := Mnemonic.ofName? (α := MemHintOp) mn then ps := ps.push do
    let (addr_w, a) ← parseMemory
    pure (toInstr (some addr_w) (w := .W64) (.memHint op a))
  if let some (op, w?) := lookupSized GprUnOp mn then ps := ps.push do
    let (addr_w, src) ← parseRegOrMem; parseComma
    let ⟨w, dst⟩ ← parseRegW; checkSuffix w? w
    if w.bits < op.minBits then fail s!"{mn}: expected at least {op.minBits}-bit operands"
    pure (toInstr addr_w (.un op dst (← ascribe w src)))
  if let some (op, w?) := lookupSized GprBinOp mn then ps := ps.push do
    let (addr_w1, a) ← parseRegOrMem; parseComma
    let (addr_w2, b) ← parseRegOrMem; parseComma
    let addr_w ← mergeAddrWidths addr_w1 addr_w2
    let ⟨w, dst⟩ ← parseRegW; checkSuffix w? w
    if w matches .W8 | .W16 then fail s!"{mn}: expected 32- or 64-bit operands"
    let (src1, src2) := if op.src2First then (b, a) else (a, b)
    match ← ascribe w src1 with
    | .reg src1 => pure (toInstr addr_w (.bin op dst src1 (← ascribe w src2)))
    | .mem _ => fail s!"{mn}: expected a register"
  if let some (op, w?) := lookupSized BitTestOp mn then ps := ps.push do
    if w? == some .W8 then fail s!"{mn}: expected 16-, 32-, or 64-bit operands"
    let instr ← commaSeparated w? parseOperand parseRegOrMem (.bt op)
    if instr.width? == some .W8 then fail s!"{mn}: expected 16-, 32-, or 64-bit operands"
    pure instr
  if let some op := Mnemonic.ofName? (α := SimdMov) mn then ps := ps.push do
    commaSeparatedAvx (some .W128) parseAvxRegOrMem parseAvxRegOrMem (.mov op)
  if let some op := Mnemonic.ofName? (α := SimdMov) v then ps := ps.push do
    commaSeparatedAvx .none parseAvxRegOrMem parseAvxRegOrMem (.vmov op)
  if let some op := Mnemonic.ofName? (α := SimdBinOp) mn then ps := ps.push do
    let (addr_w, ⟨w, src, dst⟩) ← parseAvxSrcDst
    if w != .W128 then fail s!"{mn}: expected 128-bit operands"
    pure (toAvxInstr addr_w (.sse op dst src))
  if let some op := Mnemonic.ofName? (α := SimdBinOp) v then ps := ps.push do
    if let .crypto cop := op then
      if !cop.hasVex then fail s!"v{v} is not a valid instruction"
    let (addr_w, ⟨w, src2, src1, dst⟩) ← parseAvxSrc2Src1Dst
    if op.memBytes?.isSome && w != .W128 then fail s!"v{v}: scalar op requires 128-bit operands"
    if let .perm pop := op then
      if (pop == .permd || pop == .permps) && w != .W256 then fail s!"v{v}: requires 256-bit operands"
    pure (toAvxInstr addr_w (.vex op dst src1 src2))
  for (vex, name) in [(false, mn), (true, v)] do
    if let some op := Mnemonic.ofName? (α := SimdUnOp) name then ps := ps.push do
      if op.isNarrowing then
        if !vex then
          -- Legacy SSE: e.g. cvtpd2ps (%rax), %xmm0 or cvtpd2ps %xmm1, %xmm0
          let (addr_w, src) ← parseAvxRegOrMem; parseComma
          let dst ← parseAvxRegW
          match dst with
          | ⟨.W128, .xmm mm⟩ =>
            let srcAscribed ← ascribeAvx .W128 src
            pure (toAvxInstr addr_w (.sseUn op (.xmm mm) srcAscribed))
          | _ => fail s!"{name}: expected xmm destination"
        else
          -- VEX unsuffixed: vcvtpd2ps %xmm1, %xmm0 or vcvtpd2ps %ymm1, %xmm0.
          -- Memory operands require x or y suffix!
          let (addr_w, src) ← parseAvxRegOrMem; parseComma
          let dst ← parseAvxRegW
          match dst with
          | ⟨.W128, .xmm mm⟩ =>
            match src with
            | ⟨some .W128, .avx (.xmm r)⟩ =>
              pure (toAvxInstr addr_w (.vexUn op (.xmm mm) (.avx (.xmm r))))
            | ⟨some .W256, .avx (.ymm r)⟩ =>
              pure (toAvxInstr addr_w (.vexUn op (.ymm mm) (.avx (.ymm r))))
            | ⟨none, _⟩ =>
              fail s!"{name}: memory operand requires x or y suffix"
            | _ => fail s!"{name}: invalid operand"
          | _ => fail s!"{name}: expected xmm destination"
      else
        let (addr_w, ⟨w, src, dst⟩) ← parseAvxNarrowSrcDst op.memBytes?
        if !vex then
          if w != .W128 then fail s!"{name}: expected 128-bit operands"
          if op matches .cvtph2ps | .broadcastss | .broadcastsd | .broadcasti128 | .broadcastf128 then
            fail s!"{name}: VEX-only instruction"
        else
          if (op matches .broadcastsd | .broadcasti128 | .broadcastf128) && w != .W256 then
            fail s!"{name}: requires 256-bit operands"
          if (op matches .phminposuw | .aesimc | .movq | .movd) && w != .W128 then
            fail s!"{name}: requires 128-bit operands"
        pure (toAvxInstr addr_w (if vex then .vexUn op dst src else .sseUn op dst src))
  -- VEX narrowing ops with memory suffix: e.g. vcvtpd2psx, vcvtpd2psy
  if mn.startsWith "v" && (mn.endsWith "x" || mn.endsWith "y") then
    let stem := (mn.drop 1).dropEnd 1 |>.copy
    if let some op := Mnemonic.ofName? (α := SimdUnOp) stem then
      if op.isNarrowing then ps := ps.push do
        let w : AvxWidth := if mn.endsWith "x" then .W128 else .W256
        let (addr_w, m) ← parseMemory; parseComma
        let dst ← parseAvxRegW
        match dst with
        | ⟨.W128, .xmm mm⟩ =>
          match w with
          | .W128 => pure (toAvxInstr (some addr_w) (.vexUn op (.xmm mm) (.mem m)))
          | .W256 => pure (toAvxInstr (some addr_w) (.vexUn op (.ymm mm) (.mem m)))
          | .W512 => pure (toAvxInstr (some addr_w) (.vexUn op (.zmm mm) (.mem m)))
        | _ => fail s!"{mn}: expected xmm destination"
  for (vex, name) in [(false, mn), (true, v)] do
    if let some op := Mnemonic.ofName? (α := SimdUnImmOp) name then ps := ps.push do
      let imm ← parseImmComma
      let (addr_w, ⟨w, src, dst⟩) ← parseAvxSrcDst
      if !vex && w != .W128 then fail s!"{name}: expected 128-bit operands"
      if vex && name == "aeskeygenassist" && w != .W128 then fail s!"{name}: expected 128-bit operands"
      if vex && (name == "permq" || name == "permpd") && w != .W256 then fail s!"{name}: expected 256-bit operands"
      pure (toAvxInstr addr_w (if vex then .vexUnImm op dst src imm else .sseUnImm op dst src imm))
  if let some op := Mnemonic.ofName? (α := SimdBinImmOp) mn then ps := ps.push do
    let imm ← parseImmComma
    let (addr_w, ⟨w, src, dst⟩) ← parseAvxSrcDst
    if w != .W128 then fail s!"{mn}: expected 128-bit operands"
    pure (toAvxInstr addr_w (.sseImm op dst src imm))
  if let some op := Mnemonic.ofName? (α := SimdBinImmOp) v then ps := ps.push do
    if v == "sha1rnds4" then fail "vsha1rnds4 is not a valid instruction"
    let imm ← parseImmComma
    let (addr_w, ⟨w, src2, src1, dst⟩) ← parseAvxSrc2Src1Dst
    if (v == "roundss" || v == "roundsd" || v == "cmpss" || v == "cmpsd" || v == "insertps" || v == "dppd") && w != .W128 then
      fail s!"v{v}: expected 128-bit operands"
    if (v == "perm2f128" || v == "perm2i128") && w != .W256 then
      fail s!"v{v}: expected 256-bit operands"
    pure (toAvxInstr addr_w (.vexImm op dst src1 src2 imm))
  if let some (op, code, isScalar) := parseVexCmpPseudo? mn then ps := ps.push do
    let (addr_w, ⟨w, src2, src1, dst⟩) ← parseAvxSrc2Src1Dst
    if isScalar && w != .W128 then fail s!"{mn}: expected 128-bit operands"
    pure (toAvxInstr addr_w (.vexImm op dst src1 src2 (.int64 (Int64.ofNat code))))
  if let some op := Mnemonic.ofName? (α := SimdShiftOp) mn then ps := ps.push do
    let (addr_w, count) ← parseSimdCount
    let ⟨w, dst⟩ ← parseAvxRegW
    if w != .W128 then fail s!"{mn}: expected 128-bit operands"
    pure (toAvxInstr addr_w (.sseShift op dst count))
  if let some op := Mnemonic.ofName? (α := SimdShiftOp) v then ps := ps.push do
    let (addr_w, count) ← parseSimdCount
    let ⟨w, src⟩ ← parseAvxRegW; parseComma
    let dst ← parseAvxRegW
    if h : dst.w = w then pure (toAvxInstr addr_w (.vexShift op (h ▸ dst.reg) src count))
    else fail "AVX operand widths differ"
  for (vex, name) in [(false, mn), (true, v)] do
    if let some op := Mnemonic.ofName? (α := SimdTestOp) name then ps := ps.push do
      let (addr_w, ⟨w, src2, src1⟩) ← parseAvxSrcDst
      if !vex && w != .W128 then fail s!"{name}: expected 128-bit operands"
      if vex && op.memBytes?.isSome && w != .W128 then fail s!"{name}: expected 128-bit operands"
      pure (toAvxInstr addr_w (if vex then .vexTest op src1 src2 else .sseTest op src1 src2))
  if let some op := Mnemonic.ofName? (α := SimdBlendvOp) mn then ps := ps.push do
    let _ ← (attempt do skipHWs; let _ ← pstring "%xmm0"; parseComma) <|> pure ()
    let (addr_w, ⟨w, src, dst⟩) ← parseAvxSrcDst
    if w != .W128 then fail s!"{mn}: expected 128-bit operands"
    pure (toAvxInstr addr_w (.sseBlendv op dst src))
  if let some op := Mnemonic.ofName? (α := SimdBlendvOp) v then ps := ps.push do
    if !op.hasVex then fail s!"v{v} is not a valid instruction"
    let ⟨w, mask⟩ ← parseAvxRegW; parseComma
    let (addr_w, ⟨w', src2, src1, dst⟩) ← parseAvxSrc2Src1Dst
    if h : w = w' then pure (toAvxInstr addr_w (.vexBlendv op dst src1 src2 (h ▸ mask)))
    else fail "AVX operand widths differ"
  if let some op := Mnemonic.ofName? (α := SimdFmaOp) v then ps := ps.push do
    let (addr_w, ⟨w, src3, src2, dst⟩) ← parseAvxSrc2Src1Dst
    if op.scalar && w != .W128 then fail s!"{mn}: scalar FMA requires 128-bit operands"
    pure (toAvxInstr addr_w (.fma op dst src2 src3))
  if let some op := Mnemonic.ofName? (α := SimdScalarMov) mn then ps := ps.push do
    commaSeparatedAvx (some .W128) parseAvxRegOrMem parseAvxRegOrMem (.sseMovs op)
  if let some op := Mnemonic.ofName? (α := SimdScalarMov) v then ps := ps.push do
    let (addr_w1, op1) ← parseAvxAO parseAvxRegOrMem .W128; parseComma
    match op1 with
    | .mem _ =>
      let (addr_w2, dst) ← parseAvxAO parseAvxRegOrMem .W128
      let addr_w ← mergeAddrWidths addr_w1 addr_w2
      pure (toAvxInstr addr_w (.vexMovs op dst op1))
    | .avx src2 =>
      let (addr_w2, op2) ← parseAvxAO parseAvxRegOrMem .W128
      match op2 with
      | .mem _ =>
        let addr_w ← mergeAddrWidths addr_w1 addr_w2
        pure (toAvxInstr addr_w (.vexMovs op op2 op1))
      | .avx src1 =>
        parseComma
        let ⟨w, dst⟩ ← parseAvxRegW
        if h : w = .W128 then pure (toAvxInstr .none (.vexScalar op (h ▸ dst) src1 src2))
        else fail "scalar destination must be xmm"
  if let some op := Mnemonic.ofName? (α := SimdExtract128Op) v then ps := ps.push do
    let imm ← parseImmComma
    let ⟨w, src⟩ ← parseAvxRegW; parseComma
    if h : w = .W256 then
      let (addr_w, dst) ← parseAvxRegOrMem
      pure (toAvxInstr addr_w (.vextract op (← ascribeAvx .W128 dst) (h ▸ src) imm))
    else fail "vextract requires ymm source"
  if let some op := Mnemonic.ofName? (α := SimdInsert128Op) v then ps := ps.push do
    let imm ← parseImmComma
    let (addr_w, src2) ← parseAvxRegOrMem; parseComma
    let ⟨w1, src1⟩ ← parseAvxRegW; parseComma
    let dst ← parseAvxRegW
    if h1 : w1 = .W256 then
      if h2 : dst.w = .W256 then
        pure (toAvxInstr addr_w (.vinsert op (h2 ▸ dst.reg) (h1 ▸ src1) (← ascribeAvx .W128 src2) imm))
      else fail "vinsert destination must be ymm"
    else fail "vinsert source must be ymm"
  if v == "cvtps2ph" then ps := ps.push do
    let imm ← parseImmComma
    let ⟨w, src⟩ ← parseAvxRegW; parseComma
    let (addr_w, dst) ← parseAvxRegOrMem
    match w with
    | .W128 | .W256 => pure (toAvxInstr addr_w (.vcvtps2ph (← ascribeAvx .W128 dst) src imm))
    | _ => fail "vcvtps2ph requires xmm or ymm source"
  for (vex, name) in [(false, mn), (true, v)] do
    if let some (op, w?) := lookupSized SimdToGprOp name then ps := ps.push do
      let (addr_w, src) ← parseAvxRegOrMem; parseComma
      let ⟨w, dst⟩ ← parseRegW; checkSuffix w? w
      if !vex && src.1.any (· != .W128) then fail s!"{name}: expected 128-bit operand"
      let srcW := if !vex || op.memBytes?.isSome then .W128 else src.1.getD .W128
      let vsrc ← ascribeAvx srcW src
      pure (toAvxInstr addr_w (if vex then .vexToGpr op dst vsrc else .sseToGpr op dst vsrc))
  for (vex, name) in [(false, mn), (true, v)] do
    if let some op := Mnemonic.ofName? (α := SimdExtractOp) name then ps := ps.push do
      let imm ← parseOptImmComma op.hasImm
      let ⟨w, src⟩ ← parseAvxRegW; parseComma
      if w != .W128 then fail s!"{name}: expected xmm source"
      let (addr_w, dst) ← parseRegOrMem
      let w := dst.1.getD (.ofBits op.memBits)
      let d ← ascribe w dst
      pure (toAvxInstr addr_w (if vex then .vexExtract op d src imm else .sseExtract op d src imm))
  for (vex, name) in [(false, mn), (true, v)] do
    if let some (op, w?) := lookupSized SimdInsertOp name then ps := ps.push do
      if op.twoOperand then
        let (addr_w, src) ← parseRegOrMem
        if src.1.isNone then fail s!"{name} memory loads handled by SimdUnOp"
        parseComma
        let ⟨w, dst⟩ ← parseAvxRegW
        if w != .W128 then fail s!"{name}: expected xmm destination"
        let srcW := (w? <|> src.1).getD (.ofBits op.memBits)
        let ascribed ← ascribe srcW src
        pure (toAvxInstr addr_w (if vex then .vexInsert op dst dst ascribed none else .sseInsert op dst ascribed none))
      else if vex then
        let imm ← parseOptImmComma op.hasImm
        let (addr_w, src2) ← parseRegOrMem; parseComma
        let ⟨w, src1⟩ ← parseAvxRegW; parseComma
        let dst ← parseAvxRegW
        if w != .W128 then fail s!"{name}: expected xmm source"
        if h : dst.w = w then
          let srcW := (w? <|> src2.1).getD (.ofBits op.memBits)
          pure (toAvxInstr addr_w (.vexInsert op (h ▸ dst.reg) src1 (← ascribe srcW src2) imm))
        else fail "AVX operand widths differ"
      else
        let imm ← parseOptImmComma op.hasImm
        let (addr_w, src) ← parseRegOrMem; parseComma
        let ⟨w, dst⟩ ← parseAvxRegW
        if w != .W128 then fail s!"{name}: expected xmm destination"
        let srcW := (w? <|> src.1).getD (.ofBits op.memBits)
        pure (toAvxInstr addr_w (.sseInsert op dst (← ascribe srcW src) imm))
  return ps

/-- The parser for the operands of a family opcode named `mn`, if any: the first family whose
operand shape matches. -/
def parseFamily? (mn : String) : Option (Parser Instr) :=
  let ps := familyParsers mn
  ps.back?.map fun last => ps.pop.foldr (fun p acc => attempt p <|> acc) (attempt last)

/-- Parse the operands of the instructions not in a family, named `mn` (lowercase `mnemonic`).
    AT&T syntax: src, dst (reversed from Intel). -/
def parseExplicit (mnemonic mn : String) (rep : RepPrefix := .none) : Parser Instr := do
  if let some instr := stringOp? mn rep then
    return instr
  let (stem, w?) := splitWidthSuffix mn
  match stem, w? with
  | "div", w? =>
    let (addr_w, ⟨_w, src⟩) ← parseUnaryRegOrMem w?
    pure (toInstr addr_w (.div src))
  | "idiv", w? =>
    let (addr_w, ⟨_w, src⟩) ← parseUnaryRegOrMem w?
    pure (toInstr addr_w (.idiv src))
  | "xadd", w? =>
    commaSeparated w? parseRegA parseRegOrMem .xadd
  | "cmpxchg", w? =>
    commaSeparated w? parseRegA parseRegOrMem .cmpxchg
  | "xchg", w? =>
    parseXchg w?
  | "movbe", w? =>
    parseMovbe w?
  | "crc32", w? =>
    let (addr_w, src) ← parseRegOrMem; parseComma
    let ⟨dst_w, dst⟩ ← parseRegW
    let some w := w? <|> src.1 | fail "crc32 with a memory source needs a size suffix"
    let src ← ascribe w src
    if dst_w != .W32 && dst_w != .W64 then
      fail "crc32 destination must be r32 or r64"
    if dst_w == .W64 then
      if w != .W8 && w != .W64 then
        fail "crc32 with 64-bit destination requires 8-bit or 64-bit source"
      if let .reg r := src then
        if r.isHighByte then
          fail "cannot use high byte register with 64-bit destination in crc32"
    else -- dst_w == .W32
      if w != .W8 && w != .W16 && w != .W32 then
        fail "crc32 with 32-bit destination requires 8-, 16-, or 32-bit source"
    pure (toInstr addr_w (.crc32 dst src))
  | "rorx", w? =>
    let cnt ← parseImmComma
    let (addr_w, src) ← parseRegOrMem; parseComma
    let ⟨w, dst⟩ ← parseRegW
    checkSuffix w? w
    if w != .W32 && w != .W64 then fail "rorx requires 32-bit or 64-bit operand"
    let src ← ascribe w src
    pure (toInstr addr_w (.rorx dst src cnt))
  | _, _ =>
  -- Match on full mnemonic name (no suffix stripping)
  match mn with
  -- Arithmetic (two-operand: src, dst) - 64-bit
  | "add" =>
    commaSeparated .none parseOperand parseRegOrMem .add

  | "addq" | "addl" | "addw" | "addb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .add

  | "adc" =>
    commaSeparated .none parseOperand parseRegOrMem .adc

  | "adcq" | "adcl" | "adcw" | "adcb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .adc

  | "adcx" =>
    -- Per Intel SDM: ADCX dest must be a register (r32/r64)
    let instr ← commaSeparated .none parseRegOrMem parseRegA .adcx
    if instr.width? matches some .W8 | some .W16 then fail "adcx: expected 32- or 64-bit operands"
    pure instr

  | "adcxq" | "adcxl" =>
    let w ← instrWidth mn
    commaSeparated w parseRegOrMem parseRegA .adcx

  | "adox" =>
    -- Per Intel SDM: ADOX dest must be a register (r32/r64)
    let instr ← commaSeparated .none parseRegOrMem parseRegA .adox
    if instr.width? matches some .W8 | some .W16 then fail "adox: expected 32- or 64-bit operands"
    pure instr

  | "adoxq" | "adoxl" =>
    let w ← instrWidth mn
    commaSeparated w parseRegOrMem parseRegA .adox

  | "sub" =>
    commaSeparated .none parseOperand parseRegOrMem .sub

  | "subq" | "subl" | "subw" | "subb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .sub

  | "sbb" =>
    commaSeparated .none parseOperand parseRegOrMem .sbb

  | "sbbq" | "sbbl" | "sbbw" | "sbbb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .sbb

  | "mul" =>
    let ( addr_w, src) ← parseRegOrMem
    let ⟨ _w, src ⟩ ← assertW src
    pure (toInstr addr_w (.mul src))

  | "mulq" | "mull" | "mulw" | "mulb" =>
    let w ← instrWidth mn
    let ( addr_w, src ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.mul src))

  | "mulx" =>
    -- Per Intel SDM: MULX dest1 and dest2 must be registers
    -- mulxq src, lo, hi (AT&T: src → rdx*src, result in lo:hi)
    let ( addr_w, src ) ← parseRegOrMem; parseComma
    let lo ← parseRegW; parseComma
    let hi ← parseRegW
    match src, lo, hi with
    | ⟨ .none, src ⟩, ⟨ w1, lo ⟩, ⟨ w2, hi ⟩ =>
      if h: w1 = w2 then
        pure (toInstr addr_w (.mulx (h ▸ hi) lo src))
      else
        fail "mulx not homogenous"
    | ⟨ .some w3, src ⟩, ⟨ w1, lo ⟩, ⟨ w2, hi ⟩ =>
      if h: w1 = w2 then
        let hi := h ▸ hi
        if h: w1 = w3 then
          let src := h ▸ src
          pure (toInstr addr_w (.mulx hi lo src))
        else
          fail "mulx not homogenous"
      else
        fail "mulx not homogenous"

  | "mulxq" | "mulxl" =>
    let w ← instrWidth mn
    let ( addr_w, src ) ← parseRegOrMemAO w; parseComma
    let lo ← parseRegO w; parseComma
    let hi ← parseRegO w
    pure (toInstr addr_w (.mulx hi lo src))

  | "imul" =>
    (attempt do
      let src1 ← parseOperand; parseComma;
      (attempt do
        let src2 ← parseRegOrMem; parseComma
        let (addr_w2, ⟨ w, src2, dst ⟩) ← ascribeOrInfer src2 parseRegA
        let (addr_w1, src1) := src1
        let src1 ← ascribe w src1
        let addr_w ← mergeAddrWidths addr_w1 addr_w2
        pure (toInstr addr_w (.imul (.some dst) src2 src1)))
      <|> (do
        let (addr_w, ⟨_w, src1, src2 ⟩) ← ascribeOrInfer src1 parseRegOrMem
        pure (toInstr addr_w (.imul .none src2 src1))
      )
    ) <|> (do
      let (addr_w, src) ← parseRegOrMem
      let ⟨_w, src ⟩ ← assertW src
      pure (toInstr addr_w (.imul1 src))
    )

  | "imulq" | "imull" | "imulw" | "imulb" =>
    let w ← instrWidth mn
    (attempt do
      let (addr_w1, src1) ← parseOperandAO w; parseComma
      (attempt do
        let (addr_w2, src2) ← parseRegOrMemAO w; parseComma
        let dst ← parseRegO w
        let addr_w ← mergeAddrWidths addr_w1 addr_w2
        pure (toInstr addr_w (.imul (.some dst) src2 src1))
      ) <|>
      (do
        let (addr_w2, src2) ← parseRegOrMemAO w
        let addr_w ← mergeAddrWidths addr_w1 addr_w2
        pure (toInstr addr_w (.imul none src2 src1))
      )
    ) <|>
    (do
      let (addr_w, src) ← parseRegOrMemAO w
      pure (toInstr addr_w (.imul1 src))
    )
  | "cbtw" | "cbw" =>
    pure (toInstr .none (w := .W16) .cbw)

  | "cwtl" | "cwde" =>
    pure (toInstr .none (w := .W32) .cbw)

  | "cltq" | "cdqe" =>
    pure (toInstr .none (w := .W64) .cbw)

  | "cwtd" | "cwd" =>
    pure (toInstr .none (w := .W16) .cwd)

  | "cltd" | "cdq" =>
    pure (toInstr .none (w := .W32) .cwd)

  | "cqto" | "cqo" =>
    pure (toInstr .none (w := .W64) .cwd)
  | "neg" =>
    let ( addr_w, dst) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.neg dst))

  | "negq" | "negl" | "negw" | "negb" =>
    let w ← instrWidth mn
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.neg dst))

  | "dec" =>
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.dec dst))

  | "decq" | "decl" | "decw" | "decb" =>
    let w ← instrWidth mn
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.dec dst))

  | "inc" =>
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.inc dst))

  | "incq" | "incl" | "incw" | "incb" =>
    let w ← instrWidth mn
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.inc dst))

  | "mov" | "movabs" =>
    commaSeparated .none parseOperand parseRegOrMem .mov

  | "movq" | "movl" | "movw" | "movb"
  | "movabsq" | "movabsl" | "movabsw" | "movabsb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .mov

  | "movnti" | "movntil" | "movntiq" =>
    let w? := match mn with | "movntil" => some .W32 | "movntiq" => some .W64 | _ => none
    let ⟨w, src⟩ ← parseRegW; checkSuffix w? w; parseComma
    if w != .W32 && w != .W64 then fail "movnti requires 32-bit or 64-bit operand"
    let (addr_w, dst) ← parseMemory
    pure (toInstr (some addr_w) (w := w) (.movnti dst src))

  | "cmpxchg8b" =>
    let (addr_w, a) ← parseMemory
    pure (toInstr (some addr_w) (w := .W64) (.cmpxchg8b a))

  | "cmpxchg16b" =>
    let (addr_w, a) ← parseMemory
    pure (toInstr (some addr_w) (w := .W64) (.cmpxchg16b a))

  | "clc" => pure (toInstr .none (w := .W64) .clc)
  | "stc" => pure (toInstr .none (w := .W64) .stc)
  | "cmc" => pure (toInstr .none (w := .W64) .cmc)
  | "lahf" => pure (toInstr .none (w := .W64) .lahf)
  | "sahf" => pure (toInstr .none (w := .W64) .sahf)
  | "vzeroupper" => pure (toAvxInstr .none (w := .W256) .vzeroupper)
  | "vzeroall" => pure (toAvxInstr .none (w := .W256) .vzeroall)

  | "movsx" =>
    -- Must be a register otherwise lacking type info
    let ⟨ _w_src, src ⟩ ← parseRegW; parseComma
    let ⟨ _w_dst, dst ⟩ ← parseRegW
    pure (toInstr .none (.movsx (.reg dst) (.reg src)))

  | "movzx" =>
    -- Must be a register otherwise lacking type info
    let ⟨ _w_src, src ⟩ ← parseRegW; parseComma
    let ⟨ _w_dst, dst ⟩ ← parseRegW
    pure (toInstr .none (.movzx (.reg dst) (.reg src)))

  | "movslq" | "movsxd" =>
    let (addr_w, src) ← parseRegOrMemAO .W32; parseComma
    let dst ← parseRegO .W64
    pure (toInstr addr_w (.movsx (.reg dst) src))

  | "movsbw" | "movsbl" | "movsbq" | "movswl" | "movswq" =>
    let w_dst ← instrWidth mn
    let c_src ← String.Pos.Raw.get? mn (.mk (mn.length - 2))
    let w_src ← Char.toWidth c_src
    let (addr_w, src) ← parseRegOrMemAO w_src; parseComma
    let dst ← parseRegO w_dst
    pure (toInstr addr_w (.movsx (.reg dst) src))

  | "movzbw" | "movzbl" | "movzbq" | "movzwl" | "movzwq" =>
    let w_dst ← instrWidth mn
    let c_src ← String.Pos.Raw.get? mn (.mk (mn.length - 2))
    let w_src ← Char.toWidth c_src
    let (addr_w, src) ← parseRegOrMemAO w_src; parseComma
    let dst ← parseRegO w_dst
    pure (toInstr addr_w (.movzx (.reg dst) src))

  | "lea" =>
    let ( addr_w, src ) ← parseMemory; parseComma
    let ⟨ _w, dst ⟩ ← parseRegW
    pure (toInstr (some addr_w) (.lea dst src))

  | "leaq" | "leal" | "leaw" | "leab" =>
    let w2 ← instrWidth mn
    let ( addr_w, src ) ← parseMemory; parseComma
    let ⟨ w, dst ⟩ ← parseRegW
    if w2 ≠ w then
      fail "inconsistency in {mn}"
    else
      pure (toInstr (some addr_w) (.lea dst src))

  -- Bitwise - 64-bit
  | "xor" =>
    commaSeparated .none parseOperand parseRegOrMem .xor

  | "xorq" | "xorl" | "xorw" | "xorb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .xor

  | "and" =>
    commaSeparated .none parseOperand parseRegOrMem .and

  | "andq" | "andl" | "andw" | "andb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .and

  | "not" =>
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.not dst))

  | "notq" | "notl" | "notw" | "notb" =>
    let w ← instrWidth mn
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.not dst))

  | "or" =>
    commaSeparated .none parseOperand parseRegOrMem .or

  | "orq" | "orl" | "orw" | "orb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .or

  -- Compare - 64-bit
  | "cmp" => do
    commaSeparated .none parseOperand parseRegOrMem .cmp

  | "cmpq" | "cmpl" | "cmpw" | "cmpb" => do
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .cmp

  -- Test (sets flags based on AND without storing result)
  | "test" =>
    commaSeparated .none parseOperand parseRegOrMem .test

  | "testq" | "testl" | "testw" | "testb" =>
    let w ← instrWidth mn
    commaSeparated w parseOperand parseRegOrMem .test

  -- Shift instructions - 64-bit
  | "shl"
  | "sal" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.shl dst cnt))

  | "shlq" | "shll" | "shlw" | "shlb"
  | "salq" | "sall" | "salw" | "salb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.shl dst cnt))

  | "shr" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.shr dst cnt))

  | "shrq" | "shrl" | "shrw" | "shrb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.shr dst cnt))

  | "sar" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.sar dst cnt))

  | "sarq" | "sarl" | "sarw" | "sarb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.sar dst cnt))

  | "shld" =>
    let cnt ← parseShiftExpr; parseComma
    commaSeparated .none parseRegA parseRegOrMem (fun dst src => .shld dst src cnt)

  | "shldq" | "shldl" | "shldw" =>
    let w ← instrWidth mn
    let cnt ← parseShiftExpr; parseComma
    commaSeparated w parseRegA parseRegOrMem (fun dst src => .shld dst src cnt)

  | "shrd" =>
    let cnt ← parseShiftExpr; parseComma
    commaSeparated .none parseRegA parseRegOrMem (fun dst src => .shrd dst src cnt)

  | "shrdq" | "shrdl" | "shrdw" =>
    let w ← instrWidth mn
    let cnt ← parseShiftExpr; parseComma
    commaSeparated w parseRegA parseRegOrMem (fun dst src => .shrd dst src cnt)

  -- Rotate instructions - 64-bit
  | "rol" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.rol dst cnt))

  | "rolq" | "roll" | "rolw" | "rolb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.rol dst cnt))

  | "ror" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.ror dst cnt))

  | "rorq" | "rorl" | "rorw" | "rorb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.ror dst cnt))

  | "rcl" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.rcl dst cnt))

  | "rclq" | "rcll" | "rclw" | "rclb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.rcl dst cnt))

  | "rcr" =>
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMem
    let ⟨ _w, dst ⟩ ← assertW dst
    pure (toInstr addr_w (.rcr dst cnt))

  | "rcrq" | "rcrl" | "rcrw" | "rcrb" =>
    let w ← instrWidth mn
    let cnt ← parseOptionalShiftAndComma
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.rcr dst cnt))

  -- Byte swap
  | "bswap" =>
    let ⟨ w, dst ⟩ ← parseRegW
    if w matches .W8 | .W16 then fail "bswap requires 32- or 64-bit operand"
    pure (toInstr .none (.bswap dst))

  | "bswapq" | "bswapl" =>
    let ⟨ w, dst ⟩ ← parseRegW
    let w2 ← instrWidth mn
    if w2 ≠ w then
      fail "inconsistency in {mn}"
    else
      pure (toInstr .none (.bswap dst))
  -- Stack operations
  | "push" =>
    let ( addr_w, src ) ← parseOperand
    match src.1 with
    | some w =>
      if w != .W16 && w != .W64 then fail "push requires 16- or 64-bit operand"
      let s ← ascribe w src
      pure (toInstr addr_w (.push s))
    | none =>
      let s ← ascribe .W64 src
      match s with
      | .imm _ => pure (toInstr addr_w (.push s))
      | _ => fail "push memory operand requires size suffix"

  | "pushq" | "pushw" =>
    let w ← instrWidth mn
    let ( addr_w, src ) ← parseOperandAO w
    pure (toInstr addr_w (.push src))

  | "pop" =>
    let ( addr_w, dst) ← parseRegOrMem
    let ⟨ w, dst ⟩ ← assertW dst
    if w != .W16 && w != .W64 then fail "pop requires 16- or 64-bit operand"
    pure (toInstr addr_w (.pop dst))

  | "popq" | "popw" =>
    let w ← instrWidth mn
    let ( addr_w, dst ) ← parseRegOrMemAO w
    pure (toInstr addr_w (.pop dst))

  | "leave" | "leaveq" =>
    pure (toInstr .none (w := .W64) .leave)

  | "pushf" | "pushfq" =>
    pure (toInstr .none (w := .W64) .pushf)

  | "popf" | "popfq" =>
    pure (toInstr .none (w := .W64) .popf)

  | "cld" =>
    pure (toInstr .none (w := .W64) .cld)

  | "std" =>
    pure (toInstr .none (w := .W64) .std)
  | "ud2" =>
    pure (toInstr .none (w := .W64) .ud2)

  | "int3" =>
    pure (toInstr .none (w := .W64) .int3)

  | "hlt" =>
    pure (toInstr .none (w := .W64) .hlt)

  | "ret" | "retq" =>
    pure (toInstr .none (w := .W64) .ret)

  | "call" | "callq" =>
    let ( addr_w, target ) ← parseRelRegOrMem
    pure (toInstr addr_w (w := .W64) (.call target))

  -- Control flow - unconditional jump
  | "jmp" | "jmpq" =>
    let ( addr_w, target ) ← parseRelRegOrMem
    pure (toInstr addr_w (w := .W64) (.jmp target))

  | "nop" =>
    (do
      skipHWs
      let sz ← parseHexOrDec
      pure (toInstr .none (w := .W64) (.nop sz.toNat))
    ) <|> (pure (toInstr .none (w := .W64) (.nop 1)))

  | "nopw" | "nopl" | "nopq" =>
    let w ← instrWidth mn
    let (addr_w, src) ← parseRegOrMemAO w
    pure (toInstr addr_w (.nopm src))

  | "xlat" | "xlatb" =>
    (attempt do
      let (addr_w, _) ← parseMemory
      pure (toInstr (some addr_w) (w := .W8) .xlat)) <|>
      pure (toInstr .none (w := .W8) .xlat)

  | "jrcxz" | "jecxz" | "loop" | "loope" | "loopz" | "loopne" | "loopnz" =>
    skipHWs
    let target ← parseLabelRaw
    let op := match mn with
      | "jrcxz" => .jrcxz target
      | "jecxz" => .jecxz target
      | "loope" | "loopz" => .loop .e target
      | "loopne" | "loopnz" => .loop .ne target
      | _ => .loop .none target
    pure (toInstr .none (w := .W64) op)

  -- Control flow - conditional jumps
  | _ =>
    if mn.startsWith "j" then
      let cc ← parseCondCode (mn.drop 1)
      skipHWs
      let target ← parseLabelRaw
      pure (toInstr .none (w := .W64) (.jcc cc target))
    else if mn.startsWith "set" then
      let cc ← parseCondCode (mn.drop 3)
      let (addr_w, dst) ← parseRegOrMemAO .W8
      pure (toInstr addr_w (.setcc cc dst))
    else if mn.startsWith "cmov" then
      let rest := (mn.drop 4).copy
      -- First try parsing condition code directly (e.g. "l" for cmovl, "ge" for cmovge).
      -- If that fails or if a width suffix was given, strip the suffix ('w', 'l', 'q') and retry.
      let (cc, w?) ← match parseCondCode? rest with
        | some cc => pure (cc, none)
        | none =>
          match rest.back?.bind Char.toWidth? with
          | some w =>
            if w == .W8 then fail "cmovcc: 8-bit operands not supported"
            let cc ← parseCondCode (rest.dropEnd 1).copy
            pure (cc, some w)
          | none => fail s!"unknown cmov condition code: {rest}"
      let instr ← commaSeparated w? parseRegOrMem parseRegA (.cmovcc cc)
      if instr.width? == some .W8 then fail "cmovcc: 8-bit operands not supported"
      pure instr
    else
      fail s!"unsupported instruction: {mnemonic}"

/-- Check whether an instruction is valid with the `lock` prefix per Intel SDM:
destination must be a memory operand, and operation must be one of:
ADD, ADC, AND, BTC, BTR, BTS, CMPXCHG, CMPXCHG8B, CMPXCHG16B, DEC, INC, NEG, NOT, OR, SBB, SUB, XOR, XADD, XCHG. -/
def isLockable (instr : Instr) : Bool :=
  match instr with
  | .regular _ _ op =>
    match op with
    | .add (.mem _) _ | .adc (.mem _) _ | .and (.mem _) _ | .sub (.mem _) _ | .sbb (.mem _) _
    | .xor (.mem _) _ | .or (.mem _) _ | .not (.mem _) | .neg (.mem _) | .inc (.mem _) | .dec (.mem _)
    | .xadd (.mem _) _ | .cmpxchg (.mem _) _ | .xchg (.mem _) _
    | .cmpxchg8b _ | .cmpxchg16b _ => true
    | .bt op (.mem _) _ => op != .bt
    | _ => false
  | .avx .. => false

/-- Parse an instruction mnemonic and its operands. A mnemonic may name both an explicit
instruction and family opcodes (e.g. `movq`); the first whose operands parse wins. -/
def parseInstr : Parser Instr := do
  skipHWs
  let mut mnemonic ← parseName
  let mut hasLock := false
  -- The `lock` prefix doesn't change single-threaded semantics.
  if mnemonic.toLower == "lock" then
    hasLock := true
    skipHWs
    mnemonic ← parseName
  let rep := match mnemonic.toLower with
    | "rep" => .rep
    | "repe" | "repz" => .repe
    | "repne" | "repnz" => .repne
    | _ => .none
  if rep != .none then skipHWs; mnemonic ← parseName
  let mn := mnemonic.toLower
  if rep != .none && (stringOp? mn).isNone then
    fail "rep prefixes apply only to string instructions"
  let instr ← if rep != .none then
    parseExplicit mnemonic mn rep
  else
    match parseFamily? mn with
    | some p => attempt p <|> parseExplicit mnemonic mn rep
    | none => parseExplicit mnemonic mn rep
  if hasLock && !isLockable instr then
    fail "instruction cannot take lock prefix"
  return instr

-- ============================================================================
-- Label Parsing
-- ============================================================================

/-- Parse an optional label (name followed by colon).
    Uses attempt for proper backtracking if colon is not found. -/
def parseLabelDecl : Parser Label := do
  skipHWs
  (attempt do
    let name ← parseName
    skipHWs
    let _ ← pchar ':'
    pure name)

-- ============================================================================
-- Line and Program Parsing
-- ============================================================================

def parseAlign : Parser Instr := do
  let _ ← pstring ".align"
  skipHWs
  let alignment ← parseHexOrDec
  let pad ← (do
    skipHWs
    let _ ← parseComma
    skipHWs
    let pad ← parseHexOrDec
    pure (some pad.toNat)
  ) <|> pure none
  pure (toInstr .none (w := .W64) (.nopalign alignment.toNat pad))

def skipSpaceAndCheckLineEnd : Parser Bool := do
  skipHWs
  let c? ← peek?
  match c? with
  | none
  | some '\n' =>
    pure true
  | some '#' =>
    skipLineComment
    pure true
  | some _ =>
    pure false

def parseOptionalInstr : Parser (Option Directive) := do
  if (← skipSpaceAndCheckLineEnd) then
    pure none
  else
    let i ← parseAlign <|> parseInstr
    pure (some (Directive.instr i))

def checkLineEnd : Parser Unit := do
  if (← skipSpaceAndCheckLineEnd) then
    pure ()
  else
    fail "unexpected trailing characters on line"

/-- Parse a single line: optional label, followed by optional instruction or directive.
    Returns a list of directives found on the line. -/
def parseLine : Parser (List Directive) := do
  skipHWs
  let labels ← many (attempt do
    let l ← parseLabelDecl
    pure (Directive.label l))
  let instr ← parseOptionalInstr
  checkLineEnd
  let labelsList := labels.toList
  match instr with
  | some i => pure (labelsList ++ [i])
  | none   => pure labelsList

-- ============================================================================
-- Public API
-- ============================================================================

instance {T1} : Coe (ParseResult (List T1) (Sigma String.Pos)) (Except String (List T1)) where coe :=
  fun r => match r with
  | .success _ v => .ok v
  | .error _ .eof => .error "unexpected end of input"
  | .error _ (.other msg) => .error msg

public def parse (input: String) : Except String Program := do
  let rawLines := (input.splitOn "\n")
  let (_, lines) ← rawLines.foldlM (fun (lineNum, acc) x => do
    match (parseLine ⟨ x, x.startPos ⟩ : Except String (List Directive)) with
    | .ok v => pure (lineNum + 1, v :: acc)
    | .error msg => .error s!"line {lineNum}: {msg}"
  ) ((1 : Nat), [])
  pure lines.reverse.flatten

-- ============================================================================
-- Assembly Preprocessing (Directive Stripping)
-- ============================================================================
-- These delete code that is not presently handled by Kraken. This is useful
-- for running on code without needing to modify it to delete things we do not
-- model. These are used in file parsing.

private def directiveKeywords : List String :=
  ["file", "text", "data", "p2align", "balign",
   "globl", "global", "type", "size", "section",
   "weak", "hidden", "protected", "internal", "ident",
   "cfi_startproc", "cfi_endproc", "cfi_def_cfa",
   "cfi_offset", "cfi_adjust_cfa_offset", "cfi_def_cfa_offset",
   "cfi_def_cfa_register", "cfi_restore", "cfi_remember_state",
   "cfi_restore_state"]

private def extractDirectiveName (s : String) : String :=
  let rest := s.drop 1
  let nameStr := (rest.takeWhile (fun c => c != ' ' && c != '\t' && c != ',' && c != ':')).toString
  nameStr.toLower

private def keepLine (line : String) : Bool :=
  let stripped := (line.trimAsciiStart).toString
  if stripped.isEmpty || stripped.startsWith "#" then true
  else if !stripped.startsWith "." then true
  else
    let dirName := extractDirectiveName stripped
    if stripped.any (· == ':') then true
    else if directiveKeywords.contains dirName then false
    else false

public def stripDirectives (content : String) : String :=
  let lines := content.splitOn "\n"
  let kept := lines.filter keepLine
  "\n".intercalate kept

end Kraken.X64.Parser
