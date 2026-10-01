# Test: F16C instructions (vcvtph2ps, vcvtps2ph)
# Results that a later instruction overwrites are first folded into %ymm10 with
# `vaesenc %ymmN, %ymm10, %ymm10` (unlike xor, equal results don't cancel), so that every
# result reaches the final state.

subq $0x80, %rsp

# Setup half-precision test vectors in (%rsp)
# 0x0000 (+0), 0x8000 (-0), 0x3c00 (1.0), 0xbc00 (-1.0)
movabsq $0xbc003c0080000000, %rax
movq %rax, 0(%rsp)
# 0x7c00 (+inf), 0xfc00 (-inf), 0x7c01 (SNaN), 0x7e00 (QNaN)
movabsq $0x7e007c01fc007c00, %rax
movq %rax, 8(%rsp)
# 0x0001 (min subnormal), 0x03ff (max subnormal), 0x0400 (min normal), 0x7bff (max normal)
movabsq $0x7bff040003ff0001, %rax
movq %rax, 16(%rsp)
# More subnormals and NaNs
movabsq $0x7fff020000020000, %rax
movq %rax, 24(%rsp)

# Load half-floats into xmm0 and xmm1
vmovups 0(%rsp), %xmm0
vmovups 16(%rsp), %xmm1

# vcvtph2ps: xmm -> xmm
vcvtph2ps %xmm0, %xmm2
vaesenc %ymm2, %ymm10, %ymm10
vcvtph2ps 0(%rsp), %xmm3
vaesenc %ymm3, %ymm10, %ymm10
vcvtph2ps %xmm1, %xmm4
vaesenc %ymm4, %ymm10, %ymm10
vcvtph2ps 16(%rsp), %xmm5
vaesenc %ymm5, %ymm10, %ymm10

# vcvtph2ps: xmm -> ymm
vcvtph2ps %xmm0, %ymm6
vaesenc %ymm6, %ymm10, %ymm10
vcvtph2ps 0(%rsp), %ymm7
vaesenc %ymm7, %ymm10, %ymm10
vcvtph2ps %xmm1, %ymm8
vcvtph2ps 16(%rsp), %ymm9

# Setup single-precision test vectors in 32(%rsp)
# 1.0f (0x3f800000), -2.0f (0xc0000000), 100000.0f (0x47c35000), 1e-6f (0x358637bd)
movabsq $0xc00000003f800000, %rax
movq %rax, 32(%rsp)
movabsq $0x358637bd47c35000, %rax
movq %rax, 40(%rsp)
# 1.00048828125f (0x3f801000), -100000.0f (0xc7c35000), +inf (0x7f800000), QNaN (0x7fc00000)
movabsq $0xc7c350003f801000, %rax
movq %rax, 48(%rsp)
movabsq $0x7fc000007f800000, %rax
movq %rax, 56(%rsp)

vmovups 32(%rsp), %ymm11

# vcvtps2ph: xmm -> xmm (modes 0, 1, 2, 3, 4)
vcvtps2ph $0, %xmm11, %xmm12
vcvtps2ph $1, %xmm11, %xmm13
vcvtps2ph $2, %xmm11, %xmm14
vcvtps2ph $3, %xmm11, %xmm15
vcvtps2ph $4, %xmm11, %xmm0

# vcvtps2ph: xmm -> mem (m64)
vcvtps2ph $0, %xmm11, 64(%rsp)
vmovq 64(%rsp), %xmm1

# vcvtps2ph: ymm -> xmm (modes 0, 1, 2, 3, 4)
vcvtps2ph $0, %ymm11, %xmm2
vcvtps2ph $1, %ymm11, %xmm3
vcvtps2ph $2, %ymm11, %xmm4
vcvtps2ph $3, %ymm11, %xmm5
vcvtps2ph $4, %ymm11, %xmm6

# vcvtps2ph: ymm -> mem (m128)
vcvtps2ph $0, %ymm11, 64(%rsp)
vmovups 64(%rsp), %xmm7

addq $0x80, %rsp
