# Test: variable blends and fused multiply-adds
subq $0x60, %rsp
# floats: 1.5, -2.0, 3.0e38, 1.0e-45 (denormal)
movabsq $0xc00000003fc00000, %rax
movq %rax, 0(%rsp)
movabsq $0x000000017f61b1e6, %rax
movq %rax, 8(%rsp)
# floats: 0x1.000002p0, 0x1.fffffep-1, -0.0, inf
movabsq $0x3f7fffff3f800001, %rax
movq %rax, 16(%rsp)
movabsq $0x7f80000080000000, %rax
movq %rax, 24(%rsp)
# doubles: 1/3, -1e308
movabsq $0x3fd5555555555555, %rax
movq %rax, 32(%rsp)
movabsq $0xffe1ccf385ebc8a0, %rax
movq %rax, 40(%rsp)
movups 0(%rsp), %xmm1
movups 16(%rsp), %xmm2
movups 32(%rsp), %xmm3
vmovups 0(%rsp), %ymm4
vmovups 16(%rsp), %ymm5
# blends
movaps %xmm2, %xmm0
movaps %xmm1, %xmm6
pblendvb %xmm0, %xmm3, %xmm6
movaps %xmm1, %xmm7
blendvps %xmm0, 32(%rsp), %xmm7
movaps %xmm1, %xmm8
blendvpd %xmm0, %xmm2, %xmm8
vpblendvb %ymm5, %ymm4, %ymm5, %ymm9
vblendvps %xmm1, %xmm2, %xmm3, %xmm10
vblendvpd %ymm4, (%rsp), %ymm5, %ymm11
sha256rnds2 %xmm0, %xmm3, %xmm6
sha256rnds2 %xmm0, 0(%rsp), %xmm7
# fma: products that need the single rounding
vmovaps %xmm2, %xmm12
vfmadd231ps %xmm2, %xmm2, %xmm12
vmovaps %xmm1, %xmm13
vfnmadd132ps 16(%rsp), %xmm2, %xmm13
vmovaps %ymm4, %ymm14
vfmaddsub213ps %ymm5, %ymm4, %ymm14
vmovaps %xmm3, %xmm15
vfmsub231pd %xmm3, %xmm3, %xmm15
vmovaps %xmm3, %xmm0
vfnmsub213sd 32(%rsp), %xmm3, %xmm0
# (ymm4 and ymm5 are no longer needed as inputs; xmm6 and xmm7 hold the sha256rnds2 results.)
vmovaps %xmm1, %xmm4
vfmadd132ss %xmm2, %xmm1, %xmm4
vmovaps %xmm1, %xmm5
vfmsubadd231pd %xmm2, %xmm3, %xmm5
addq $0x60, %rsp
