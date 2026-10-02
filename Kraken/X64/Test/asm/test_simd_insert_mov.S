# Test: SimdExtractOp (pextrb/w/d/q, extractps, movd/q XMM->GPR/mem, movlps/hps/lpd/hpd XMM->mem),
# SimdInsertOp (pinsrb/w/d/q, cvtsi2ss/sd suffixed and unsuffixed, movlps/hps/lpd/hpd mem->XMM,
# movd/q GPR->XMM), and 256-bit vpmovmskb/vmovmskps/vmovmskpd.

subq $0x100, %rsp

# Setup distinct patterns in memory
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

vmovdqu 0(%rsp), %ymm0
vmovdqu 32(%rsp), %ymm1
movups 16(%rsp), %xmm2

# Zero the memory result area (64..255(%rsp))
vpxor %xmm4, %xmm4, %xmm4
vmovdqu %ymm4, 64(%rsp)
vmovdqu %ymm4, 96(%rsp)
vmovdqu %ymm4, 128(%rsp)
vmovdqu %ymm4, 160(%rsp)
vmovdqu %ymm4, 192(%rsp)
vmovdqu %ymm4, 224(%rsp)

# 256-bit vpmovmskb, vmovmskps, vmovmskpd
vpmovmskb %ymm0, %eax
movl %eax, 152(%rsp)
vmovmskps %ymm0, %ebx
movl %ebx, 156(%rsp)
vmovmskpd %ymm1, %ecx
movl %ecx, 160(%rsp)

# SimdExtractOp: pextrb, pextrw, pextrd, pextrq, extractps (reg and mem dst, legacy and VEX)
pextrb $1, %xmm0, %eax
movl %eax, 164(%rsp)
pextrb $3, %xmm0, 216(%rsp)
vpextrb $5, %xmm0, %r8
movq %r8, 168(%rsp)
vpextrb $7, %xmm0, 217(%rsp)

pextrw $2, %xmm0, %ebx
movl %ebx, 176(%rsp)
pextrw $1, %xmm0, 218(%rsp)
vpextrw $3, %xmm0, %r9
movq %r9, 184(%rsp)
vpextrw $0, %xmm0, 220(%rsp)

pextrd $1, %xmm0, %ecx
movl %ecx, 192(%rsp)
pextrd $2, %xmm0, 224(%rsp)
vpextrd $0, %xmm0, %r10d
movl %r10d, 196(%rsp)
vpextrd $3, %xmm0, 228(%rsp)

pextrq $0, %xmm0, %r11
movq %r11, 200(%rsp)
pextrq $1, %xmm0, 232(%rsp)
vpextrq $1, %xmm0, %r12
movq %r12, 208(%rsp)
vpextrq $0, %xmm0, 240(%rsp)

extractps $1, %xmm2, %edx
extractps $0, %xmm2, 248(%rsp)
vextractps $2, %xmm2, %r13
vextractps $3, %xmm2, 252(%rsp)

# SimdExtractOp: movd and movq (XMM to GPR and memory)
movd %xmm0, %edi
movd %xmm0, 64(%rsp)
vmovd %xmm0, %esi
vmovd %xmm0, 68(%rsp)

movq %xmm0, %rbp
movq %xmm0, 72(%rsp)
vmovq %xmm0, %r14
vmovq %xmm0, 80(%rsp)

# SimdExtractOp: movlps, movhps, movlpd, movhpd (XMM to memory)
movlps %xmm0, 88(%rsp)
vmovlps %xmm0, 96(%rsp)
movhps %xmm0, 104(%rsp)
vmovhps %xmm0, 112(%rsp)
movlpd %xmm1, 120(%rsp)
vmovlpd %xmm1, 128(%rsp)
movhpd %xmm1, 136(%rsp)
vmovhpd %xmm1, 144(%rsp)

# SimdInsertOp: movlps, movhps, movlpd, movhpd (memory to XMM)
movlps 0(%rsp), %xmm1
vmovlps 8(%rsp), %xmm1, %xmm2
movhps 16(%rsp), %xmm1
vmovhps 24(%rsp), %xmm1, %xmm3
movlpd 32(%rsp), %xmm1
vmovlpd 40(%rsp), %xmm1, %xmm2
movhpd 48(%rsp), %xmm1
vmovhpd 56(%rsp), %xmm1, %xmm3

# SimdInsertOp: movd and movq (GPR to XMM)
movl $0x89abcdef, %eax
movl $0x80000001, %ebx
movabsq $0xfedcba9876543210, %rcx
movabsq $0x0123456789abcdef, %rdx
movd %eax, %xmm4
vmovd %ebx, %xmm5
movq %rcx, %xmm6
vmovq %rdx, %xmm7

# SimdInsertOp: pinsrb, pinsrw, pinsrd, pinsrq (reg and mem src)
pinsrb $2, %eax, %xmm4
pinsrb $4, 0(%rsp), %xmm4
vpinsrb $6, %ebx, %xmm4, %xmm5
vpinsrb $1, 1(%rsp), %xmm5, %xmm5

pinsrw $1, %eax, %xmm4
pinsrw $3, 2(%rsp), %xmm4
vpinsrw $2, %ebx, %xmm4, %xmm6
vpinsrw $0, 4(%rsp), %xmm6, %xmm6

pinsrd $1, %eax, %xmm4
pinsrd $2, 8(%rsp), %xmm4
vpinsrd $3, %ebx, %xmm4, %xmm7
vpinsrd $0, 12(%rsp), %xmm7, %xmm7

pinsrq $1, %rcx, %xmm4
pinsrq $0, 16(%rsp), %xmm4
vpinsrq $0, %rdx, %xmm4, %xmm8
vpinsrq $1, 24(%rsp), %xmm8, %xmm8

# SimdInsertOp: cvtsi2ss and cvtsi2sd (GPR and memory src, 32-bit/64-bit, suffixed and unsuffixed)
movl $0xffffff85, %edx            # -123 as a dword
movabsq $0x7fffffffffffffff, %r13
movl $0x01000001, %edi            # 2^24 + 1 (rounds as a float)
movq $-256, %r14
movl $0x80000000, %esi
movabsq $0x0020000000000001, %rbp # 2^53 + 1 (rounds as a double)
movl $0x7fffffff, %r15d
movabsq $0x0000000100000003, %rax # low dword 3, high dword 1 (tests unsuffixed 32-bit mem load)
movq %rax, 0(%rsp)

cvtsi2ss %edx, %xmm9
vpxor %xmm9, %xmm3, %xmm3
cvtsi2ss %r13, %xmm9
vpxor %xmm9, %xmm3, %xmm3
cvtsi2ssl 0(%rsp), %xmm9
vpxor %xmm9, %xmm3, %xmm3
cvtsi2ssq 0(%rsp), %xmm9
vpxor %xmm9, %xmm3, %xmm3
cvtsi2ss 0(%rsp), %xmm9           # unsuffixed memory source (32-bit)
vcvtsi2ss %edi, %xmm9, %xmm9
vpxor %xmm9, %xmm3, %xmm3
vcvtsi2ss %r14, %xmm9, %xmm9
vpxor %xmm9, %xmm3, %xmm3
vcvtsi2ssl 12(%rsp), %xmm9, %xmm9
vpxor %xmm9, %xmm3, %xmm3
vcvtsi2ssq 16(%rsp), %xmm9, %xmm9
vpxor %xmm9, %xmm3, %xmm3
vcvtsi2ss 0(%rsp), %xmm9, %xmm9   # unsuffixed memory source (32-bit)

cvtsi2sd %esi, %xmm10
vpxor %xmm10, %xmm3, %xmm3
cvtsi2sd %rbp, %xmm10
vpxor %xmm10, %xmm3, %xmm3
cvtsi2sdl 0(%rsp), %xmm10
vpxor %xmm10, %xmm3, %xmm3
cvtsi2sdq 0(%rsp), %xmm10
vpxor %xmm10, %xmm3, %xmm3
cvtsi2sd 0(%rsp), %xmm10          # unsuffixed memory source (32-bit)
vcvtsi2sd %r15d, %xmm10, %xmm10
vpxor %xmm10, %xmm3, %xmm3
vcvtsi2sd %rcx, %xmm10, %xmm10
vpxor %xmm10, %xmm3, %xmm3
vcvtsi2sdl 20(%rsp), %xmm10, %xmm10
vpxor %xmm10, %xmm3, %xmm3
vcvtsi2sdq 24(%rsp), %xmm10, %xmm10
vpxor %xmm10, %xmm3, %xmm3
vcvtsi2sd 0(%rsp), %xmm10, %xmm10 # unsuffixed memory source (32-bit)

# Read the stored extract results back into ymm11-15 and ymm0
vmovdqu 64(%rsp), %ymm11
vmovdqu 96(%rsp), %ymm12
vmovdqu 128(%rsp), %ymm13
vmovdqu 160(%rsp), %ymm14
vmovdqu 192(%rsp), %ymm15
vmovdqu 224(%rsp), %ymm0

addq $0x100, %rsp
