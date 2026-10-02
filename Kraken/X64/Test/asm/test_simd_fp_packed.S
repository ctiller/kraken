# Test: SimdFp packed floating-point operations
# Tests packed single and double precision add/sub/mul/div/min/max (SSE and VEX)
# with special float values (NaNs, infinities, signed zeros, denormals, and normal values).

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

# Test 256-bit VEX packed single and double precision forms
vmovups 0(%rsp), %ymm12
vmovups 32(%rsp), %ymm13
vmulps %ymm13, %ymm12, %ymm14
vdivps 32(%rsp), %ymm14, %ymm14
vminps %ymm13, %ymm12, %ymm15
vmaxps %ymm12, %ymm13, %ymm13
vpxor %ymm15, %ymm14, %ymm14

vmovups 64(%rsp), %ymm12
vmovups 96(%rsp), %ymm15
vmulpd %ymm15, %ymm12, %ymm15
vdivpd 96(%rsp), %ymm15, %ymm15
vminpd %ymm15, %ymm12, %ymm12
vmaxpd 64(%rsp), %ymm15, %ymm15

addq $0x100, %rsp
