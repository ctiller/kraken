# Test: vzeroall and vzeroupper (from test_simd_moves.S). ymm8-15 show vzeroall's zeros;
# ymm0-7, refilled afterwards, show vzeroupper zeroing bits 255:128 and keeping xmm0-7.
subq $0x40, %rsp

movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x1122334455667788, %rax
movq %rax, 16(%rsp)
movabsq $0x99aabbccddeeff00, %rax
movq %rax, 24(%rsp)
movq %rax, 32(%rsp)

vmovups 0(%rsp), %ymm8
vmovups 8(%rsp), %ymm9
vpcmpeqd %ymm10, %ymm10, %ymm10
vmovups 0(%rsp), %ymm11
vmovups 8(%rsp), %ymm12
vpcmpeqd %ymm13, %ymm13, %ymm13
vmovups 0(%rsp), %ymm14
vmovups 8(%rsp), %ymm15
vzeroall

vmovups 0(%rsp), %ymm0
vmovups 8(%rsp), %ymm1
vpcmpeqd %ymm2, %ymm2, %ymm2
vmovups 0(%rsp), %ymm3
vmovups 8(%rsp), %ymm4
vpcmpeqd %ymm5, %ymm5, %ymm5
vmovups 0(%rsp), %ymm6
vmovups 8(%rsp), %ymm7
vzeroupper

addq $0x40, %rsp
