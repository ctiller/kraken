# Test: SIMD logic and comparison instructions
# Exercises: pand pandn por pxor andps andnps orps xorps andpd andnpd orpd xorpd
#            pcmpeqb pcmpeqw pcmpeqd pcmpeqq pcmpgtb pcmpgtw pcmpgtd pcmpgtq

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

# VEX 256-bit bitwise forms
vpor %ymm1, %ymm0, %ymm4
vpxor %ymm1, %ymm0, %ymm5
vandps %ymm1, %ymm0, %ymm8
vandnps %ymm1, %ymm0, %ymm9
vorps %ymm1, %ymm0, %ymm10
vxorps %ymm1, %ymm0, %ymm11
vandpd %ymm1, %ymm0, %ymm12
vandnpd %ymm1, %ymm0, %ymm13
vorpd %ymm1, %ymm0, %ymm14
vxorpd %ymm1, %ymm0, %ymm15

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

# VEX forms for comparison
vpcmpeqb %ymm1, %ymm0, %ymm2
vpcmpeqw %ymm1, %ymm0, %ymm3
vpcmpeqd %ymm1, %ymm0, %ymm4
vpcmpeqq %ymm1, %ymm0, %ymm5
vpcmpgtb %ymm1, %ymm0, %ymm6
vpcmpgtw %ymm1, %ymm0, %ymm7
vpcmpgtd %ymm1, %ymm0, %ymm8
vpcmpgtq %ymm1, %ymm0, %ymm9

addq $0x40, %rsp
