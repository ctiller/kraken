# Test: GF(2^8) affine transforms
# Exercises: gf2p8affineqb, gf2p8affineinvqb
# Requires: gfni

subq $0x80, %rsp

# Data bytes at 0..31(%rsp)
movabsq $0x8d305a88a8f64332, %rax
movq %rax, 0(%rsp)
movabsq $0x340737e0a2983131, %rax
movq %rax, 8(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 16(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 24(%rsp)
vmovups 0(%rsp), %ymm8

# One 8x8 bit matrix per qword at 32..63(%rsp): identity, bit reversal, and two dense matrices
movabsq $0x0102040810204080, %rax
movq %rax, 32(%rsp)
movabsq $0x8040201008040201, %rax
movq %rax, 40(%rsp)
movabsq $0x1f3e7cf8f0e1c387, %rax
movq %rax, 48(%rsp)
movabsq $0xa5c33c5af00f6996, %rax
movq %rax, 56(%rsp)
vmovups 32(%rsp), %ymm9

# Legacy forms transform the destination in place, so each starts from a copy of the data
vmovups %ymm8, %ymm10
gf2p8affineqb $0x37, %xmm9, %xmm10
vmovups %ymm8, %ymm11
gf2p8affineqb $0x5a, 48(%rsp), %xmm11
vmovups %ymm8, %ymm12
gf2p8affineinvqb $0x37, %xmm9, %xmm12
vmovups %ymm8, %ymm13
gf2p8affineinvqb $0x5a, 48(%rsp), %xmm13

# VEX forms
vgf2p8affineqb $0x00, %xmm9, %xmm8, %xmm0
vgf2p8affineqb $0xff, 48(%rsp), %xmm8, %xmm1
vgf2p8affineqb $0x37, %ymm9, %ymm8, %ymm2
vgf2p8affineqb $0x5a, 32(%rsp), %ymm8, %ymm3
vgf2p8affineinvqb $0x00, %xmm9, %xmm8, %xmm4
vgf2p8affineinvqb $0xff, 48(%rsp), %xmm8, %xmm5
vgf2p8affineinvqb $0x37, %ymm9, %ymm8, %ymm6
vgf2p8affineinvqb $0x5a, 32(%rsp), %ymm8, %ymm7

addq $0x80, %rsp
