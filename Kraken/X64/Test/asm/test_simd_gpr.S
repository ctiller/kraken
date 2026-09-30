# Test: SIMD to GPR, extract, and insert families
# SimdToGprOp: pmovmskb, movmskps, movmskpd, cvtss2si, cvttss2si, cvtsd2si, cvttsd2si
# SimdExtractOp: pextrb, pextrw, pextrd, pextrq, extractps, movd, movq, movlps, movhps, movlpd, movhpd
# SimdInsertOp: pinsrb, pinsrw, pinsrd, pinsrq, cvtsi2ss, cvtsi2sd, movlps, movhps, movlpd, movhpd, movd, movq

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

# --- 1. SimdToGprOp tests ---
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

# --- 2. SimdExtractOp tests ---
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

# --- 3. SimdInsertOp tests ---
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
vcvtsi2ss %r14, %xmm13, %xmm14
vcvtsi2ssl 12(%rsp), %xmm13, %xmm14
vcvtsi2ssq 16(%rsp), %xmm13, %xmm14

cvtsi2sd %esi, %xmm15
cvtsi2sd %rbp, %xmm15
cvtsi2sdl 0(%rsp), %xmm15
cvtsi2sdq 8(%rsp), %xmm15
vcvtsi2sd %r15d, %xmm15, %xmm0
vcvtsi2sd %rax, %xmm15, %xmm0
vcvtsi2sdl 20(%rsp), %xmm15, %xmm0
vcvtsi2sdq 24(%rsp), %xmm15, %xmm0

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
