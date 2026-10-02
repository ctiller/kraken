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
