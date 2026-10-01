# Test: SIMD integer comparisons (from test_simd_logic.S)
# Exercises: pcmpeqb pcmpeqw pcmpeqd pcmpeqq pcmpgtb pcmpgtw pcmpgtd pcmpgtq

subq $0x40, %rsp

# Setup pattern 1 at 0(%rsp): 0x0f0f...
movabsq $0x0f0f0f0f0f0f0f0f, %rax
movq %rax, 0(%rsp)
movq %rax, 8(%rsp)

# Setup pattern 2 at 16(%rsp): 0x3333...
movabsq $0x3333333333333333, %rbx
movq %rbx, 16(%rsp)
movq %rbx, 24(%rsp)

# Setup pattern 3 at 32(%rsp): interesting comparison values with signed boundaries
# Byte: (127, -128, 0, -1, 42, -42, 1, 0)
# Quadword 1: 0x7f8000ff2ad60100
# Quadword 2: 0x0123456789abcdef
movabsq $0x7f8000ff2ad60100, %rcx
movq %rcx, 32(%rsp)
movabsq $0x0123456789abcdef, %rcx
movq %rcx, 40(%rsp)

# Equality comparisons: self comparison (should be all 1s) and distinct comparison
movups 32(%rsp), %xmm0
movups 16(%rsp), %xmm1

movaps %xmm0, %xmm2
pcmpeqb %xmm0, %xmm2

movaps %xmm0, %xmm3
pcmpeqw %xmm0, %xmm3

movaps %xmm0, %xmm4
pcmpeqd %xmm0, %xmm4

movaps %xmm0, %xmm5
pcmpeqq %xmm0, %xmm5

# Equality against different operand
movaps %xmm0, %xmm6
pcmpeqb %xmm1, %xmm6

movaps %xmm0, %xmm7
pcmpeqq %xmm1, %xmm7

# Signed greater-than comparisons:
# Greater-than against self (all 0s)
movaps %xmm0, %xmm8
pcmpgtb %xmm0, %xmm8

movaps %xmm0, %xmm9
pcmpgtw %xmm0, %xmm9

movaps %xmm0, %xmm10
pcmpgtd %xmm0, %xmm10

movaps %xmm0, %xmm11
pcmpgtq %xmm0, %xmm11

# Greater-than with mixed signed values:
# xmm0 vs xmm1
movaps %xmm0, %xmm12
pcmpgtb %xmm1, %xmm12

movaps %xmm0, %xmm13
pcmpgtw %xmm1, %xmm13

movaps %xmm0, %xmm14
pcmpgtd %xmm1, %xmm14

movaps %xmm0, %xmm15
pcmpgtq %xmm1, %xmm15

addq $0x40, %rsp
