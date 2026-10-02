# Test: FP compare pseudo-ops with scalar register operands and VEX forms (including predicates 8-31)
# Requires: vaes

subq $0x80, %rsp

# Setup values in memory:
# Lane 3: NaN (0x7fc00000), Lane 2: -inf (0xff800000), Lane 1: -0.0f (0x80000000), Lane 0: 1.0f (0x3f800000)
movl $0x7fc00000, 12(%rsp)
movl $0xff800000, 8(%rsp)
movl $0x80000000, 4(%rsp)
movl $0x3f800000, 0(%rsp)

# Lane 3: 2.0f (0x40000000), Lane 2: +inf (0x7f800000), Lane 1: +0.0f (0x00000000), Lane 0: 1.0f (0x3f800000)
movl $0x40000000, 28(%rsp)
movl $0x7f800000, 24(%rsp)
movl $0x00000000, 20(%rsp)
movl $0x3f800000, 16(%rsp)

# Double-precision setup:
# Lane 1: NaN (0x7ff8000000000000), Lane 0: -0.0 (0x8000000000000000)
movabsq $0x7ff8000000000000, %rax
movq %rax, 40(%rsp)
movabsq $0x8000000000000000, %rax
movq %rax, 32(%rsp)

# Lane 1: 2.0 (0x4000000000000000), Lane 0: +0.0 (0x0000000000000000)
movabsq $0x4000000000000000, %rax
movq %rax, 56(%rsp)
movq $0, %rax
movq %rax, 48(%rsp)

# Additional float / double for scalar memory test
movl $0x3f800000, 64(%rsp)   # 1.0f
movabsq $0x3ff0000000000000, %rax # 1.0
movq %rax, 72(%rsp)

# Test scalar with register operands
movaps 0(%rsp), %xmm0
movaps 16(%rsp), %xmm1
cmpeqss %xmm1, %xmm0

movaps 32(%rsp), %xmm8
movaps 48(%rsp), %xmm9
cmpeqsd %xmm9, %xmm8

# Test AVX vex forms (including extended predicates 8-31)
vcmpeqps 16(%rsp), %xmm0, %xmm1
vcmpltps 16(%rsp), %xmm0, %xmm2
vcmplepd 48(%rsp), %xmm8, %xmm3
vcmpeqss %xmm1, %xmm0, %xmm4
vcmpeqsd %xmm9, %xmm8, %xmm5

# Extended VEX predicates 8-31 folded into %ymm15
vcmpeq_uqps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpngeps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpngtpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpfalseps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpneq_oqpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpgeps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpgtpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmptrueps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpeq_ospd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmplt_oqps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmple_oqpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpunord_sps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpneq_uspd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpnlt_uqps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpnle_uqpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpord_sps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpeq_uspd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpnge_uqps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpngt_uqpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpfalse_osps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpneq_ospd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpge_oqps 16(%rsp), %xmm0, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmpgt_oqpd 48(%rsp), %xmm8, %xmm10
vaesenc %ymm10, %ymm15, %ymm15
vcmptrue_usss 16(%rsp), %xmm0, %xmm11
vcmptrue_ussd 48(%rsp), %xmm8, %xmm12

# A register compared with itself
movaps 16(%rsp), %xmm6
cmpltss %xmm6, %xmm6
movaps 48(%rsp), %xmm7
cmpltsd %xmm7, %xmm7

addq $0x80, %rsp
