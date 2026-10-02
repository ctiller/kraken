# Test: SIMD scalar moves (movss, movsd, vmovss, vmovsd)
subq $0x80, %rsp

# Setup memory constants
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x1122334455667788, %rax
movq %rax, 16(%rsp)
movabsq $0x99aabbccddeeff00, %rax
movq %rax, 24(%rsp)

# Pre-fill ymm0-ymm8 to verify upper-128 preservation (legacy) vs zeroing (VEX)
vmovups 0(%rsp), %ymm0
vmovups 0(%rsp), %ymm1
vmovups 0(%rsp), %ymm2
vmovups 0(%rsp), %ymm3
vmovups 0(%rsp), %ymm7
vmovups 0(%rsp), %ymm8

# Load from memory
movss 0(%rsp), %xmm0
vmovss 4(%rsp), %xmm1
movsd 8(%rsp), %xmm2
vmovsd 16(%rsp), %xmm3

# Store to memory
movss %xmm0, 32(%rsp)
vmovss %xmm1, 36(%rsp)
movsd %xmm2, 40(%rsp)
vmovsd %xmm3, 48(%rsp)

# Setup registers for register merge tests
vmovups 0(%rsp), %ymm4
vmovups 16(%rsp), %xmm5
vmovups 0(%rsp), %ymm6

# Legacy register merge (low bits from src, rest of 128 from dst, upper preserved)
movss %xmm5, %xmm4
movsd %xmm5, %xmm6

# VEX 3-operand register merge (low from src2, rest of 128 from src1, upper zeroed)
vmovss %xmm5, %xmm6, %xmm7
vmovsd %xmm5, %xmm4, %xmm8

# Read the stores back (xmm5 is no longer needed as an input)
movups 32(%rsp), %xmm15
movsd 48(%rsp), %xmm5

addq $0x80, %rsp
