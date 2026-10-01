# Test: SimdFp floating point operations
# Tests packed, scalar, horizontal, and addsub operations with special float values
# (NaNs, infinities, signed zeros, denormals, and normal values).

subq $0x100, %rsp

# Setup test vectors at (%rsp):
# Vector A (32-bit lanes):
# lane 0: +0.0f       (0x00000000)
# lane 1: -0.0f       (0x80000000)
# lane 2: +inf        (0x7f800000)
# lane 3: SNaN        (0x7f800001)
movl $0x00000000, 0(%rsp)
movl $0x80000000, 4(%rsp)
movl $0x7f800000, 8(%rsp)
movl $0x7f800001, 12(%rsp)

# Vector B (32-bit lanes):
# lane 0: -0.0f       (0x80000000)
# lane 1: +0.0f       (0x00000000)
# lane 2: -inf        (0xff800000)
# lane 3: QNaN        (0x7fc00042)
movl $0x80000000, 16(%rsp)
movl $0x00000000, 20(%rsp)
movl $0xff800000, 24(%rsp)
movl $0x7fc00042, 28(%rsp)

# Vector C (32-bit lanes, numbers and denormals):
# lane 0: 1.5f        (0x3fc00000)
# lane 1: -2.0f       (0xc0000000)
# lane 2: 0.5f        (0x3f000000)
# lane 3: denormal    (0x00000002)
movl $0x3fc00000, 32(%rsp)
movl $0xc0000000, 36(%rsp)
movl $0x3f000000, 40(%rsp)
movl $0x00000002, 44(%rsp)

# Vector D (32-bit lanes):
# lane 0: 4.0f        (0x40800000)
# lane 1: 0.25f       (0x3e800000)
# lane 2: 2.0f        (0x40000000)
# lane 3: 3.0f        (0x40400000)
movl $0x40800000, 48(%rsp)
movl $0x3e800000, 52(%rsp)
movl $0x40000000, 56(%rsp)
movl $0x40400000, 60(%rsp)

# Vector 64-bit A:
# lane 0: +0.0        (0x0000000000000000)
# lane 1: +inf        (0x7ff0000000000000)
movl $0x00000000, 64(%rsp)
movl $0x00000000, 68(%rsp)
movl $0x00000000, 72(%rsp)
movl $0x7ff00000, 76(%rsp)

# Vector 64-bit B:
# lane 0: -0.0        (0x8000000000000000)
# lane 1: SNaN        (0x7ff0000000000001)
movl $0x00000000, 80(%rsp)
movl $0x80000000, 84(%rsp)
movl $0x00000001, 88(%rsp)
movl $0x7ff00000, 92(%rsp)

# Vector 64-bit C (numbers and denormals):
# lane 0: 2.5         (0x4004000000000000)
# lane 1: denormal    (0x0000000000000005)
movl $0x00000000, 96(%rsp)
movl $0x40040000, 100(%rsp)
movl $0x00000005, 104(%rsp)
movl $0x00000000, 108(%rsp)

# Vector 64-bit D:
# lane 0: 1.25        (0x3ff4000000000000)
# lane 1: -4.0        (0xc010000000000000)
movl $0x00000000, 112(%rsp)
movl $0x3ff40000, 116(%rsp)
movl $0x00000000, 120(%rsp)
movl $0xc0100000, 124(%rsp)

# Test packed single precision
movaps 0(%rsp), %xmm0
movaps 16(%rsp), %xmm1
addps %xmm1, %xmm0
subps %xmm1, %xmm0
mulps 32(%rsp), %xmm0
divps 48(%rsp), %xmm0

movaps 0(%rsp), %xmm2
minps 16(%rsp), %xmm2
movaps 16(%rsp), %xmm3
minps 0(%rsp), %xmm3
movaps 0(%rsp), %xmm4
maxps 16(%rsp), %xmm4
movaps 16(%rsp), %xmm5
maxps 0(%rsp), %xmm5

# Test packed double precision
movaps 64(%rsp), %xmm6
movaps 80(%rsp), %xmm7
addpd %xmm7, %xmm6
subpd %xmm7, %xmm6
mulpd 96(%rsp), %xmm6
divpd 112(%rsp), %xmm6

movaps 64(%rsp), %xmm8
minpd 80(%rsp), %xmm8
movaps 80(%rsp), %xmm9
minpd 64(%rsp), %xmm9
movaps 64(%rsp), %xmm10
maxpd 80(%rsp), %xmm10
movaps 80(%rsp), %xmm11
maxpd 64(%rsp), %xmm11

# Test scalar single precision (reg and mem)
movaps 32(%rsp), %xmm12
addss 48(%rsp), %xmm12
subss %xmm1, %xmm12
mulss %xmm12, %xmm12
divss 32(%rsp), %xmm12
minss 0(%rsp), %xmm12
maxss 16(%rsp), %xmm12

# Test scalar double precision (reg and mem)
movaps 96(%rsp), %xmm13
addsd 112(%rsp), %xmm13
subsd %xmm7, %xmm13
mulsd %xmm13, %xmm13
divsd 96(%rsp), %xmm13
minsd 64(%rsp), %xmm13
maxsd 80(%rsp), %xmm13

# Test horizontal and addsub ops
movaps 32(%rsp), %xmm14
movaps 48(%rsp), %xmm15
addsubps %xmm15, %xmm14
haddps %xmm15, %xmm14
hsubps %xmm15, %xmm14

# Fold the results that the code below overwrites into %ymm15 (no longer needed as an input),
# so that they reach the final state; unlike xor, vaesenc doesn't cancel equal results.
vaesenc %ymm0, %ymm15, %ymm15
vaesenc %ymm2, %ymm15, %ymm15
vaesenc %ymm3, %ymm15, %ymm15
vaesenc %ymm4, %ymm15, %ymm15
vaesenc %ymm5, %ymm15, %ymm15
vaesenc %ymm8, %ymm15, %ymm15
vaesenc %ymm9, %ymm15, %ymm15
vaesenc %ymm10, %ymm15, %ymm15
vaesenc %ymm11, %ymm15, %ymm15

movaps 96(%rsp), %xmm0
movaps 112(%rsp), %xmm1
addsubpd %xmm1, %xmm0
haddpd %xmm1, %xmm0
hsubpd %xmm1, %xmm0

# Test VEX forms
vaddps %ymm1, %ymm0, %ymm2
vsubpd %ymm7, %ymm6, %ymm3
vmulss %xmm12, %xmm13, %xmm4
vdivsd %xmm13, %xmm12, %xmm5
vminps %ymm1, %ymm0, %ymm6
vmaxpd %ymm7, %ymm6, %ymm7
vhaddps %ymm3, %ymm2, %ymm8
vhsubpd %ymm7, %ymm6, %ymm9
vaddsubps %ymm2, %ymm3, %ymm10
vaddsubpd %ymm6, %ymm7, %ymm11

addq $0x100, %rsp
