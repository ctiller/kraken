# Test: SimdFpCmp scalar register operands and VEX forms (from test_simd_fpcmp.S)

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

# Test AVX vex forms
vcmpeqps 16(%rsp), %xmm0, %xmm1
vcmpltps 16(%rsp), %xmm0, %xmm2
vcmplepd 48(%rsp), %xmm8, %xmm3
vcmpeqss %xmm1, %xmm0, %xmm4
vcmpeqsd %xmm9, %xmm8, %xmm5

# A register compared with itself
movaps 16(%rsp), %xmm6
cmpltss %xmm6, %xmm6
movaps 48(%rsp), %xmm7
cmpltsd %xmm7, %xmm7

addq $0x80, %rsp
