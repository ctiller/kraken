# Test failing cmpxchg, cmpxchg8b, and cmpxchg16b with memory destinations

subq $64, %rsp

# --- 1. cmpxchgb failure on stack ---
movb $0x55, 16(%rsp)
movb $0x11, %al
movb $0x99, %bl
cmpxchgb %bl, 16(%rsp)
movb %al, %cl
movb 16(%rsp), %dl

# --- 2. cmpxchgw failure on stack ---
movw $0x2233, 16(%rsp)
movw $0x4455, %ax
movw $0x6677, %bx
cmpxchgw %bx, 16(%rsp)
movw %ax, %r8w
movw 16(%rsp), %r9w

# --- 3. cmpxchgl failure on stack ---
movl $0x12345678, 16(%rsp)
movl $0x87654321, %eax
movl $0xDEADBEEF, %ebx
cmpxchgl %ebx, 16(%rsp)
movl %eax, %r10d
movl 16(%rsp), %r11d

# --- 4. cmpxchgq failure on stack ---
movabsq $0x1122334455667788, %rax
movq %rax, 16(%rsp)
movabsq $0x8877665544332211, %rax
movabsq $0xFEEDFACECAFEBABE, %rbx
cmpxchgq %rbx, 16(%rsp)
movq %rax, %r12
movq 16(%rsp), %r13

# --- 5. cmpxchg8b failure on stack ---
movl $0x11112222, 16(%rsp)
movl $0x33334444, 20(%rsp)
movl $0x55556666, %eax
movl $0x77778888, %edx
movl $0xAAAABBBB, %ebx
movl $0xCCCCDDDD, %ecx
cmpxchg8b 16(%rsp)
movq 16(%rsp), %r14

# --- 6. cmpxchg16b failure on stack ---
# 16(%rsp) is 16-byte aligned
movabsq $0x0123456789ABCDEF, %rsi
movabsq $0xFEDCBA9876543210, %rdi
movq %rsi, 16(%rsp)
movq %rdi, 24(%rsp)
movabsq $0x1111111111111111, %rax
movabsq $0x2222222222222222, %rdx
movabsq $0x3333333333333333, %rbx
movabsq $0x4444444444444444, %rcx
cmpxchg16b 16(%rsp)
movq 16(%rsp), %rsi
movq 24(%rsp), %rdi

# --- 7. cmpxchgq failure where the accumulator is the address register ---
movq $5, 16(%rsp)
leaq 16(%rsp), %rax
movq $9, %rbx
cmpxchgq %rbx, (%rax)
movq 16(%rsp), %r15

addq $64, %rsp
