# Test: vextracti128 / vextractf128 and vinserti128 / vinsertf128 (from test_simd_moves.S)
subq $0x80, %rsp

movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x1122334455667788, %rax
movq %rax, 16(%rsp)
movabsq $0x99aabbccddeeff00, %rax
movq %rax, 24(%rsp)

vmovups 0(%rsp), %ymm0
vextracti128 $0, %ymm0, %xmm1
vextracti128 $1, %ymm0, %xmm2
vextracti128 $1, %ymm0, 56(%rsp)
vextractf128 $0, %ymm0, 72(%rsp)
vextractf128 $1, %ymm0, %xmm3

vinserti128 $0, %xmm1, %ymm0, %ymm4
vinserti128 $1, %xmm2, %ymm0, %ymm5
vinserti128 $0, 56(%rsp), %ymm0, %ymm6
vinsertf128 $1, %xmm3, %ymm0, %ymm7
vinsertf128 $0, 72(%rsp), %ymm0, %ymm8

addq $0x80, %rsp
