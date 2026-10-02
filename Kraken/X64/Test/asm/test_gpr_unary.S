# GPR Unary operations test: popcnt, lzcnt, tzcnt, bsf, bsr, blsi, blsmsk, blsr
# Cover zero, all-ones, high bit, and widths (16/32/64), memory and registers.
# bsf and bsr are only tested on non-zero inputs because destination is undefined when src == 0.
movabsq $0x8000000000000005, %rax
movq %rax, -64(%rsp)
movq $0, -48(%rsp)
movq $-1, -32(%rsp)
lzcntq %rax, %r8
lzcntl %eax, %r9d
lzcntw %ax, %r10w
lzcntq -48(%rsp), %r11
tzcntq %rax, %r12
tzcntl %eax, %r13d
tzcntw %ax, %r14w
tzcntq -32(%rsp), %r15
bsfq %rax, %rbx
bsfl %eax, %ecx
bsfw %ax, %dx
bsrq %rax, %rsi
bsrl %eax, %edi
bsrw -32(%rsp), %bp
blsiq %rax, %r8
blsil %eax, %r9d
blsiq -48(%rsp), %r10
blsmskq %rax, %r11
blsmskl %eax, %r12d
blsmskq -32(%rsp), %r13
blsrq %rax, %r14
blsrl %eax, %r15d
blsrq -32(%rsp), %rbx
movl $1, %ecx
addl %ecx, %ecx
popcnt %r9, %r12
popcntw %r11w, %r13w
