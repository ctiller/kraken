# Test: SIMD pack and unpack instructions
# Exercises packsswb, packssdw, packuswb, packusdw, punpcklbw, punpcklwd,
# punpckldq, punpcklqdq, punpckhbw, punpckhwd (continued in test_simd_shuf2.S and
# test_simd_shuf_256.S, so that every result reaches the final state)

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

# 1. pack family: packsswb, packssdw, packuswb, packusdw
movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
packsswb %xmm1, %xmm0

movups 0(%rsp), %xmm2
movups 16(%rsp), %xmm3
packssdw %xmm3, %xmm2

movups 0(%rsp), %xmm4
movups 16(%rsp), %xmm5
packuswb %xmm5, %xmm4

movups 0(%rsp), %xmm6
movups 16(%rsp), %xmm7
packusdw %xmm7, %xmm6

# VEX 3-operand forms and memory source
vpacksswb 16(%rsp), %xmm0, %xmm8
vpackusdw %xmm7, %xmm6, %xmm9

# 2. punpckl family: punpcklbw, punpcklwd, punpckldq, punpcklqdq
movups 0(%rsp), %xmm10
punpcklbw 16(%rsp), %xmm10

movups 0(%rsp), %xmm11
punpcklwd 16(%rsp), %xmm11

movups 0(%rsp), %xmm12
punpckldq 16(%rsp), %xmm12

movups 0(%rsp), %xmm13
punpcklqdq 16(%rsp), %xmm13

# 3. punpckh family: punpckhbw, punpckhwd (punpckhdq and punpckhqdq are in test_simd_shuf2.S)
movups 0(%rsp), %xmm14
punpckhbw 16(%rsp), %xmm14

movups 0(%rsp), %xmm15
punpckhwd 16(%rsp), %xmm15

addq $0x80, %rsp
