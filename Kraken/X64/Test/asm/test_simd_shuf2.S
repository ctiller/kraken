# Test: SIMD unpack, byte permute, movlhps and movhlps (continued from test_simd_shuf.S)
# Exercises punpckhdq, punpckhqdq, unpcklps, unpckhps, unpcklpd, unpckhpd, pshufb, movlhps, movhlps

subq $0x80, %rsp

# Setup test vectors in memory
# -16(%rsp) .. 0(%rsp): data vector 1
movabsq $0x01f4fff07fff8000, %rax
movq %rax, 0(%rsp)
movabsq $0x0050ff8000200001, %rax
movq %rax, 8(%rsp)

# 16(%rsp) .. 32(%rsp): data vector 2
movabsq $0x7060504030201000, %rax
movq %rax, 16(%rsp)
movabsq $0x0f0e0d0c0b0a0908, %rax
movq %rax, 24(%rsp)

# 32(%rsp) .. 48(%rsp): mask vector for pshufb
# lane 0: byte 2; lane 1: msb set (0x80 -> 0); lane 2: byte 15; lane 3: byte 0 with high bits (0x40 -> byte 0)
movabsq $0x07060504400f8002, %rax
movq %rax, 32(%rsp)
movabsq $0x8f8e8d8c0b0a0908, %rax
movq %rax, 40(%rsp)

# 48(%rsp) .. 80(%rsp): 256-bit data
movabsq $0x1111222233334444, %rax
movq %rax, 48(%rsp)
movabsq $0x5555666677778888, %rax
movq %rax, 56(%rsp)
movabsq $0xaaaabbbbccccdddd, %rax
movq %rax, 64(%rsp)
movabsq $0xeeeeffff00001111, %rax
movq %rax, 72(%rsp)

# 1. punpckhdq, punpckhqdq
movups 0(%rsp), %xmm0
punpckhdq 16(%rsp), %xmm0

movups 0(%rsp), %xmm1
punpckhqdq 16(%rsp), %xmm1

# 2. FP unpacks: unpcklps, unpckhps, unpcklpd, unpckhpd
movups 0(%rsp), %xmm2
unpcklps 16(%rsp), %xmm2

movups 0(%rsp), %xmm3
unpckhps 16(%rsp), %xmm3

movups 0(%rsp), %xmm4
unpcklpd 16(%rsp), %xmm4

movups 0(%rsp), %xmm5
unpckhpd 16(%rsp), %xmm5

# 3. pshufb
movups 16(%rsp), %xmm6
pshufb 32(%rsp), %xmm6

vpshufb 32(%rsp), %xmm6, %xmm7

# 4. movlhps, movhlps
movups 0(%rsp), %xmm8
movups 16(%rsp), %xmm9
movlhps %xmm9, %xmm8

movups 0(%rsp), %xmm10
movups 16(%rsp), %xmm11
movhlps %xmm11, %xmm10

vmovlhps %xmm9, %xmm0, %xmm12
vmovhlps %xmm11, %xmm1, %xmm13

addq $0x80, %rsp
