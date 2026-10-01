# Test: SIMD scalar moves and movq/movd (extract/insert and vzeroupper/vzeroall are in
# test_simd_extract_insert.S and test_simd_vzero.S, so that every result reaches the final state)
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

# 1. movss / movsd
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
vmovups 0(%rsp), %xmm4
vmovups 16(%rsp), %xmm5
vmovups 0(%rsp), %xmm6

# Legacy register merge (low bits from src, rest of 128 from dst, upper preserved)
movss %xmm5, %xmm4
movsd %xmm5, %xmm6

# VEX 3-operand register merge (low from src2, rest of 128 from src1, upper zeroed)
vmovss %xmm5, %xmm6, %xmm7
vmovsd %xmm5, %xmm4, %xmm8

# Read the stores back (xmm5 is no longer needed as an input)
movups 32(%rsp), %xmm15
movq 48(%rsp), %xmm5

# 2. movq / movd
movq %xmm7, %xmm9
vmovq %xmm8, %xmm10
movq 0(%rsp), %xmm11
vmovq 8(%rsp), %xmm12
movd 16(%rsp), %xmm13
vmovd 20(%rsp), %xmm14

addq $0x80, %rsp
