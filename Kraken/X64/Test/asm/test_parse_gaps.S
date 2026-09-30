# Test parse gaps: movzbl/movswq/movslq from stack memory, nops, hints

# Setup test values on the stack
movq $0x1122334455667788, %rax
movq %rax, -16(%rsp)

# Test movzbl from stack memory
movzbl -16(%rsp), %ebx

# Test movswq from stack memory
movswq -16(%rsp), %rcx

# Test movslq from stack memory
movslq -16(%rsp), %rdx

# Test movsxd from stack memory and register
movsxd -16(%rsp), %rsi
movsxd %ebx, %rdi

# Test hints (no-ops)
pause
lfence
mfence
sfence
endbr64

# Test nops with memory and register operands
nopw -16(%rsp)
nopl -16(%rsp)
nopq -16(%rsp)
nopw %ax
nopl %eax
nopq %rax
nopl 0(%rsp)
nopw 0(%rsp,%rax,1)

# End with an instruction defining flags
addq %rbx, %rbx
