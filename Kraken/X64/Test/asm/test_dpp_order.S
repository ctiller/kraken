# Regression: dpps/dppd add the products pairwise, (p0+p1)+(p2+p3), which is observable
# through rounding and through the sign of an all-negative-zero sum.

subq $0x40, %rsp
movl $0x3f800000, %eax           # 1.0f, 0.0f
movq %rax, 0(%rsp)
movabsq $0x3380000033800000, %rax   # 2^-24f, 2^-24f
movq %rax, 8(%rsp)
movabsq $0x3f8000003f800000, %rax   # 1.0f x 2
movq %rax, 16(%rsp)
movq %rax, 24(%rsp)
movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
movaps %xmm0, %xmm2
dpps $0xf1, %xmm1, %xmm2            # rounds to 0x3f800001 only when summed pairwise

movabsq $0xbf800000bf800000, %rax   # -1.0f x 2
movq %rax, 32(%rsp)
movq %rax, 40(%rsp)
movups 32(%rsp), %xmm3
xorps %xmm4, %xmm4
dpps $0xf1, %xmm4, %xmm3            # -0 + -0 + -0 + -0 = -0

movabsq $0xbff0000000000000, %rax   # -1.0
movq %rax, 48(%rsp)
movq %rax, 56(%rsp)
movups 48(%rsp), %xmm5
xorpd %xmm6, %xmm6
dppd $0x31, %xmm6, %xmm5            # -0 + -0 = -0
addq $0x40, %rsp
