# Test: flag-setting SIMD ops (ptest, vtestps/pd, (u)comis[sd])
subq $0x40, %rsp
movabsq $0x8000000000000000, %rax
movq %rax, 0(%rsp)
movabsq $0x00000000ffffffff, %rax
movq %rax, 8(%rsp)
movabsq $0x7fffffff7ff80000, %rax
movq %rax, 16(%rsp)
movabsq $0x3f8000003ff00000, %rax
movq %rax, 24(%rsp)
movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
pxor %xmm2, %xmm2
ptest %xmm0, %xmm0
setz %al
setc %bl
ptest %xmm2, %xmm0
setz %cl
setc %dl
vptest 16(%rsp), %xmm0
sete %sil
setb %dil
vmovups 0(%rsp), %ymm3
vtestps %ymm3, %ymm3
setz %r8b
setc %r9b
vtestpd %xmm0, %xmm1
setz %r10b
setc %r11b
ucomiss %xmm1, %xmm0
setp %r12b
setz %r13b
setc %r14b
comiss %xmm0, %xmm2
setz %r15b
setc %bpl
ucomisd %xmm2, %xmm1
seta %ah
vucomiss 28(%rsp), %xmm2
setb %bh
vcomisd 24(%rsp), %xmm1
setbe %ch
ucomisd %xmm2, %xmm2
setnp %dh
addq $0x40, %rsp
