# Test: movnti (32-bit and 64-bit non-temporal store)

subq $0x40, %rsp

# Setup values in registers
movl $0x12345678, %eax
movl $0xdeadbeef, %ebx
movabsq $0x0123456789abcdef, %rcx
movabsq $0xfedcba9876543210, %rdx

# 32-bit stores
movnti %eax, 0(%rsp)
movntil %ebx, 8(%rsp)

# 64-bit stores
movnti %rcx, 16(%rsp)
movntiq %rdx, 24(%rsp)

# Read back to registers to verify memory contents
movl 0(%rsp), %r8d
movl 8(%rsp), %r9d
movq 16(%rsp), %r10
movq 24(%rsp), %r11

addq $0x40, %rsp
