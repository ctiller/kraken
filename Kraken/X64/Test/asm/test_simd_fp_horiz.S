# Test: SimdFp horizontal and asymmetric floating-point operations
# Tests addsubps, addsubpd, haddps, haddpd, hsubps, hsubpd and their VEX
# 128-bit and 256-bit forms with special float values (NaNs, infinities,
# signed zeros, denormals, and normal values).

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

# Legacy SSE single-precision: normal values & denormals (reg and m128, preserves upper YMM)
vmovups 0(%rsp), %ymm0
movaps 32(%rsp), %xmm0
movaps 48(%rsp), %xmm1
addsubps %xmm1, %xmm0
haddps 48(%rsp), %xmm0
hsubps %xmm1, %xmm0

# Legacy SSE single-precision: special values (signed zeros, infinities, SNaN/QNaN)
movaps 0(%rsp), %xmm2
addsubps 16(%rsp), %xmm2
movaps 0(%rsp), %xmm3
haddps 16(%rsp), %xmm3
movaps 0(%rsp), %xmm4
hsubps 16(%rsp), %xmm4

# Legacy SSE double-precision: normal values & denormals (reg and m128, preserves upper YMM)
vmovups 64(%rsp), %ymm5
movaps 96(%rsp), %xmm5
movaps 112(%rsp), %xmm6
addsubpd %xmm6, %xmm5
haddpd 112(%rsp), %xmm5
hsubpd %xmm6, %xmm5

# Legacy SSE double-precision: special values (signed zeros, infinities, SNaN)
movaps 64(%rsp), %xmm7
addsubpd 80(%rsp), %xmm7
movaps 64(%rsp), %xmm8
haddpd 80(%rsp), %xmm8
movaps 64(%rsp), %xmm9
hsubpd 80(%rsp), %xmm9

# VEX 128-bit forms (reg and m128, zeroes upper YMM bits)
vmovups 0(%rsp), %ymm10
vaddsubps 48(%rsp), %xmm1, %xmm10
vhaddps %xmm1, %xmm10, %xmm10
vhsubps 32(%rsp), %xmm10, %xmm10

vmovups 64(%rsp), %ymm11
vaddsubpd 112(%rsp), %xmm6, %xmm11
vhaddpd %xmm6, %xmm11, %xmm11
vhsubpd 96(%rsp), %xmm11, %xmm11

# VEX 256-bit single-precision forms (reg and m256 across both 128-bit lanes)
vmovups 0(%rsp), %ymm12
vmovups 32(%rsp), %ymm13
vaddsubps %ymm13, %ymm12, %ymm12
vhaddps 0(%rsp), %ymm13, %ymm13
vhsubps 32(%rsp), %ymm12, %ymm12

# VEX 256-bit double-precision forms (reg and m256 across both 128-bit lanes)
vmovups 64(%rsp), %ymm14
vmovups 96(%rsp), %ymm15
vaddsubpd %ymm15, %ymm14, %ymm14
vhaddpd 64(%rsp), %ymm15, %ymm15
vhsubpd 96(%rsp), %ymm14, %ymm14

addq $0x100, %rsp
