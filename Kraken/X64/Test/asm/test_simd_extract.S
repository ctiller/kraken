# Test: SimdExtractOp: pextrb, pextrw, pextrd, pextrq, extractps, movd, movq, movlps, movhps,
# movlpd, movhpd (from test_simd_gpr.S). The memory results are read back into ymm4-9 at the end.

subq $0x100, %rsp

# Setup some distinct patterns in memory
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x3f80000040000000, %rax   # 1.0f, 2.0f
movq %rax, 16(%rsp)
movabsq $0xc08000007fc00000, %rax   # -4.0f, NaN (float32)
movq %rax, 24(%rsp)
movabsq $0x3ff0000000000000, %rax   # 1.0 (double)
movq %rax, 32(%rsp)
movabsq $0xc014000000000000, %rax   # -5.0 (double)
movq %rax, 40(%rsp)
movabsq $0x7ff8000000000000, %rax   # NaN (double)
movq %rax, 48(%rsp)
movabsq $0x41e0000000000000, %rax   # 2^31 (double overflow 32-bit int)
movq %rax, 56(%rsp)

movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
movups 32(%rsp), %xmm2
movups 48(%rsp), %xmm3

# Zero the result area, whose bytes between the stores are read back too.
vpxor %xmm4, %xmm4, %xmm4
vmovdqu %ymm4, 64(%rsp)
vmovdqu %ymm4, 96(%rsp)
vmovdqu %ymm4, 128(%rsp)
vmovdqu %ymm4, 160(%rsp)
vmovdqu %ymm4, 192(%rsp)
vmovdqu %ymm4, 224(%rsp)

# pextrb (reg and mem dst, legacy and VEX)
pextrb $1, %xmm0, %eax
pextrb $3, %xmm0, 216(%rsp)
vpextrb $5, %xmm0, %r8
vpextrb $7, %xmm0, 217(%rsp)

# pextrw (reg and mem dst, legacy and VEX)
pextrw $2, %xmm0, %ebx
pextrw $1, %xmm0, 218(%rsp)
vpextrw $3, %xmm0, %r9
vpextrw $0, %xmm0, 220(%rsp)

# pextrd and pextrq (reg and mem dst, legacy and VEX)
pextrd $1, %xmm0, %ecx
pextrd $2, %xmm0, 224(%rsp)
vpextrd $0, %xmm0, %r10d
vpextrd $3, %xmm0, 228(%rsp)

pextrq $0, %xmm0, %r11
pextrq $1, %xmm0, 232(%rsp)
vpextrq $1, %xmm0, %r12
vpextrq $0, %xmm0, 240(%rsp)

# extractps
extractps $1, %xmm1, %edx
extractps $0, %xmm1, 248(%rsp)
vextractps $2, %xmm1, %r13
vextractps $3, %xmm1, 252(%rsp)

# movd and movq (extract to reg and mem)
movd %xmm0, %edi
movd %xmm0, 64(%rsp)
vmovd %xmm0, %esi
vmovd %xmm0, 68(%rsp)

movq %xmm0, %rbp
movq %xmm0, 72(%rsp)
vmovq %xmm0, %r14
vmovq %xmm0, 80(%rsp)

# movlps, movhps, movlpd, movhpd (mem dst)
movlps %xmm0, 88(%rsp)
vmovlps %xmm0, 96(%rsp)
movhps %xmm0, 104(%rsp)
vmovhps %xmm0, 112(%rsp)
movlpd %xmm2, 120(%rsp)
vmovlpd %xmm2, 128(%rsp)
movhpd %xmm2, 136(%rsp)
vmovhpd %xmm2, 144(%rsp)

# Read the stored results back.
vmovdqu 64(%rsp), %ymm4
vmovdqu 96(%rsp), %ymm5
vmovdqu 128(%rsp), %ymm6
vmovdqu 160(%rsp), %ymm7
vmovdqu 192(%rsp), %ymm8
vmovdqu 224(%rsp), %ymm9

addq $0x100, %rsp
