# Test: SimdFpCmp opcodes (ps, pd, ss, sd for all 8 comparison predicates)
# Tests NaNs, signed zeros (+0.0 vs -0.0), infinities, and regular numbers.

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

# Test packed single ps (all 8 predicates)
movaps 0(%rsp), %xmm0
cmpeqps 16(%rsp), %xmm0

movaps 0(%rsp), %xmm1
cmpltps 16(%rsp), %xmm1

movaps 0(%rsp), %xmm2
cmpleps 16(%rsp), %xmm2

movaps 0(%rsp), %xmm3
cmpunordps 16(%rsp), %xmm3

movaps 0(%rsp), %xmm4
cmpneqps 16(%rsp), %xmm4

movaps 0(%rsp), %xmm5
cmpnltps 16(%rsp), %xmm5

movaps 0(%rsp), %xmm6
cmpnleps 16(%rsp), %xmm6

movaps 0(%rsp), %xmm7
cmpordps 16(%rsp), %xmm7

# Test packed double pd (all 8 predicates)
movaps 32(%rsp), %xmm8
cmpeqpd 48(%rsp), %xmm8

movaps 32(%rsp), %xmm9
cmpltpd 48(%rsp), %xmm9

movaps 32(%rsp), %xmm10
cmplepd 48(%rsp), %xmm10

movaps 32(%rsp), %xmm11
cmpunordpd 48(%rsp), %xmm11

movaps 32(%rsp), %xmm12
cmpneqpd 48(%rsp), %xmm12

movaps 32(%rsp), %xmm13
cmpnltpd 48(%rsp), %xmm13

movaps 32(%rsp), %xmm14
cmpnlepd 48(%rsp), %xmm14

movaps 32(%rsp), %xmm15
cmpordpd 48(%rsp), %xmm15

# Test scalar single ss (all 8 predicates, preserving high lanes)
movaps 0(%rsp), %xmm0
movaps 16(%rsp), %xmm1
cmpeqss %xmm1, %xmm0

movaps 0(%rsp), %xmm1
movaps 16(%rsp), %xmm1
cmpltss %xmm1, %xmm1

movaps 0(%rsp), %xmm2
movaps 16(%rsp), %xmm1
cmpless %xmm1, %xmm2

movaps 0(%rsp), %xmm3
movaps 16(%rsp), %xmm1
cmpunordss %xmm1, %xmm3

movaps 0(%rsp), %xmm4
movaps 16(%rsp), %xmm1
cmpneqss %xmm1, %xmm4

movaps 0(%rsp), %xmm5
movaps 16(%rsp), %xmm1
cmpnltss %xmm1, %xmm5

movaps 0(%rsp), %xmm6
movaps 16(%rsp), %xmm1
cmpnless %xmm1, %xmm6

movaps 0(%rsp), %xmm7
movaps 16(%rsp), %xmm1
cmpordss %xmm1, %xmm7

# Test scalar double sd (all 8 predicates, preserving high lanes)
movaps 32(%rsp), %xmm8
movaps 48(%rsp), %xmm9
cmpeqsd %xmm9, %xmm8

movaps 32(%rsp), %xmm9
movaps 48(%rsp), %xmm9
cmpltsd %xmm9, %xmm9

movaps 32(%rsp), %xmm10
movaps 48(%rsp), %xmm9
cmplesd %xmm9, %xmm10

movaps 32(%rsp), %xmm11
movaps 48(%rsp), %xmm9
cmpunordsd %xmm9, %xmm11

movaps 32(%rsp), %xmm12
movaps 48(%rsp), %xmm9
cmpneqsd %xmm9, %xmm12

movaps 32(%rsp), %xmm13
movaps 48(%rsp), %xmm9
cmpnltsd %xmm9, %xmm13

movaps 32(%rsp), %xmm14
movaps 48(%rsp), %xmm9
cmpnlesd %xmm9, %xmm14

movaps 32(%rsp), %xmm15
movaps 48(%rsp), %xmm9
cmpordsd %xmm9, %xmm15

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

addq $0x80, %rsp
