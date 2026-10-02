# bt/bts/btr/btc with immediate and register bit offsets, including register offsets that
# select bits outside a memory operand (signed, relative to the address).
movabsq $0x8000000000000005, %rax
movq %rax, -64(%rsp)
movq %rax, -56(%rsp)
movq $0, -48(%rsp)
btq $63, %rax
setc %bl
btsl $33, %eax
btrq $0, %rax
movq $70, %rcx
btcq %rcx, %rax
setc %bh
movq $65, %rdx
btsq %rdx, -64(%rsp)
movq $-60, %rsi
btrq %rsi, -48(%rsp)
setc %cl
btcw $17, -56(%rsp)
movq $130, %rdi
btl %edi, -64(%rsp)
setc %ch
movq -64(%rsp), %r8
movq -56(%rsp), %r9
movq -48(%rsp), %r10
movl $1, %r11d
addq %r11, %r11
