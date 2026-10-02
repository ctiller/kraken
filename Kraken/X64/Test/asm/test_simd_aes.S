# Test: AES round instructions
# Requires: vaes
# Results that a later instruction overwrites are first folded into %ymm15 with vaesenc
# (unlike xor, equal results don't cancel), so that every result reaches the final state.

subq $0x80, %rsp

# Set up test data
# Known AES FIPS 197 test vector:
# Key = 2b7e151628aed2a6abf7158809cf4f3c
# PT  = 3243f6a8885a308d313198a2e0370734
# CT  = 3925841d02dc09fbdc118597196a0b32
movabsq $0x8d305a88a8f64332, %rax
movq %rax, 0(%rsp)
movabsq $0x340737e0a2983131, %rax
movq %rax, 8(%rsp)
movups 0(%rsp), %xmm0

# RK0
movabsq $0xa6d2ae2816157e2b, %rax
movq %rax, 16(%rsp)
movabsq $0x3c4fcf098815f7ab, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
pxor %xmm1, %xmm0

# RK1
movabsq $0xb12c548817fefaa0, %rax
movq %rax, 16(%rsp)
movabsq $0x05766c2a3939a323, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
aesenc %xmm1, %xmm0

# RK2
movabsq $0x43b9967af295c2f2, %rax
movq %rax, 16(%rsp)
movabsq $0x7ff659737a803559, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
vaesenc %xmm1, %xmm0, %xmm0

# RK3
movabsq $0x3efe16477d47803d, %rax
movq %rax, 16(%rsp)
movabsq $0x3b887a6d447e231e, %rax
movq %rax, 24(%rsp)
aesenc 16(%rsp), %xmm0

# RK4
movabsq $0x7f5b52a841a544ef, %rax
movq %rax, 16(%rsp)
movabsq $0x00ad0bdb3b2571b6, %rax
movq %rax, 24(%rsp)
vaesenc 16(%rsp), %xmm0, %xmm0

# RK5
movabsq $0x879d837cf8c6d1d4, %rax
movq %rax, 16(%rsp)
movabsq $0xbc15f911bcb8f2ca, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
aesenc %xmm1, %xmm0

# RK6
movabsq $0xfd3e0b117aa3886d, %rax
movq %rax, 16(%rsp)
movabsq $0xfd9300ca4186f9db, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
vaesenc %xmm1, %xmm0, %xmm0

# RK7
movabsq $0xf3c95f5f0ef7544e, %rax
movq %rax, 16(%rsp)
movabsq $0x4fdca64eb24fa684, %rax
movq %rax, 24(%rsp)
aesenc 16(%rsp), %xmm0

# RK8
movabsq $0xd2ba8db52173d2ea, %rax
movq %rax, 16(%rsp)
movabsq $0x2f298d7f60f52b31, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
aesenc %xmm1, %xmm0

# RK9
movabsq $0x21dcfa19f36677ac, %rax
movq %rax, 16(%rsp)
movabsq $0x6e005c574129d128, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
vaesenc %xmm1, %xmm0, %xmm0

# RK10
movabsq $0x8925eec9a8f914d0, %rax
movq %rax, 16(%rsp)
movabsq $0xa60c63b6c80c3fe1, %rax
movq %rax, 24(%rsp)
movups 16(%rsp), %xmm1
aesenclast %xmm1, %xmm0

# Now test aesdec, aesdeclast, vaesdec, vaesdeclast
movups %xmm0, %xmm2
vaesenclast 16(%rsp), %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
aesdec %xmm1, %xmm2
vaesdec %xmm1, %xmm2, %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vaesdec 16(%rsp), %xmm2, %xmm5
aesdeclast %xmm1, %xmm2
vaesdeclast %xmm1, %xmm2, %xmm6
vaesdeclast 16(%rsp), %xmm2, %xmm7

# 256-bit VAES: vaesenc, vaesenclast, vaesdec, vaesdeclast
# Set up 32 bytes at 0(%rsp)..31(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 16(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 24(%rsp)
vmovups 0(%rsp), %ymm8
vmovups 0(%rsp), %ymm9
vaesenc %ymm9, %ymm8, %ymm10
vaesenclast %ymm9, %ymm8, %ymm11
vaesdec %ymm9, %ymm8, %ymm12
vaesdeclast %ymm9, %ymm8, %ymm13
vaesenc 0(%rsp), %ymm9, %ymm14

addq $0x80, %rsp
