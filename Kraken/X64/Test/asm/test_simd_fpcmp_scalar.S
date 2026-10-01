# Test: SimdFpCmp scalar ss and sd for all 8 comparison predicates (from test_simd_fpcmp.S)

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

# Scalar single ss (all 8 predicates, memory source, high lanes from the destination)
movaps 0(%rsp), %xmm0
cmpeqss 16(%rsp), %xmm0

movaps 0(%rsp), %xmm1
cmpltss 16(%rsp), %xmm1

movaps 0(%rsp), %xmm2
cmpless 16(%rsp), %xmm2

movaps 0(%rsp), %xmm3
cmpunordss 16(%rsp), %xmm3

movaps 0(%rsp), %xmm4
cmpneqss 16(%rsp), %xmm4

movaps 0(%rsp), %xmm5
cmpnltss 16(%rsp), %xmm5

movaps 0(%rsp), %xmm6
cmpnless 16(%rsp), %xmm6

movaps 0(%rsp), %xmm7
cmpordss 16(%rsp), %xmm7

# Scalar double sd (all 8 predicates, memory source, high lanes from the destination)
movaps 32(%rsp), %xmm8
cmpeqsd 48(%rsp), %xmm8

movaps 32(%rsp), %xmm9
cmpltsd 48(%rsp), %xmm9

movaps 32(%rsp), %xmm10
cmplesd 48(%rsp), %xmm10

movaps 32(%rsp), %xmm11
cmpunordsd 48(%rsp), %xmm11

movaps 32(%rsp), %xmm12
cmpneqsd 48(%rsp), %xmm12

movaps 32(%rsp), %xmm13
cmpnltsd 48(%rsp), %xmm13

movaps 32(%rsp), %xmm14
cmpnlesd 48(%rsp), %xmm14

movaps 32(%rsp), %xmm15
cmpordsd 48(%rsp), %xmm15

addq $0x80, %rsp
