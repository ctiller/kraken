# Test xchg, xadd, cmpxchg
# Tests all widths (8, 16, 32, 64) and values (zeroes, all-ones, high bit)
# Concludes with addq %r11, %r11 to set all flags deterministically

# 1. xchg across widths
# 64-bit xchg
movq $0x1122334455667788, %rax
movq $0x8877665544332211, %rbx
xchgq %rax, %rbx

# 32-bit xchg (zero-extends both registers)
movq $0xFFFFFFFFFFFFFFFF, %rcx
movq $0xAAAAAAAAAAAAAAAA, %rdx
movl $0x12345678, %ecx
movl $0x87654321, %edx
xchgl %ecx, %edx

# 16-bit xchg (preserves upper 48 bits)
movq $0x1111222233334444, %rsi
movq $0x5555666677778888, %rdi
xchgw %si, %di

# 8-bit xchg (preserves upper 56 bits)
movq $0x1234567890ABCDEF, %r8
movq $0xFEDCBA0987654321, %r9
xchgb %r8b, %r9b

# Memory xchg (both operand orders)
movq $0x1000, %r10
pushq %r10
xchgq %r10, (%rsp)
xchgq (%rsp), %r10
popq %r10

# 2. xadd across widths
# 64-bit xadd
movq $0x1000, %rax
movq $0x2000, %rbx
xaddq %rax, %rbx

# 32-bit xadd (zero-extends dst and src)
movq $0xFFFFFFFFFFFFFFFF, %rcx
movq $0xFFFFFFFFFFFFFFFF, %rdx
movl $0x80000000, %ecx
movl $0x80000000, %edx
xaddl %ecx, %edx

# Same register xadd (src == dst, result is sum)
movq $0x10, %r12
xaddq %r12, %r12

# 16-bit xadd
movq $0x1234567800000001, %rsi
movq $0x8765432100000002, %rdi
xaddw %si, %di

# 8-bit xadd
movq $0x100, %r8
movq $0x200, %r9
movb $0x7F, %r8b
movb $0x01, %r9b
xaddb %r8b, %r9b

# 3. cmpxchg across widths
# 64-bit cmpxchg (equal: dst := src, ZF := 1)
movq $0x1234, %rax
movq $0x1234, %rbx
movq $0x5678, %rcx
cmpxchgq %rcx, %rbx

# 64-bit cmpxchg (not equal: rax := dst, ZF := 0)
movq $0x1111, %rax
movq $0x2222, %rbx
movq $0x3333, %rcx
cmpxchgq %rcx, %rbx

# 32-bit cmpxchg (not equal: eax := dst, zero-extended into rax)
movq $0xFFFFFFFFFFFFFFFF, %rax
movq $0x4444, %rbx
movq $0x5555, %rcx
cmpxchgl %ecx, %ebx

# 16-bit cmpxchg
movq $0x1000000000000010, %rax
movq $0x2000000000000010, %rbx
movq $0x3000000000000020, %rcx
cmpxchgw %cx, %bx

# 8-bit cmpxchg
movq $0x100, %rax
movq $0x200, %rbx
movb $0x42, %al
movb $0x42, %bl
movb $0x99, %cl
cmpxchgb %cl, %bl

# Set all status flags deterministically
movq $0x4000000000000000, %r11
addq %r11, %r11
