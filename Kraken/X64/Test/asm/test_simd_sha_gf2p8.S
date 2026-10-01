# Test: SHA and GF(2^8) instructions (from test_simd_crypto.S)

subq $0x80, %rsp

# Data at 0..31(%rsp) (as left by the AES test in test_simd_aes.S)
movabsq $0x8d305a88a8f64332, %rax
movq %rax, 0(%rsp)
movabsq $0x340737e0a2983131, %rax
movq %rax, 8(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 16(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 24(%rsp)
vmovups 0(%rsp), %ymm8
vmovups 0(%rsp), %ymm9

# sha1msg1, sha1msg2, sha1nexte, sha1rnds4
movabsq $0x0123456789abcdef, %rax
movq %rax, 32(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 40(%rsp)
movups 32(%rsp), %xmm5
movabsq $0x1111111122222222, %rax
movq %rax, 48(%rsp)
movabsq $0x3333333344444444, %rax
movq %rax, 56(%rsp)
movups 48(%rsp), %xmm6

sha1msg1 %xmm6, %xmm5
sha1msg1 48(%rsp), %xmm5
sha1msg2 %xmm6, %xmm5
sha1msg2 48(%rsp), %xmm5
sha1nexte %xmm6, %xmm5
sha1nexte 48(%rsp), %xmm5
sha1rnds4 $0, %xmm6, %xmm5
sha1rnds4 $1, %xmm6, %xmm5
sha1rnds4 $2, 48(%rsp), %xmm5
sha1rnds4 $3, 48(%rsp), %xmm5

# sha256msg1, sha256msg2
sha256msg1 %xmm6, %xmm5
sha256msg1 48(%rsp), %xmm5
sha256msg2 %xmm6, %xmm5
sha256msg2 48(%rsp), %xmm5

# gf2p8mulb, vgf2p8mulb
gf2p8mulb %xmm6, %xmm5
gf2p8mulb 48(%rsp), %xmm5
vgf2p8mulb %xmm6, %xmm5, %xmm0
vgf2p8mulb 48(%rsp), %xmm5, %xmm1
vgf2p8mulb %ymm9, %ymm8, %ymm2
vgf2p8mulb 0(%rsp), %ymm9, %ymm3

# gf2p8affineqb, vgf2p8affineqb
gf2p8affineqb $0x37, %xmm6, %xmm5
gf2p8affineqb $0x5a, 48(%rsp), %xmm5
vgf2p8affineqb $0x37, %xmm6, %xmm5, %xmm4
vgf2p8affineqb $0x5a, 48(%rsp), %xmm5, %xmm7
vgf2p8affineqb $0x37, %ymm9, %ymm8, %ymm10
vgf2p8affineqb $0x5a, 0(%rsp), %ymm9, %ymm11

# gf2p8affineinvqb, vgf2p8affineinvqb
gf2p8affineinvqb $0x37, %xmm6, %xmm5
gf2p8affineinvqb $0x5a, 48(%rsp), %xmm5
vgf2p8affineinvqb $0x37, %xmm6, %xmm5, %xmm12
vgf2p8affineinvqb $0x5a, 48(%rsp), %xmm5, %xmm13
vgf2p8affineinvqb $0x37, %ymm9, %ymm8, %ymm14
vgf2p8affineinvqb $0x5a, 0(%rsp), %ymm9, %ymm15

addq $0x80, %rsp
