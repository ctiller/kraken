# Test: variable permutations (vpermd, vpermps, vpermilps, vpermilpd)
subq $0x40, %rsp
movabsq $0x0000000500000002, %rax
movq %rax, 0(%rsp)
movabsq $0x0000000f00000007, %rax
movq %rax, 8(%rsp)
movabsq $0x0000000300000000, %rax
movq %rax, 16(%rsp)
movabsq $0xfffffff900000001, %rax
movq %rax, 24(%rsp)
movabsq $0x1111111122222222, %rax
movq %rax, 32(%rsp)
movabsq $0x3333333344444444, %rax
movq %rax, 40(%rsp)
movabsq $0x5555555566666666, %rax
movq %rax, 48(%rsp)
movabsq $0x7777777788888888, %rax
movq %rax, 56(%rsp)
vmovups 0(%rsp), %ymm1
vmovups 32(%rsp), %ymm2
vpermd %ymm2, %ymm1, %ymm3
vpermps 32(%rsp), %ymm1, %ymm4
vpermilps %ymm1, %ymm2, %ymm5
vpermilps (%rsp), %xmm2, %xmm6
vpermilpd %ymm1, %ymm2, %ymm7
vpermilpd %xmm1, %xmm2, %xmm8
addq $0x40, %rsp
