# Test: variable shifts vpsllvd, vpsllvq, vpsrlvd, vpsrlvq, vpsravd (128-bit and 256-bit, register
# and memory counts; from test_simd_crypto.S). Results that a later instruction overwrites are first
# folded into %ymm15 with vaesenc (unlike xor, equal results don't cancel), so that every result
# reaches the final state.

subq $0x80, %rsp

# 256-bit counts at 0(%rsp): dwords 1, 0, 32, 0, 31, 0, -1, 0x7fffffff (qwords 1, 32, 31, huge)
movq $1, %rax
movq %rax, 0(%rsp)
movq $32, %rax
movq %rax, 8(%rsp)
movq $31, %rax
movq %rax, 16(%rsp)
movabsq $0x7fffffffffffffff, %rax
movq %rax, 24(%rsp)
# 256-bit data at 32(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 32(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 40(%rsp)
movabsq $0x7fffffff12345678, %rax
movq %rax, 48(%rsp)
movabsq $0x8000000180000001, %rax
movq %rax, 56(%rsp)
# 128-bit counts at 64(%rsp): dwords 4, 0, 63, 0 (qwords 4, 63)
movq $4, %rax
movq %rax, 64(%rsp)
movq $63, %rax
movq %rax, 72(%rsp)
# 128-bit data at 80(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 80(%rsp)
movabsq $0x8123456789abcdef, %rax
movq %rax, 88(%rsp)

movups 80(%rsp), %xmm5
movups 64(%rsp), %xmm6
vmovups 32(%rsp), %ymm8
vmovups 0(%rsp), %ymm9

vpsllvd %xmm6, %xmm5, %xmm0
vaesenc %ymm0, %ymm15, %ymm15
vpsllvd 64(%rsp), %xmm5, %xmm1
vaesenc %ymm1, %ymm15, %ymm15
vpsllvd %ymm9, %ymm8, %ymm2
vaesenc %ymm2, %ymm15, %ymm15
vpsllvd 0(%rsp), %ymm8, %ymm3
vaesenc %ymm3, %ymm15, %ymm15

vpsllvq %xmm6, %xmm5, %xmm0
vaesenc %ymm0, %ymm15, %ymm15
vpsllvq 64(%rsp), %xmm5, %xmm1
vaesenc %ymm1, %ymm15, %ymm15
vpsllvq %ymm9, %ymm8, %ymm2
vaesenc %ymm2, %ymm15, %ymm15
vpsllvq 0(%rsp), %ymm8, %ymm3
vaesenc %ymm3, %ymm15, %ymm15

vpsrlvd %xmm6, %xmm5, %xmm0
vaesenc %ymm0, %ymm15, %ymm15
vpsrlvd 64(%rsp), %xmm5, %xmm1
vaesenc %ymm1, %ymm15, %ymm15
vpsrlvd %ymm9, %ymm8, %ymm2
vaesenc %ymm2, %ymm15, %ymm15
vpsrlvd 0(%rsp), %ymm8, %ymm3
vaesenc %ymm3, %ymm15, %ymm15

vpsrlvq %xmm6, %xmm5, %xmm0
vaesenc %ymm0, %ymm15, %ymm15
vpsrlvq 64(%rsp), %xmm5, %xmm1
vaesenc %ymm1, %ymm15, %ymm15
vpsrlvq %ymm9, %ymm8, %ymm2
vaesenc %ymm2, %ymm15, %ymm15
vpsrlvq 0(%rsp), %ymm8, %ymm3
vaesenc %ymm3, %ymm15, %ymm15

vpsravd %xmm6, %xmm5, %xmm0
vpsravd 64(%rsp), %xmm5, %xmm1
vpsravd %ymm9, %ymm8, %ymm2
vpsravd 0(%rsp), %ymm8, %ymm3

addq $0x80, %rsp
