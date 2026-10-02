# Test: SIMD bitwise instructions (comparisons and 256-bit forms are in test_simd_pcmp.S,
# test_simd_logic_256.S and test_simd_pcmp_256.S, so that every result reaches the final state)
# Exercises: pand pandn por pxor andps andnps orps xorps andpd andnpd orpd xorpd

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

# Load into xmm registers
movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1

# Bitwise integer ops (SSE and VEX)
movaps %xmm0, %xmm2
pand %xmm1, %xmm2

movaps %xmm0, %xmm3
pandn %xmm1, %xmm3

movaps %xmm0, %xmm4
por %xmm1, %xmm4

movaps %xmm0, %xmm5
pxor %xmm1, %xmm5

vpand %xmm1, %xmm0, %xmm6
vpandn %xmm1, %xmm0, %xmm7

# Bitwise float single ops
movaps %xmm0, %xmm8
andps %xmm1, %xmm8

movaps %xmm0, %xmm9
andnps %xmm1, %xmm9

movaps %xmm0, %xmm10
orps %xmm1, %xmm10

movaps %xmm0, %xmm11
xorps %xmm1, %xmm11

# Bitwise float double ops
movaps %xmm0, %xmm12
andpd %xmm1, %xmm12

movaps %xmm0, %xmm13
andnpd %xmm1, %xmm13

movaps %xmm0, %xmm14
orpd %xmm1, %xmm14

movaps %xmm0, %xmm15
xorpd %xmm1, %xmm15

addq $0x40, %rsp
