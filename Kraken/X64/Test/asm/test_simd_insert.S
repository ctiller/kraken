# Test: SimdInsertOp: pinsrb, pinsrw, pinsrd, pinsrq, cvtsi2ss, cvtsi2sd (from test_simd_gpr.S).
# The VEX cvtsi2ss/cvtsi2sd results that the next one overwrites are first folded into %ymm3
# with vaesenc (unlike xor, equal results don't cancel), so that every result reaches the final state.

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

# GPR sources (in test_simd_gpr.S these were extraction results)
movabsq $0xfedcba9876543210, %rax
movq $0xc3, %r8
movq $0xbeef, %rbx
movq $0x1234, %r9
movl $0x89abcdef, %ecx
movl $0x76543210, %r10d
movabsq $0x0123456789abcdef, %r11
movabsq $0x8000000000000001, %r12
movl $0xffffff85, %edx            # -123 as a dword
movabsq $0x7fffffffffffffff, %r13
movl $0x01000001, %edi            # 2^24 + 1 (rounds as a float)
movq $-256, %r14
movl $0x80000000, %esi
movabsq $0x0020000000000001, %rbp # 2^53 + 1 (rounds as a double)
movl $0x7fffffff, %r15d

# pinsrb, pinsrw, pinsrd, pinsrq (reg and mem src)
pinsrb $2, %eax, %xmm4
pinsrb $4, 0(%rsp), %xmm4
vpinsrb $6, %r8d, %xmm4, %xmm5
vpinsrb $1, 1(%rsp), %xmm4, %xmm6

pinsrw $1, %ebx, %xmm4
pinsrw $3, 2(%rsp), %xmm4
vpinsrw $2, %r9d, %xmm4, %xmm7
vpinsrw $0, 4(%rsp), %xmm4, %xmm8

pinsrd $1, %ecx, %xmm4
pinsrd $2, 8(%rsp), %xmm4
vpinsrd $3, %r10d, %xmm4, %xmm9
vpinsrd $0, 12(%rsp), %xmm4, %xmm10

pinsrq $1, %r11, %xmm4
pinsrq $0, 16(%rsp), %xmm4
vpinsrq $0, %r12, %xmm4, %xmm11
vpinsrq $1, 24(%rsp), %xmm4, %xmm12

# cvtsi2ss and cvtsi2sd (reg and mem src, 32-bit and 64-bit GPR)
cvtsi2ss %edx, %xmm13
cvtsi2ss %r13, %xmm13
cvtsi2ssl 0(%rsp), %xmm13
cvtsi2ssq 8(%rsp), %xmm13
vcvtsi2ss %edi, %xmm13, %xmm14
vaesenc %ymm14, %ymm3, %ymm3
vcvtsi2ss %r14, %xmm13, %xmm14
vaesenc %ymm14, %ymm3, %ymm3
vcvtsi2ssl 12(%rsp), %xmm13, %xmm14
vaesenc %ymm14, %ymm3, %ymm3
vcvtsi2ssq 16(%rsp), %xmm13, %xmm14

cvtsi2sd %esi, %xmm15
cvtsi2sd %rbp, %xmm15
cvtsi2sdl 0(%rsp), %xmm15
cvtsi2sdq 8(%rsp), %xmm15
vcvtsi2sd %r15d, %xmm15, %xmm0
vaesenc %ymm0, %ymm3, %ymm3
vcvtsi2sd %rax, %xmm15, %xmm0
vaesenc %ymm0, %ymm3, %ymm3
vcvtsi2sdl 20(%rsp), %xmm15, %xmm0
vaesenc %ymm0, %ymm3, %ymm3
vcvtsi2sdq 24(%rsp), %xmm15, %xmm0

addq $0x100, %rsp
