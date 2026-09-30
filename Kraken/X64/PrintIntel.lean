module

public import Kraken.X64.Syntax

public section
/-!
# IntelPrinter
This file prints Kraken-supported x64 assembly in Intel syntax.
This is different from Parser.lean which expects AT&T syntax.
-/

instance : ToString Reg64 where
  toString r := match r with
  | .rax => "rax" | .rbx => "rbx" | .rcx => "rcx" | .rdx => "rdx"
  | .rsi => "rsi" | .rdi => "rdi" | .rsp => "rsp" | .rbp => "rbp"
  | .r8  => "r8"  | .r9  => "r9"  | .r10 => "r10" | .r11 => "r11"
  | .r12 => "r12" | .r13 => "r13" | .r14 => "r14" | .r15 => "r15"

instance : ToString RegMm where
  toString r := match r with
  | .mm0  => "mm0"  | .mm1  => "mm1"  | .mm2  => "mm2"  | .mm3  => "mm3"
  | .mm4  => "mm4"  | .mm5  => "mm5"  | .mm6  => "mm6"  | .mm7  => "mm7"
  | .mm8  => "mm8"  | .mm9  => "mm9"  | .mm10 => "mm10" | .mm11 => "mm11"
  | .mm12 => "mm12" | .mm13 => "mm13" | .mm14 => "mm14" | .mm15 => "mm15"
  | .mm16 => "mm16" | .mm17 => "mm17" | .mm18 => "mm18" | .mm19 => "mm19"
  | .mm20 => "mm20" | .mm21 => "mm21" | .mm22 => "mm22" | .mm23 => "mm23"
  | .mm24 => "mm24" | .mm25 => "mm25" | .mm26 => "mm26" | .mm27 => "mm27"
  | .mm28 => "mm28" | .mm29 => "mm29" | .mm30 => "mm30" | .mm31 => "mm31"

def Reg.toStr {w} (r : Reg w) : String := match w, r with
  | .W64, .low r _ => toString r
  | .W32, .low r _ => match r with
    | .rax => "eax" | .rbx => "ebx" | .rcx => "ecx" | .rdx => "edx"
    | .rsi => "esi" | .rdi => "edi" | .rsp => "esp" | .rbp => "ebp"
    | .r8  => "r8d" | .r9  => "r9d" | .r10 => "r10d" | .r11 => "r11d"
    | .r12 => "r12d"| .r13 => "r13d"| .r14 => "r14d"| .r15 => "r15d"
  | .W16, .low r _ => match r with
    | .rax => "ax" | .rbx => "bx" | .rcx => "cx" | .rdx => "dx"
    | .rsi => "si" | .rdi => "di" | .rsp => "sp" | .rbp => "bp"
    | .r8  => "r8w" | .r9  => "r9w" | .r10 => "r10w" | .r11 => "r11w"
    | .r12 => "r12w"| .r13 => "r13w"| .r14 => "r14w"| .r15 => "r15w"
  | .W8, .low r _ => match r with
    | .rax => "al" | .rbx => "bl" | .rcx => "cl" | .rdx => "dl"
    | .rsi => "sil" | .rdi => "dil" | .rsp => "spl" | .rbp => "bpl"
    | .r8  => "r8b" | .r9  => "r9b" | .r10 => "r10b" | .r11 => "r11b"
    | .r12 => "r12b"| .r13 => "r13b"| .r14 => "r14b"| .r15 => "r15b"
  | .W8, .ah => "ah" | .W8, .bh => "bh" | .W8, .ch => "ch" | .W8, .dh => "dh"

instance {w} : ToString (Reg w) where toString := Reg.toStr

instance {w} : ToString (AvxReg w) where
  toString r := match r with
  | .xmm r => "x" ++ toString r
  | .ymm r => "y" ++ toString r
  | .zmm r => "z" ++ toString r

def RegOrRip.toStr (b : RegOrRip) (addr_w : Width := .W64) : String := match b with
  | .reg r => toString (Reg.low r addr_w)
  | .rip => "rip"
instance : ToString RegOrRip where toString b := b.toStr

def ConstExpr.toStr : ConstExpr → String
  | .label l => l
  | .int64 i => s!"{i}"
  | .before_current_instruction => "."
  | .after_current_instruction => "."
  | .add e1 e2 => s!"({e1.toStr} + {e2.toStr})"
  | .sub e1 e2 => s!"({e1.toStr} - {e2.toStr})"
instance : ToString ConstExpr where toString := ConstExpr.toStr

def optImm : Option ConstExpr → String
  | some i => s!", {i}"
  | none => ""

def AddrExpr.toStr (a : AddrExpr) (addr_w : Width := .W64) : String :=
  let dispStr := match a.base, a.disp with
    -- Unwrap RIP-relative displacements back to just the label for printing
    -- (like RelRegOrMem.toStr below)
    | .some .rip, .sub e .after_current_instruction => toString e
    | _, _ => toString a.disp
  "[" ++ "+".intercalate (
    (match a.base with | .some b => [b.toStr addr_w] | _ => [])
    ++ (match a.idx with | .some ⟨r, s⟩ => [s!"{Reg.low r addr_w}*{s.bytes}"] | _ => [])
    ++ [dispStr]
  ) ++ "]"

def Width.ptrName : Width → String
  | .W8 => "BYTE" | .W16 => "WORD" | .W32 => "DWORD" | .W64 => "QWORD"

def Width.strSuffix : Width → String
  | .W8 => "b" | .W16 => "w" | .W32 => "d" | .W64 => "q"

def RegOrMem.toStr {w} (rm : RegOrMem w) (addr_w : Width := .W64) : String := match rm with
  | .reg r => ToString.toString r
  | .mem a => s!"{w.ptrName} PTR {a.toStr addr_w}"
instance {w} : ToString (RegOrMem w) where toString rm := rm.toStr

def AvxRegOrMem.toStr {w} (rm : AvxRegOrMem w) (addr_w : Width := .W64) : String := match rm with
  | .avx r => ToString.toString r
  | .mem a => match w with
    | .W512 => "ZMMWORD PTR " ++ a.toStr addr_w
    | .W256 => "YMMWORD PTR " ++ a.toStr addr_w
    | .W128 => "XMMWORD PTR " ++ a.toStr addr_w
instance {w} : ToString (AvxRegOrMem w) where toString rm := rm.toStr

def Operand.toStr {w} (op : Operand w) (addr_w : Width := .W64) : String := match op with
  | .regOrMem rm => rm.toStr addr_w
  | .imm v => toString v
instance {w} : ToString (Operand w) where toString op := op.toStr

def RelRegOrMem.toStr (rel : RelRegOrMem) (addr_w : Width := .W64) : String := match rel with
  | .rel (.sub e .after_current_instruction) => toString e
  | .rel c => toString c
  | .reg r => toString r
  | .mem a => "QWORD PTR " ++ a.toStr addr_w
instance : ToString RelRegOrMem where toString rel := rel.toStr

instance : ToString CondCode where toString
  | .o => "o" | .no => "no" | .c => "b" | .nc => "ae" | .z => "e" | .nz => "ne" | .be => "be" | .a => "a"
  | .s => "s" | .ns => "ns" | .p => "p" | .np => "np" | .l => "l" | .ge => "ge" | .le => "le" | .g => "g"

instance : ToString ShiftCountExpr where toString
  | .cl => "cl"
  | .imm8 v => ToString.toString v

def Operation.toStr {w} (op : Operation w) (addr_w : Width := .W64) : String := match op with
  | .mov dst src => s!"mov {dst.toStr addr_w}, {src.toStr addr_w}"
  | .movsx dst src => s!"movsx {dst.toStr addr_w}, {src.toStr addr_w}"
  | .movzx dst src => s!"movzx {dst.toStr addr_w}, {src.toStr addr_w}"
  | .push src => s!"push {src.toStr addr_w}"
  | .pop dst => s!"pop {dst.toStr addr_w}"
  | .leave => "leave"
  | .pushf => "pushfq"
  | .popf => "popfq"
  | .setcc cc dst => s!"set{cc} {dst.toStr addr_w}"
  | .cmovcc cc dst src => s!"cmov{cc} {dst}, {src.toStr addr_w}"
  | .xchg dst src => s!"xchg {dst.toStr addr_w}, {src}"
  | .xadd dst src => s!"xadd {dst.toStr addr_w}, {src}"
  | .cmpxchg dst src => s!"cmpxchg {dst.toStr addr_w}, {src}"
  | .cmpxchg8b a => s!"cmpxchg8b {a.toStr addr_w}"
  | .cmpxchg16b a => s!"cmpxchg16b {a.toStr addr_w}"
  | .ud2 => "ud2"
  | .int3 => "int3"
  | .hlt => "hlt"
  | .clc => "clc"
  | .stc => "stc"
  | .cmc => "cmc"
  | .lahf => "lahf"
  | .sahf => "sahf"
  | .cld => "cld"
  | .std => "std"
  | .movs rep => s!"{rep.toStrPrefix}movs{w.strSuffix}"
  | .stos rep => s!"{rep.toStrPrefix}stos{w.strSuffix}"
  | .lods rep => s!"{rep.toStrPrefix}lods{w.strSuffix}"
  | .cmps rep => s!"{rep.toStrPrefix}cmps{w.strSuffix}"
  | .scas rep => s!"{rep.toStrPrefix}scas{w.strSuffix}"
  | .lea dst src => s!"lea {dst}, {src.toStr addr_w}"
  | .add dst src => s!"add {dst.toStr addr_w}, {src.toStr addr_w}"
  | .adc dst src => s!"adc {dst.toStr addr_w}, {src.toStr addr_w}"
  | .adcx dst src => s!"adcx {dst}, {src.toStr addr_w}"
  | .adox dst src => s!"adox {dst}, {src.toStr addr_w}"
  | .inc dst => s!"inc {dst.toStr addr_w}"
  | .dec dst => s!"dec {dst.toStr addr_w}"
  | .neg dst => s!"neg {dst.toStr addr_w}"
  | .sub dst src => s!"sub {dst.toStr addr_w}, {src.toStr addr_w}"
  | .sbb dst src => s!"sbb {dst.toStr addr_w}, {src.toStr addr_w}"
  | .cmp a b => s!"cmp {a.toStr addr_w}, {b.toStr addr_w}"
  | .mul src => s!"mul {src.toStr addr_w}"
  | .mulx hi lo src => s!"mulx {hi}, {lo}, {src.toStr addr_w}"
  | .imul none src1 src2 => s!"imul {src1.toStr addr_w}, {src2.toStr addr_w}"
  | .imul (some dst) src1 src2 => s!"imul {dst.toStr addr_w}, {src1.toStr addr_w}, {src2.toStr addr_w}"
  | .imul1 src => s!"imul {src.toStr addr_w}"
  | .div src => s!"div {src.toStr addr_w}"
  | .idiv src => s!"idiv {src.toStr addr_w}"
  | .cbw => match w with
    | .W8 | .W16 => "cbw"
    | .W32 => "cwde"
    | .W64 => "cdqe"
  | .cwd => match w with
    | .W8 | .W16 => "cwd"
    | .W32 => "cdq"
    | .W64 => "cqo"
  | .test a b => s!"test {a.toStr addr_w}, {b.toStr addr_w}"
  | .and dst src => s!"and {dst.toStr addr_w}, {src.toStr addr_w}"
  | .not dst => s!"not {dst.toStr addr_w}"
  | .or dst src => s!"or {dst.toStr addr_w}, {src.toStr addr_w}"
  | .xor dst src => s!"xor {dst.toStr addr_w}, {src.toStr addr_w}"
  | .shl dst cnt => s!"shl {dst.toStr addr_w}, {cnt}"
  | .shr dst cnt => s!"shr {dst.toStr addr_w}, {cnt}"
  | .sar dst cnt => s!"sar {dst.toStr addr_w}, {cnt}"
  | .shld dst src cnt => s!"shld {dst.toStr addr_w}, {src}, {cnt}"
  | .shrd dst src cnt => s!"shrd {dst.toStr addr_w}, {src}, {cnt}"
  | .rol dst cnt => s!"rol {dst.toStr addr_w}, {cnt}"
  | .ror dst cnt => s!"ror {dst.toStr addr_w}, {cnt}"
  | .rcl dst cnt => s!"rcl {dst.toStr addr_w}, {cnt}"
  | .rcr dst cnt => s!"rcr {dst.toStr addr_w}, {cnt}"
  | .bswap dst => s!"bswap {dst}"
  | .movbe dst src => s!"movbe {dst.toStr addr_w}, {src.toStr addr_w}"
  | .crc32 dst src => s!"crc32 {dst}, {src.toStr addr_w}"
  | .rorx dst src cnt => s!"rorx {dst}, {src.toStr addr_w}, {cnt}"
  | .un op dst src => s!"{Mnemonic.name op} {dst}, {src.toStr addr_w}"
  | .bin op dst src1 src2 =>
    if op.src2First then s!"{Mnemonic.name op} {dst}, {src1}, {src2.toStr addr_w}"
    else s!"{Mnemonic.name op} {dst}, {src2.toStr addr_w}, {src1}"
  | .bt op dst bit => s!"{Mnemonic.name op} {dst.toStr addr_w}, {bit.toStr addr_w}"
  | .jcc cc l => s!"j{cc} {l}"
  | .jrcxz l => s!"jrcxz {l}"
  | .jecxz l => s!"jecxz {l}"
  | .loop .none l => s!"loop {l}"
  | .loop .e l => s!"loope {l}"
  | .loop .ne l => s!"loopne {l}"
  | .jmp tgt => s!"jmp {tgt.toStr addr_w}"
  | .call tgt => s!"call {tgt.toStr addr_w}"
  | .ret => "ret"
  | .nop n => s!".nops {n}"
  | .nopalign a none => s!".align {a}"
  | .nopalign a (some p) => s!".align {a}, {p}"
  | .hint op => Mnemonic.name op
  | .nopm x => s!"nop {x.toStr addr_w}"
  | .memHint op a => s!"{Mnemonic.name op} BYTE PTR {a.toStr addr_w}"
  | .movnti dst src => s!"movnti {(RegOrMem.mem (w:=w) dst).toStr addr_w}, {src}"
  | .xlat => if addr_w == .W32 then "xlat BYTE PTR [ebx]" else "xlat BYTE PTR [rbx]"
instance {w} : ToString (Operation w) where toString op := op.toStr

def SimdCount.toStr (c : SimdCount) (addr_w : Width := .W64) : String := match c with
  | .imm v => toString v
  | .reg src => src.toStr addr_w

def AvxRegOrMem.toStrSimd {w} (memBytes? : Option Nat) (rm : AvxRegOrMem w) (addr_w : Width := .W64) : String :=
  match rm, memBytes? with
  | .avx r, some _ => ToString.toString (r.as .W128)
  | .avx r, none => ToString.toString r
  | .mem a, some 16 => "XMMWORD PTR " ++ a.toStr addr_w
  | .mem a, some n => s!"{(Width.ofBytes n).ptrName} PTR {a.toStr addr_w}"
  | .mem _, _ => rm.toStr addr_w

def AvxOperation.toStr {w} (op : AvxOperation w) (addr_w : Width := .W64) : String := match op with
  | .mov op dst src => s!"{Mnemonic.name op} {dst.toStr addr_w}, {src.toStr addr_w}"
  | .vmov op dst src => s!"v{Mnemonic.name op} {dst.toStr addr_w}, {src.toStr addr_w}"
  | .sse op dst src => s!"{Mnemonic.name op} {dst}, {src.toStrSimd op.memBytes? addr_w}"
  | .vex op dst src1 src2 => s!"v{Mnemonic.name op} {dst}, {src1}, {src2.toStrSimd op.memBytes? addr_w}"
  | .sseUn op dst src => s!"{Mnemonic.name op} {dst}, {src.toStrSimd (op.memBytes? w.bytes) addr_w}"
  | .vexUn op dst src => s!"v{Mnemonic.name op} {dst}, {src.toStrSimd (op.memBytes? w.bytes) addr_w}"
  | .sseUnImm op dst src imm =>
    s!"{Mnemonic.name op} {dst}, {src.toStr addr_w}, {imm}"
  | .sseImm op dst src imm =>
    s!"{Mnemonic.name op} {dst}, {src.toStrSimd op.memBytes? addr_w}, {imm}"
  | .vexUnImm op dst src imm => s!"v{Mnemonic.name op} {dst}, {src.toStr addr_w}, {imm}"
  | .vexImm op dst src1 src2 imm =>
    s!"v{Mnemonic.name op} {dst}, {src1}, {src2.toStrSimd op.memBytes? addr_w}, {imm}"
  | .sseShift op dst c => s!"{Mnemonic.name op} {dst}, {c.toStr addr_w}"
  | .vexShift op dst src c => s!"v{Mnemonic.name op} {dst}, {src}, {c.toStr addr_w}"
  | .sseTest op src1 src2 => s!"{Mnemonic.name op} {src1}, {src2.toStrSimd op.memBytes? addr_w}"
  | .vexTest op src1 src2 => s!"v{Mnemonic.name op} {src1}, {src2.toStrSimd op.memBytes? addr_w}"
  | .sseBlendv op dst src => s!"{Mnemonic.name op} {dst}, {src.toStr addr_w}, xmm0"
  | .vexBlendv op dst src1 src2 mask =>
    s!"v{Mnemonic.name op} {dst}, {src1}, {src2.toStr addr_w}, {mask}"
  | .fma op dst src2 src3 => s!"v{Mnemonic.name op} {dst}, {src2}, {src3.toStrSimd op.memBytes? addr_w}"
  | .vzeroupper => "vzeroupper"
  | .vzeroall => "vzeroall"
  | .sseMovs op dst src =>
    s!"{Mnemonic.name op} {dst.toStrSimd (some op.bytes) addr_w}, {src.toStrSimd (some op.bytes) addr_w}"
  | .vexMovs op dst src =>
    s!"v{Mnemonic.name op} {dst.toStrSimd (some op.bytes) addr_w}, {src.toStrSimd (some op.bytes) addr_w}"
  | .vexScalar op dst src1 src2 => s!"v{Mnemonic.name op} {dst}, {src1}, {src2}"
  | .vextract op dst src imm =>
    s!"v{Mnemonic.name op} {dst.toStrSimd (some 16) addr_w}, {src}, {imm}"
  | .vinsert op dst src1 src2 imm =>
    s!"v{Mnemonic.name op} {dst}, {src1}, {src2.toStrSimd (some 16) addr_w}, {imm}"
  | .vcvtps2ph dst src imm =>
    let ptr := if w matches .W128 then some 8 else some 16
    s!"vcvtps2ph {dst.toStrSimd ptr addr_w}, {src}, {imm}"
  | .sseToGpr op dst src => s!"{Mnemonic.name op} {dst}, {src.toStrSimd op.memBytes? addr_w}"
  | .vexToGpr op dst src => s!"v{Mnemonic.name op} {dst}, {src.toStrSimd op.memBytes? addr_w}"
  | .sseExtract op dst src imm =>
    let immStr := optImm imm
    s!"{Mnemonic.name op} {dst.toStr addr_w}, {src}{immStr}"
  | .vexExtract op dst src imm =>
    let immStr := optImm imm
    s!"v{Mnemonic.name op} {dst.toStr addr_w}, {src}{immStr}"
  | .sseInsert op dst src imm =>
    let immStr := optImm imm
    s!"{Mnemonic.name op} {dst}, {src.toStr addr_w}{immStr}"
  | .vexInsert op dst src1 src2 imm =>
    if op.twoOperand then
      s!"v{Mnemonic.name op} {dst}, {src2.toStr addr_w}"
    else
      let immStr := optImm imm
      s!"v{Mnemonic.name op} {dst}, {src1}, {src2.toStr addr_w}{immStr}"

instance : ToString Instr where
  toString i := match i with
  | .regular a _ o => o.toStr a
  | .avx a _ o => o.toStr a

instance : ToString Directive where
  toString
  | .instr i => ToString.toString i
  | .label l => s!"{l}:"
  | .byteArray bs => ".byte "++", ".intercalate (bs.toList.map (fun b => s!"{b}"))
