# Test: GF(2^8) byte multiplication
# Requires: gfni

subq $0x80, %rsp

# Data at 0..31(%rsp)
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

# xmm5 and xmm6 operands, and 48(%rsp) memory operand
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

# gf2p8mulb, vgf2p8mulb
gf2p8mulb %xmm6, %xmm5
gf2p8mulb 48(%rsp), %xmm5
vgf2p8mulb %xmm6, %xmm5, %xmm0
vgf2p8mulb 48(%rsp), %xmm5, %xmm1
vgf2p8mulb %ymm9, %ymm8, %ymm2
vgf2p8mulb 0(%rsp), %ymm9, %ymm3

addq $0x80, %rsp
