# Test: SimdFp scalar floating-point operations
# Tests scalar single and double precision add/sub/mul/div/min/max/sqrt/cvt (SSE and VEX)
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

# Test scalar single precision add/sub/mul/div (SSE, reg and m32)
movaps 0(%rsp), %xmm0
movaps 16(%rsp), %xmm1
addss 48(%rsp), %xmm0
subss 32(%rsp), %xmm0
mulss 32(%rsp), %xmm0
divss 48(%rsp), %xmm0

# Test scalar single precision min/max/sqrt (SSE, reg and m32)
movaps 0(%rsp), %xmm2
minss %xmm1, %xmm2
maxss 32(%rsp), %xmm2
minss 48(%rsp), %xmm2

movaps 48(%rsp), %xmm3
sqrtss %xmm3, %xmm3
sqrtss 32(%rsp), %xmm3

# Test scalar single/double conversions cvtss2sd and cvtsd2ss (SSE, reg and mem)
movaps 16(%rsp), %xmm4
cvtss2sd 32(%rsp), %xmm4
addsd 112(%rsp), %xmm4
cvtsd2ss %xmm4, %xmm4

movaps 32(%rsp), %xmm5
cvtsd2ss 96(%rsp), %xmm5
cvtss2sd 12(%rsp), %xmm5

# Test scalar double precision add/sub/mul/div (SSE, reg and m64)
movaps 64(%rsp), %xmm6
movaps 80(%rsp), %xmm7
addsd 96(%rsp), %xmm6
subsd 112(%rsp), %xmm6
mulsd %xmm6, %xmm6
divsd 96(%rsp), %xmm6

# Test scalar double precision min/max/sqrt (SSE, reg and m64)
movaps 64(%rsp), %xmm8
minsd %xmm7, %xmm8
maxsd 96(%rsp), %xmm8
minsd 112(%rsp), %xmm8
sqrtsd %xmm8, %xmm8

vmovups 0(%rsp), %ymm9
sqrtsd 96(%rsp), %xmm9

# Test VEX scalar single precision forms (reg and m32, upper lane copy and YMM zeroing)
vmovups 0(%rsp), %ymm10
vaddss 48(%rsp), %xmm0, %xmm10
vsubss 32(%rsp), %xmm10, %xmm10
vmulss %xmm2, %xmm10, %xmm10
vdivss 48(%rsp), %xmm10, %xmm10

# Test VEX scalar double precision forms (reg and m64)
vaddsd 112(%rsp), %xmm6, %xmm11
vsubsd %xmm7, %xmm11, %xmm11
vmulsd 96(%rsp), %xmm11, %xmm11
vdivsd 112(%rsp), %xmm11, %xmm11

# Test VEX vminss/vmaxss/vsqrtss (including negative input -> default QNaN)
vminss 16(%rsp), %xmm0, %xmm12
vmaxss 48(%rsp), %xmm12, %xmm12
vsqrtss %xmm12, %xmm1, %xmm12
vsqrtss 36(%rsp), %xmm12, %xmm13

# Test VEX vminsd/vmaxsd/vsqrtsd (including SNaN quieting)
vminsd 80(%rsp), %xmm6, %xmm14
vmaxsd 96(%rsp), %xmm14, %xmm14
vsqrtsd 96(%rsp), %xmm7, %xmm14
vsqrtsd 88(%rsp), %xmm14, %xmm14

# Test VEX vcvtss2sd/vcvtsd2ss (denormal, negative, reg and m32/m64)
vcvtss2sd 44(%rsp), %xmm7, %xmm15
vcvtsd2ss %xmm15, %xmm1, %xmm15
vcvtsd2ss 120(%rsp), %xmm15, %xmm1
vcvtss2sd %xmm1, %xmm6, %xmm15

addq $0x100, %rsp
