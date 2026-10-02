# Test: SIMD to GPR (SimdToGprOp): pmovmskb, movmskps, movmskpd, cvtss2si, cvttss2si, cvtsd2si,
# cvttsd2si. Each result is also stored to 64..215(%rsp), which is read back into ymm4-8 at the end
# so that results whose register is reused reach the final state. The extract and insert families
# are in test_simd_insert_mov.S.

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

# pmovmskb (legacy and VEX)
pmovmskb %xmm0, %eax
movl %eax, 64(%rsp)
vpmovmskb %xmm0, %r8
movq %r8, 72(%rsp)

# movmskps
movmskps %xmm1, %ebx
movl %ebx, 80(%rsp)
vmovmskps %xmm1, %r9
movq %r9, 88(%rsp)

# movmskpd
movmskpd %xmm2, %ecx
movl %ecx, 96(%rsp)
vmovmskpd %xmm2, %r10
movq %r10, 104(%rsp)

# cvtss2si and cvttss2si (32-bit and 64-bit dst, reg and mem)
cvtss2si %xmm1, %edx
movl %edx, 112(%rsp)
cvtss2si %xmm1, %r11
movq %r11, 120(%rsp)
cvtss2si 16(%rsp), %r12
movq %r12, 128(%rsp)
vcvtss2si %xmm1, %r13
movq %r13, 136(%rsp)
vcvtss2si 20(%rsp), %edi
movl %edi, 144(%rsp)

# NaN case -> saturation to indefinite (0x80000000 or 0x8000000000000000)
cvttss2si 28(%rsp), %esi
movl %esi, 152(%rsp)
vcvttss2si 28(%rsp), %r14
movq %r14, 160(%rsp)

# cvtsd2si and cvttsd2si (32-bit and 64-bit dst, reg and mem)
cvtsd2si %xmm2, %ebp
movl %ebp, 168(%rsp)
cvtsd2si %xmm2, %r15
movq %r15, 176(%rsp)
vcvtsd2si 40(%rsp), %eax
movl %eax, 184(%rsp)
vcvtsd2si 40(%rsp), %rbx
movq %rbx, 192(%rsp)

# NaN and double overflow -> saturation
cvttsd2si 48(%rsp), %rcx
movq %rcx, 200(%rsp)
vcvtsd2si 56(%rsp), %edx
movl %edx, 208(%rsp)

# Read the stored results back.
vmovdqu 64(%rsp), %ymm4
vmovdqu 96(%rsp), %ymm5
vmovdqu 128(%rsp), %ymm6
vmovdqu 160(%rsp), %ymm7
vmovdqu 192(%rsp), %ymm8

addq $0x100, %rsp
