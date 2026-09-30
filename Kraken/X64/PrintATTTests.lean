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
  "movq $42, %rax", "movl $-1, %r9d", "movw %ax, %r15w", "movb %ah, %sil",
  "movabsq $0xFFFFFFFFFFFFFFFF, %rdx", "movq $-9223372036854775808, %rdx",
  "movq sym, %rax", "movq 8(%rsp), %rax", "movq %rax, -16(%rbp,%rcx,8)",
  "movb $1, (%eax)", "movl %eax, 4(%r8d,%r9d,2)", "movq (%rax,%rbx), %rcx",
  "movq 8(%rip), %rax", "movsx %al, %ecx", "movzx %bx, %rdx", "movsbq %al, %rax",
  "movzwl %cx, %edx", "movslq %eax, %rbx", "movslq (%rsp), %rax", "movsbl (%rsp), %ecx",
  "movswq (%rsp), %rdx", "movzbl (%rsp), %ecx", "movzwq (%rsp), %rax",
  "pushq %rbx", "pushq $7", "pushw (%rsp)", "popq %rax", "popq 8(%rsp)",
  "sete %al", "setnz 3(%rsp)", "setb %dh", "setae %bl", "seta %cl", "setbe %al",
  "setl %al", "setle %al", "seto %al", "setno %al", "sets %al", "setns %al",
  "setp %al", "setnp %al", "setge %al", "setg %al",
  "cmovz %rax, %rbx", "cmovl (%rsp), %ecx", "cmovge %rax, %rbx", "cmovg (%rsp), %ecx",
  "xchgb %al, %bl", "xchgw %ax, (%rsp)", "xchgl %eax, %ebx", "xchgq %rax, %rbx", "xchgq %rax, 8(%rsp)",
  "xaddb %al, (%rsp)", "xaddw %ax, %bx", "xaddl %eax, (%rsp)", "xaddq %rax, %rbx",
  "cmpxchgb %bl, (%rsp)", "cmpxchgw %bx, %cx", "cmpxchgl %ebx, (%rsp)", "cmpxchgq %rbx, %rcx",
  "clc", "stc", "cmc", "lahf", "sahf",
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
  -- control flow
  "foo:\n  jmp foo", "je foo", "jne .L1", "jb foo", "jae foo", "ja foo", "jbe foo",
  "jl foo", "jle foo", "call foo", "call %rax", "jmp %rax",
  "jmp 8(%rax)", "call (%rsp)", "ret", "nop", "nop 5", ".align 16", ".align 16, 0x90",
  "pause", "lfence", "mfence", "sfence", "endbr64",
  "nopw (%rax)", "nopl (%rax)", "nopq (%rax)", "nopw %ax", "nopl %eax", "nopq %rax",
  "nopl 0(%rax)", "nopw 0(%rax,%rax,1)",
  "a:\nb: ret\n\nc:",
  -- AVX
  "movups %xmm0, %xmm1", "vmovups (%rsp), %ymm2", "vmovups %zmm31, 64(%rsp)",
  "movaps %xmm3, %xmm4", "addps (%rax), %xmm5", "subps %xmm6, %xmm7",
  "vzeroupper", "vzeroall", "movq %xmm1, %xmm0", "vmovq %xmm1, %xmm0"
]

/-- info: [] -/
#guard_msgs in
#eval corpus.filter (!roundtrips ·)

-- Every SIMD opcode round-trips in both forms, and mnemonics are unique.
/-- info: [] -/
#guard_msgs in
#eval (Mnemonic.names (α := SimdBinOp)).toList.map (·.2) |>.filter fun mn =>
  !roundtrips s!"{mn} 16(%rsp), %xmm1" || !roundtrips s!"v{mn} %ymm1, %ymm2, %ymm3"
#guard let ns := (Mnemonic.names (α := SimdBinOp)).toList.map (·.2); ns.eraseDups == ns

/-- The mnemonics of family `α` for which one of `forms` doesn't round-trip. -/
def failing (α) [Mnemonic α] (forms : α → String → List String) : List String :=
  (Mnemonic.names (α := α)).toList.filterMap fun (op, mn) =>
    if (forms op mn).all roundtrips then none else some mn

/-- info: [] -/
#guard_msgs in
#eval failing GprUnOp (fun _ mn => [s!"{mn} (%rsp), %rax", s!"{mn}l %eax, %ebx"]) ++
  failing GprBinOp (fun op mn => [s!"{mn} %rax, %rbx, %rcx",
    if op.src2First then s!"{mn} 8(%rsp), %ebx, %ecx" else s!"{mn} %ebx, 8(%rsp), %ecx"]) ++
  failing BitTestOp (fun _ mn => [s!"{mn}q $5, (%rsp)", s!"{mn} %ax, %bx"]) ++
  failing SimdMov (fun _ mn => [s!"{mn} (%rsp), %xmm1", s!"{mn} %xmm2, (%rsp)", s!"v{mn} %ymm3, %ymm4"]) ++
  failing SimdUnOp (fun op mn => [s!"{mn} (%rsp), %xmm1",
    s!"v{mn} %{if (op.memBytes? 32).isSome then "x" else "y"}mm3, %ymm4"]) ++
  failing SimdUnImmOp (fun _ mn => [s!"{mn} $1, (%rsp), %xmm1", s!"v{mn} $255, %ymm3, %ymm4"]) ++
  failing SimdBinImmOp (fun _ mn => [s!"{mn} $1, (%rsp), %xmm1", s!"v{mn} $2, %ymm2, %ymm3, %ymm4"]) ++
  failing SimdShiftOp (fun _ mn => [s!"{mn} $3, %xmm1", s!"{mn} (%rsp), %xmm1", s!"v{mn} %xmm2, %ymm3, %ymm4"]) ++
  failing SimdTestOp (fun _ mn => [s!"{mn} (%rsp), %xmm1", s!"v{mn} %xmm3, %xmm4"]) ++
  failing SimdBlendvOp (fun _ mn => [s!"{mn} %xmm0, (%rsp), %xmm1", s!"v{mn} %ymm1, %ymm2, %ymm3, %ymm4"]) ++
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
  failing HintOp (fun _ mn => [mn])

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
