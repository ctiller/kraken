module

/-
  Round-trip tests for the AT&T printer: `parse (toATT p) = .ok p` for programs
  `p` produced by `parse`.
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

/-- One line per `Operation`/`AvxOperation` constructor and operand form. -/
def corpus : List String := [
  -- data movement, all widths and operand kinds
  "movq $42, %rax", "movl $-1, %r9d", "movw %ax, %r15w", "movb %ah, %al",
  "movabsq $0xFFFFFFFFFFFFFFFF, %rdx", "movq $-9223372036854775808, %rdx",
  "movq sym, %rax", "movq 8(%rsp), %rax", "movq %rax, -16(%rbp,%rcx,8)",
  "movb $1, (%eax)", "movl %eax, 4(%r8d,%r9d,2)", "movq (%rax,%rbx), %rcx",
  "movq 8(%rip), %rax", "movsx %al, %ecx", "movzx %bx, %rdx", "movsbq %al, %rax",
  "movzwl %cx, %edx", "movslq %eax, %rbx", "movslq (%rsp), %rax", "movsbl (%rsp), %ecx",
  "movswq (%rsp), %rdx", "movzbl (%rsp), %ecx", "movzwq (%rsp), %rax",
  "movnti %eax, (%rsp)", "movnti %rax, (%rsp)", "movnti %eax, -16(%rbp,%rcx,8)",
  "pushq %rbx", "pushq $7", "pushw (%rsp)", "popq %rax", "popq 8(%rsp)",
  "sete %al", "setnz 3(%rsp)", "setb %dh", "setae %bl", "seta %cl", "setbe %al",
  "setl %al", "setle %al", "seto %al", "setno %al", "sets %al", "setns %al",
  "setp %al", "setnp %al", "setge %al", "setg %al",
  "cmovz %rax, %rbx", "cmovl (%rsp), %ecx", "cmovge %rax, %rbx", "cmovg (%rsp), %ecx",
  "xchgb %al, %bl", "xchgw %ax, (%rsp)", "xchgl %eax, %ebx", "xchgq %rax, %rbx", "xchgq %rax, 8(%rsp)",
  "xaddb %al, (%rsp)", "xaddw %ax, %bx", "xaddl %eax, (%rsp)", "xaddq %rax, %rbx",
  "cmpxchgb %bl, (%rsp)", "cmpxchgw %bx, %cx", "cmpxchgl %ebx, (%rsp)", "cmpxchgq %rbx, %rcx",
  "cmpxchg8b (%rsp)", "cmpxchg16b (%rsp)",
  "clc", "stc", "cmc", "lahf", "sahf",
  "cld", "std",
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
  "repne scasb", "repne scasw", "repne scasl", "repne scasq",
  "leave", "pushfq", "popfq",
  "ud2", "int3", "hlt",
  -- arithmetic
  "leaq 8(%rax,%rbx,4), %rcx", "leal (%eax), %ecx", "lea sym(%rip), %rax",
  "addq $1, %rax", "addb %al, (%rsp)", "adcl (%rsp), %eax", "adcx %rax, %rbx",
  "adox (%rsp), %ecx", "incq %rax", "incb (%rsp)", "decw %ax", "negl %eax",
  "subq %rax, %rbx", "sbbb $1, %al", "cmpq $0, (%rsp)", "cmpl %eax, %ebx",
  "mulq %rbx", "mulb (%rsp)", "mulx %rax, %rbx, %rcx", "mulxl (%rsp), %eax, %ebx",
  "imulq %rbx", "imulw %ax, %bx", "imulq (%rsp), %rbx", "imulq $3, %rax, %rbx",
  "imull $-3, (%rsp), %eax",
  "divq %rbx", "divb (%rsp)", "idivq %rbx", "idivw (%rsp)",
  "cbtw", "cwtl", "cltq", "cwtd", "cltd", "cqto",
  -- bitwise
  "testq $1, %rax", "testb %al, (%rsp)", "andq %rax, %rbx", "notq %rax",
  "orw $5, %ax", "xorl %eax, %eax",
  "shlq %rax", "shlq $3, %rax", "shlb %cl, (%rsp)", "salq $1, %rax",
  "shrw $2, %ax", "sarl %cl, %eax", "shldq $4, %rax, %rbx", "shrd %cl, %ax, (%rsp)",
  "rolq $1, %rax", "rorb %cl, %al", "rclq $1, %rax", "rcrl %cl, (%rsp)",
  "bswap %eax", "bswapq %rax",
  "movbew (%rsp), %ax", "movbel (%rsp), %eax", "movbeq (%rsp), %rax",
  "movbew %ax, (%rsp)", "movbel %eax, (%rsp)", "movbeq %rax, (%rsp)",
  "crc32b (%rsp), %eax", "crc32w (%rsp), %eax", "crc32l (%rsp), %eax", "crc32b (%rsp), %rax", "crc32q (%rsp), %rax",
  "crc32b %bl, %eax", "crc32w %bx, %eax", "crc32l %ebx, %eax", "crc32b %bl, %rax", "crc32q %rbx, %rax",
  "rorxl $5, (%rsp), %eax", "rorxq $13, (%rsp), %rax", "rorxl $7, %ebx, %eax", "rorxq $63, %rbx, %rax",
  -- control flow
  "foo:\n  jmp foo", "je foo", "jne .L1", "jb foo", "jae foo", "ja foo", "jbe foo",
  "jl foo", "jle foo", "call foo", "call %rax", "jmp %rax",
  "jmp 8(%rax)", "call (%rsp)", "ret", "nop", "nop 5", ".align 16", ".align 16, 0x90",
  "pause", "lfence", "mfence", "sfence", "endbr64",
  "nopw (%rax)", "nopl (%rax)", "nopq (%rax)", "nopw %ax", "nopl %eax", "nopq %rax",
  "nopl 0(%rax)", "nopw 0(%rax,%rax,1)",
  "xlatb", "jrcxz foo", "jecxz foo", "loop foo", "loope foo", "loopne foo",
  "a:\nb: ret\n\nc:",
  -- AVX
  "movups %xmm0, %xmm1", "vmovups (%rsp), %ymm2", "vmovups %zmm31, 64(%rsp)",
  "movaps %xmm3, %xmm4", "addps (%rax), %xmm5", "subps %xmm6, %xmm7",
  "vzeroupper", "vzeroall", "movq %xmm1, %xmm0", "vmovq %xmm1, %xmm0",
  "vcvtps2ph $1, %xmm0, %xmm1", "vcvtps2ph $1, %ymm0, %xmm1",
  "vcvtps2ph $1, %xmm0, (%rsp)", "vcvtps2ph $1, %ymm0, (%rsp)"
]

/-- info: [] -/
#guard_msgs in
#eval corpus.filter (!roundtrips ·)

/-- The mnemonics of family `α` for which one of `forms` doesn't round-trip. -/
def failing (α) [Mnemonic α] (forms : α → String → List String) : List String :=
  (Mnemonic.names (α := α)).toList.filterMap fun (op, mn) =>
    if (forms op mn).all roundtrips then none else some mn

#guard let ns := (Mnemonic.names (α := SimdBinOp)).toList.map (·.2); ns.eraseDups == ns

/-- info: [] -/
#guard_msgs in
#eval failing SimdBinOp (fun op mn =>
    let hasVex := match op with | .crypto cop => cop.hasVex | _ => true
    let isScalar := op.memBytes?.isSome || (op matches .shuf .movlhps | .shuf .movhlps)
    let isRegOnly := op matches .shuf .movlhps | .shuf .movhlps
    (if op.hasLegacy then [if isRegOnly then s!"{mn} %xmm0, %xmm1" else s!"{mn} 16(%rsp), %xmm1"] else []) ++
    (if hasVex then [s!"v{mn} %{if isScalar then "x" else "y"}mm1, %{if isScalar then "x" else "y"}mm2, %{if isScalar then "x" else "y"}mm3"] else [])) ++
  failing GprUnOp (fun _ mn => [s!"{mn} (%rsp), %rax", s!"{mn}l %eax, %ebx"]) ++
  failing GprBinOp (fun op mn => [s!"{mn} %rax, %rbx, %rcx",
    if op.src2First then s!"{mn} 8(%rsp), %ebx, %ecx" else s!"{mn} %ebx, 8(%rsp), %ecx"]) ++
  failing BitTestOp (fun _ mn => [s!"{mn}q $5, (%rsp)", s!"{mn} %ax, %bx"]) ++
  failing SimdMov (fun _ mn => [s!"{mn} (%rsp), %xmm1", s!"{mn} %xmm2, (%rsp)", s!"v{mn} %ymm3, %ymm4"]) ++
  failing SimdUnOp (fun op mn =>
    let is128Only := op matches .phminposuw | .aesimc | .movq | .movd
    let dstReg := if is128Only || op.isNarrowing then "x" else "y"
    (if op.hasLegacy then [s!"{mn} (%rsp), %xmm1"] else []) ++
    (if op.isNarrowing then
      [s!"v{mn} %ymm3, %xmm4", s!"v{mn}x (%rsp), %xmm4", s!"v{mn}y (%rsp), %xmm4"]
    else if op == .movd then
      [s!"v{mn} (%rsp), %xmm4"]
    else
      [s!"v{mn} %{if (op.memBytes? 32).isSome then "x" else dstReg}mm3, %{dstReg}mm4"])) ++
  failing SimdUnImmOp (fun op mn =>
    let is128Only := op == .aeskeygenassist
    let reg := if is128Only then "x" else "y"
    (if op.hasLegacy then [s!"{mn} $1, (%rsp), %xmm1"] else []) ++
    [s!"v{mn} $255, %{reg}mm3, %{reg}mm4"]) ++
  failing SimdBinImmOp (fun op mn =>
    let is128Only := op matches .roundss | .roundsd | .cmpss | .cmpsd | .insertps | .dppd
    let reg := if is128Only then "x" else "y"
    (if op.hasLegacy then [s!"{mn} $1, (%rsp), %xmm1"] else []) ++
    (if op == .sha1rnds4 then [] else [s!"v{mn} $2, %{reg}mm2, %{reg}mm3, %{reg}mm4"])) ++
  failing SimdShiftOp (fun _ mn => [s!"{mn} $3, %xmm1", s!"{mn} (%rsp), %xmm1", s!"v{mn} %xmm2, %ymm3, %ymm4"]) ++
  failing SimdTestOp (fun op mn => (if op.hasLegacy then [s!"{mn} (%rsp), %xmm1"] else []) ++ [s!"v{mn} %xmm3, %xmm4"]) ++
  failing SimdBlendvOp (fun op mn =>
    [s!"{mn} %xmm0, (%rsp), %xmm1"] ++
    (if op.hasVex then [s!"v{mn} %ymm1, %ymm2, %ymm3, %ymm4"] else [])) ++
  failing SimdFmaOp (fun _ mn => [s!"v{mn} (%rsp), %xmm1, %xmm2", s!"v{mn} %xmm1, %xmm2, %xmm3"]) ++
  failing SimdScalarMov (fun _ mn => [
    s!"{mn} %xmm1, %xmm0",
    s!"{mn} (%rsp), %xmm0",
    s!"{mn} %xmm0, (%rsp)",
    s!"v{mn} %xmm2, %xmm1, %xmm0",
    s!"v{mn} (%rsp), %xmm0",
    s!"v{mn} %xmm0, (%rsp)"
  ]) ++
  failing SimdExtract128Op (fun _ mn => [
    s!"v{mn} $1, %ymm0, %xmm1",
    s!"v{mn} $0, %ymm0, (%rsp)"
  ]) ++
  failing SimdInsert128Op (fun _ mn => [
    s!"v{mn} $1, %xmm2, %ymm1, %ymm0",
    s!"v{mn} $0, (%rsp), %ymm1, %ymm0"
  ]) ++
  failing SimdToGprOp (fun op mn =>
    if op.memBytes?.isSome then [s!"{mn} (%rsp), %rax", s!"v{mn} %xmm1, %rax"]
    else [s!"{mn} %xmm1, %eax", s!"v{mn} %xmm1, %rax", s!"v{mn} %ymm1, %eax"]) ++
  failing SimdExtractOp (fun op mn =>
    let imm := if op.hasImm then "$1, " else ""
    let dstReg := if op == .pextrd then "%eax" else "%rax"
    [s!"{mn} {imm}%xmm1, (%rsp)", s!"v{mn} {imm}%xmm1, {dstReg}"]) ++
  failing SimdInsertOp (fun op mn =>
    let imm := if op.hasImm then "$1, " else ""
    let (src_s, src_v) :=
      if op == .movd then ("%eax", "%eax")
      else if op == .movq then ("%rax", "%rax")
      else ("(%rsp)", "(%rsp)")
    let sfx := if op == .cvtsi2ss || op == .cvtsi2sd then "q" else ""
    if op.twoOperand then
      [s!"{mn} {src_s}, %xmm1", s!"v{mn} {src_v}, %xmm1"]
    else
      [s!"{mn}{sfx} {imm}{src_s}, %xmm1", s!"v{mn}{sfx} {imm}{src_v}, %xmm1, %xmm2"]) ++
  failing HintOp (fun _ mn => [mn]) ++
  failing MemHintOp (fun _ mn => [s!"{mn} (%rsp)", s!"{mn} (%eax)"])

-- The address size of a memory operand in any position is kept.
#guard match parse "bextr %rbx, -8(%esp), %r15" with
  | .ok p => toATT p == "bextr %rbx, -8(%esp), %r15"
  | .error _ => false

-- Printed form is canonical AT&T.
#guard match parse "movq %rax, -16(%rbp,%rcx,8)\nfoo: imul $3, 8(%eax), %ebx\njne foo" with
  | .ok p => toATT p == "movq %rax, -16(%rbp,%rcx,8)\nfoo:\nimull $3, 8(%eax), %ebx\njne foo"
  | .error _ => false

#guard match parse "lock xaddq %rax, (%rsp)", parse "xaddq %rax, (%rsp)" with
  | .ok p1, .ok p2 => p1 == p2
  | _, _ => false

-- Every program in the hardware test corpus round-trips.
#eval show IO Unit from do
  for f in ← System.FilePath.readDir "Kraken/X64/Test/asm" do
    if f.path.extension == some "S" then
      unless roundtrips (stripDirectives (← IO.FS.readFile f.path)) do
        throw <| .userError s!"{f.path} does not round-trip"

/-- Programs the parser rejects. -/
def rejected : List String := [
  -- `rep` prefixes only apply to string instructions.
  "rep addq %rax, %rbx",
  -- BMI operands are 32 or 64 bits wide.
  "shlx %ax, %bx, %cx",
  -- `lock` prefix requires a valid lockable instruction with memory destination.
  "lock addq $1, %rax", "lock btq $1, (%rsp)", "lock movq %rax, (%rsp)",
  -- Legacy SSE instructions reject ymm operands
  "addps %ymm0, %ymm1", "movdqa %ymm0, %ymm1",
  -- VEX SHA instructions do not exist
  "vsha1msg1 %xmm1, %xmm2, %xmm3", "vsha1rnds4 $1, %xmm1, %xmm2, %xmm3",
  "vsha256rnds2 %xmm1, %xmm2, %xmm3",
  -- 128-bit only VEX instructions reject ymm
  "vaesimc %ymm0, %ymm1", "vaeskeygenassist $0, %ymm0, %ymm1", "vphminposuw %ymm0, %ymm1",
  "vdppd $1, %ymm0, %ymm1, %ymm2", "vpextrb $0, %ymm0, %rax", "vpinsrb $0, %rax, %ymm0, %ymm1",
  "vmovd %rax, %ymm0", "vmovq %rax, %ymm0", "vextractps $0, %ymm0, %rax",
  "vinsertps $0, %xmm0, %ymm1, %ymm2",
  -- Scalar SIMD VEX instructions reject ymm
  "vaddss %ymm0, %ymm1, %ymm2", "vcmpss $0, %ymm0, %ymm1, %ymm2", "vroundss $0, %ymm0, %ymm1, %ymm2",
  "vfmadd132ss %ymm0, %ymm1, %ymm2",
  -- 256-bit only VEX instructions reject xmm
  "vpermq $0, %xmm0, %xmm1", "vpermpd $0, %xmm0, %xmm1", "vpermd %xmm0, %xmm1, %xmm2",
  "vpermps %xmm0, %xmm1, %xmm2", "vperm2f128 $0, %xmm0, %xmm1, %xmm2",
  "vperm2i128 $0, %xmm0, %xmm1, %xmm2", "vbroadcastsd (%rax), %xmm0", "vbroadcasti128 (%rax), %xmm0",
  "vbroadcastf128 (%rax), %xmm0", "vextractf128 $0, %xmm0, (%rax)", "vextracti128 $0, %xmm0, (%rax)",
  "vinsertf128 $0, (%rax), %xmm0, %ymm1", "vinserti128 $0, (%rax), %ymm0, %xmm1",
  -- push/pop only allow 16- and 64-bit operands
  "pushb $1", "pushl $1", "pushl %eax", "pushb %al", "popl %eax", "popb %al", "popl (%rax)",
  "popb (%rax)",
  -- 8-bit operands rejected for popcnt/lzcnt/tzcnt/bsf/bsr
  "popcnt %al, %bl", "popcntb %al, %bl", "lzcnt %al, %bl", "tzcnt %al, %bl", "bsf %al, %bl",
  "bsr %al, %bl",
  -- 8-bit operands rejected for bt/bts/btr/btc
  "bt %al, %bl", "btb $1, (%rax)", "bts %al, %bl", "btr %al, %bl", "btc %al, %bl",
  -- 8-bit operands rejected for cmovcc
  "cmove %al, %bl", "cmovzb %al, %bl",
  -- 8- and 16-bit operands rejected for blsi/blsmsk/blsr
  "blsi %al, %bl", "blsi %ax, %bx", "blsiw %ax, %bx", "blsmsk %ax, %bx", "blsr %ax, %bx",
  -- 8- and 16-bit operands rejected for adcx/adox
  "adcx %al, %bl", "adcx %ax, %bx", "adcxw %ax, %bx", "adox %ax, %bx",
  -- 8- and 16-bit operands rejected for bswap
  "bswap %al", "bswap %ax", "bswapw %ax",
  -- crc32 width constraints
  "crc32w %ax, %rbx", "crc32l %eax, %rbx", "crc32q %rax, %ebx", "crc32b %al, %bx",
  "crc32b %ah, %rbx", "crc32 %ah, %rbx",
  -- vcvtpd2ps, vcvtpd2dq, vcvttpd2dq narrowing operand and suffix constraints
  "vcvtpd2ps (%rax), %xmm0", "vcvtpd2ps %ymm1, %ymm0", "cvtpd2psx (%rax), %xmm0",
  -- VEX compare pseudo-ops for predicates 8-31
  "vcmpeq_uqss %ymm1, %ymm2, %ymm3", "vcmpeq_uqsd 16(%rsp), %ymm2, %ymm3", "cmpeq_uqps %xmm1, %xmm2",
  -- Two-operand forms with implicit %xmm0
  "blendvps %xmm3, %xmm1, %xmm2", "blendvps %ymm1, %ymm2", "sha256rnds2 %ymm1, %ymm2",
  -- VEX-only instructions reject legacy non-v forms
  "pbroadcastb %xmm0, %xmm1", "permd %xmm0, %xmm1, %xmm2", "permps %xmm0, %xmm1, %xmm2",
  "psllvd %xmm0, %xmm1, %xmm2", "permq $0, %xmm0, %xmm1", "pblendd $1, %xmm0, %xmm1",
  "testps %xmm0, %xmm1", "testpd %xmm0, %xmm1",
  -- vmovlhps/vmovhlps reject ymm
  "vmovlhps %ymm0, %ymm1, %ymm2", "vmovhlps %ymm0, %ymm1, %ymm2",
  -- REX registers with high byte registers
  "crc32b %ah, %r8d", "movb %ah, %sil", "addb %ah, %r8b", "movzbq %ah, %rax", "movb %ah, (%r8)",
  -- movd between vector registers rejected
  "movd %xmm1, %xmm0",
  -- permilps/permilpd legacy forms rejected (VEX-only)
  "permilps $1, %xmm0, %xmm1", "permilpd $1, %xmm0, %xmm1",
  -- SIMD GPR transfer register width restrictions
  "pinsrb $0, %al, %xmm0", "pinsrb $0, %ah, %xmm0", "pinsrw $0, %ax, %xmm0", "pinsrd $0, %ax, %xmm0",
  "pextrb $0, %xmm0, %al", "pextrw $0, %xmm0, %ax", "vpinsrb $0, %ah, %xmm1, %xmm2",
  "cvtsi2ss %al, %xmm0", "movd %ax, %xmm0", "vmovd %ax, %xmm0", "movq %eax, %xmm0",
  "vmovq %eax, %xmm0", "movq %xmm0, %eax", "vmovq %xmm0, %eax", "pinsrd $0, %rax, %xmm0",
  "pinsrq $0, %eax, %xmm0", "pextrd $0, %xmm0, %rax", "pextrq $0, %xmm0, %eax",
  -- movlhps/movhlps reject memory source
  "movlhps (%rax), %xmm1", "vmovlhps (%rax), %xmm1, %xmm2", "movhlps (%rax), %xmm1",
  "vmovhlps (%rax), %xmm1, %xmm2"
]

/-- info: [] -/
#guard_msgs in
#eval rejected.filter (parse · matches .ok _)

/-- Parser edge cases that are accepted and round-trip. -/
def accepted : List String := [
  -- A trailing `$0` operand, and `crc32` sized by its register source.
  "pushq $0", "crc32 %al, %eax",
  -- `lock` prefix requires a valid lockable instruction with memory destination.
  "lock btsq $1, (%rsp)",
  -- push/pop only allow 16- and 64-bit operands
  "push $42", "pushw $42", "pushq $42",
  -- 8-bit operands rejected for popcnt/lzcnt/tzcnt/bsf/bsr
  "popcnt %ax, %bx",
  -- 8-bit operands rejected for bt/bts/btr/btc
  "bt %ax, %bx",
  -- 8-bit operands rejected for cmovcc
  "cmove %ax, %bx", "cmovzl %eax, %ebx",
  -- 8- and 16-bit operands rejected for blsi/blsmsk/blsr
  "blsi %eax, %ebx",
  -- 8- and 16-bit operands rejected for adcx/adox
  "adcx %eax, %ebx", "adox %eax, %ebx",
  -- 8- and 16-bit operands rejected for bswap
  "bswap %eax", "bswap %rax",
  -- crc32 width constraints
  "crc32b %al, %ebx", "crc32w %ax, %ebx", "crc32l %eax, %ebx", "crc32b %al, %rbx",
  "crc32q %rax, %rbx", "crc32b %ah, %ebx",
  -- vcvtpd2ps, vcvtpd2dq, vcvttpd2dq narrowing operand and suffix constraints
  "vcvtpd2ps %ymm1, %xmm0", "vcvtpd2ps %xmm1, %xmm0", "vcvtpd2psx (%rax), %xmm0",
  "vcvtpd2psy (%rax), %xmm0", "cvtpd2ps (%rax), %xmm0", "vcvtpd2dq %ymm1, %xmm0",
  "vcvtpd2dqy (%rax), %xmm0", "vcvttpd2dq %ymm1, %xmm0", "vcvttpd2dqx (%rax), %xmm0",
  -- VEX compare pseudo-ops for predicates 8-31
  "vcmpeq_uqps %xmm1, %xmm2, %xmm3", "vcmpeq_uqps %ymm1, %ymm2, %ymm3",
  "vcmpeq_uqpd 16(%rsp), %ymm2, %ymm3", "vcmptrue_usps %xmm1, %xmm2, %xmm3",
  "vcmpeq_uqss %xmm1, %xmm2, %xmm3", "vcmpeq_uqsd 16(%rsp), %xmm2, %xmm3",
  "vcmptrue_uspd 16(%rsp), %ymm2, %ymm3",
  -- Two-operand forms with implicit %xmm0
  "sha256rnds2 %xmm1, %xmm2", "sha256rnds2 (%rax), %xmm2", "blendvps %xmm1, %xmm2",
  "blendvps (%rax), %xmm2", "blendvpd %xmm1, %xmm2", "blendvpd (%rax), %xmm2",
  "pblendvb %xmm1, %xmm2", "pblendvb (%rax), %xmm2", "sha256rnds2 %xmm0, %xmm1, %xmm2",
  "blendvps %xmm0, %xmm1, %xmm2", "blendvps %xmm0, %xmm2", "sha256rnds2 %xmm0, %xmm2",
  -- Unsuffixed memory push/pop defaults to 64-bit
  "push (%rax)", "pop 8(%rsp)",
  -- REX registers with high byte registers
  "movb %ah, (%rax)", "movb %ah, %al", "movzbl %ah, %eax",
  -- permilps/permilpd legacy forms rejected (VEX-only)
  "vpermilps $1, %xmm0, %xmm1", "vpermilpd $1, %xmm0, %xmm1",
  -- SIMD GPR transfer register width restrictions
  "pinsrb $0, %eax, %xmm0", "pinsrb $0, %rax, %xmm0", "pextrb $0, %xmm0, %eax",
  "pextrb $0, %xmm0, %rax", "pinsrd $0, %eax, %xmm0", "pinsrq $0, %rax, %xmm0",
  "pextrd $0, %xmm0, %eax", "pextrq $0, %xmm0, %rax", "movq %rax, %xmm0", "movq %xmm0, %rax"
]

/-- info: [] -/
#guard_msgs in
#eval accepted.filter (!roundtrips ·)

#guard match parse "pushw $42" with
  | .ok [d] => toString d == "push word ptr 42"
  | _ => false
