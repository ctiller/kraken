# Test: SimdInsertOp: movlps, movhps, movlpd, movhpd (memory source), movd, movq (GPR source)
# (from test_simd_gpr.S)

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

movl $0x89abcdef, %eax
movl $0x80000001, %ebx
movabsq $0xfedcba9876543210, %rcx
movabsq $0x0123456789abcdef, %rdx

# movlps, movhps, movlpd, movhpd (mem src)
movlps 0(%rsp), %xmm1
vmovlps 8(%rsp), %xmm1, %xmm2
movhps 16(%rsp), %xmm1
vmovhps 24(%rsp), %xmm1, %xmm3
movlpd 32(%rsp), %xmm1
vmovlpd 40(%rsp), %xmm1, %xmm4
movhpd 48(%rsp), %xmm1
vmovhpd 56(%rsp), %xmm1, %xmm5

# movd and movq (reg src to vector dst)
movd %eax, %xmm6
vmovd %ebx, %xmm7
movq %rcx, %xmm8
vmovq %rdx, %xmm9

addq $0x100, %rsp
