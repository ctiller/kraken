# Test cmpxchg8b and cmpxchg16b
#
# Stack setup (aligned to 16 bytes for cmpxchg16b)
subq $64, %rsp

# --- cmpxchg8b equal case ---
# Set memory 8 bytes at 16(%rsp) to 0x1122334455667788
# edx:eax = 0x11223344:0x55667788
# ecx:ebx = 0xAABBCCDD:0xEEFF0011
movl $0x55667788, %eax
movl $0x11223344, %edx
movl $0xEEFF0011, %ebx
movl $0xAABBCCDD, %ecx
movl %eax, 16(%rsp)
movl %edx, 20(%rsp)

cmpxchg8b 16(%rsp)

# Should match: ZF=1, memory becomes ecx:ebx, eax/edx unchanged
sete %r8b
movq 16(%rsp), %r9

# --- cmpxchg8b unequal case ---
# edx:eax = 0x99999999:0x88888888 (different from memory 16(%rsp))
movl $0x88888888, %eax
movl $0x99999999, %edx
cmpxchg8b 16(%rsp)

# Should mismatch: ZF=0, eax/edx loaded from memory
sete %r10b
movl %eax, %r11d
movl %edx, %r12d

# --- cmpxchg16b equal case ---
# 16(%rsp) is 16-byte aligned (rsp was aligned, subq $64 maintains 16B alignment)
# Set memory 16 bytes at 16(%rsp) to rdx:rax
movabsq $0x0123456789ABCDEF, %rax
movabsq $0x0FEDCBA987654321, %rdx
movabsq $0xAAAAAAAAAAAAAAAA, %rbx
movabsq $0xBBBBBBBBBBBBBBBB, %rcx
movq %rax, 16(%rsp)
movq %rdx, 24(%rsp)

cmpxchg16b 16(%rsp)

# Should match: ZF=1, memory becomes rcx:rbx, rax/rdx unchanged
sete %r13b
movq 16(%rsp), %r14
movq 24(%rsp), %r15

# --- cmpxchg16b unequal case ---
movabsq $0x1111111111111111, %rax
movabsq $0x2222222222222222, %rdx
cmpxchg16b 16(%rsp)

# Should mismatch: ZF=0, rax/rdx loaded from memory (which is rcx:rbx)
sete %dil
movq %rax, %rsi

# Stack cleanup
addq $64, %rsp
