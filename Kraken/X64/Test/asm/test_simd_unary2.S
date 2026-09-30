# Test: simd unary instructions part 2
subq $0x60, %rsp

# Setup memory buffer with interesting float / integer patterns:
# 0(%rsp): single float values: 1.0f (0x3f800000), -2.0f (0xc0000000), NaN (0x7fc00001), +inf (0x7f800000)
movabsq $0xc00000003f800000, %rax
movq %rax, 0(%rsp)
movabsq $0x7f8000007fc00001, %rax
movq %rax, 8(%rsp)

# 16(%rsp): double float values: 2.0 (0x4000000000000000), -4.0 (0xc010000000000000)
movabsq $0x4000000000000000, %rax
movq %rax, 16(%rsp)
movabsq $0xc010000000000000, %rax
movq %rax, 24(%rsp)

# 32(%rsp): more doubles: NaN, -0.0
movabsq $0x7ff8000000000001, %rax
movq %rax, 32(%rsp)
movabsq $0x8000000000000000, %rax
movq %rax, 40(%rsp)

# 48(%rsp): integer test patterns
movabsq $0x807f01fe02fd03fc, %rax
movq %rax, 48(%rsp)
movabsq $0x04fb05fa06f907f8, %rax
movq %rax, 56(%rsp)

# 64(%rsp): 16-bit words for phminposuw
movabsq $0x0005000400030002, %rax
movq %rax, 64(%rsp)
movabsq $0x0001000200030004, %rax
movq %rax, 72(%rsp)

movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
movups 48(%rsp), %xmm2
movups 64(%rsp), %xmm3

# 1. Widening pmovzx / pmovsx (legacy, VEX 128, VEX 256, reg and mem)
pmovzxbd %xmm2, %xmm4
vpmovzxbd %xmm2, %xmm4
vpmovzxbd 48(%rsp), %ymm5
pmovzxbq %xmm2, %xmm4
vpmovzxbq %xmm2, %xmm4
vpmovzxbq 48(%rsp), %ymm5
pmovzxwd %xmm2, %xmm4
vpmovzxwd %xmm2, %xmm4
vpmovzxwd 48(%rsp), %ymm5
pmovzxwq %xmm2, %xmm4
vpmovzxwq %xmm2, %xmm4
vpmovzxwq 48(%rsp), %ymm5
pmovzxdq %xmm2, %xmm4
vpmovzxdq %xmm2, %xmm4
vpmovzxdq 48(%rsp), %ymm5

pmovsxbw %xmm2, %xmm4
vpmovsxbw %xmm2, %xmm4
vpmovsxbw 48(%rsp), %ymm5
pmovsxbd %xmm2, %xmm4
vpmovsxbd %xmm2, %xmm4
vpmovsxbd 48(%rsp), %ymm5
pmovsxbq %xmm2, %xmm4
vpmovsxbq %xmm2, %xmm4
vpmovsxbq 48(%rsp), %ymm5
pmovsxwd %xmm2, %xmm4
vpmovsxwd %xmm2, %xmm4
vpmovsxwd 48(%rsp), %ymm5
pmovsxwq %xmm2, %xmm4
vpmovsxwq %xmm2, %xmm4
vpmovsxwq 48(%rsp), %ymm5
pmovsxdq %xmm2, %xmm4
vpmovsxdq %xmm2, %xmm4
vpmovsxdq 48(%rsp), %ymm5

# 2. Duplications: movshdup, movsldup, movddup
movshdup %xmm0, %xmm4
vmovshdup %xmm0, %xmm4
vmovshdup 0(%rsp), %ymm5
movsldup %xmm0, %xmm4
vmovsldup %xmm0, %xmm4
vmovsldup 0(%rsp), %ymm5
movddup %xmm1, %xmm4
vmovddup %xmm1, %xmm4
movddup 16(%rsp), %xmm4
vmovddup 16(%rsp), %xmm4
vmovddup 16(%rsp), %ymm5

# 3. Packed sqrt: sqrtps, sqrtpd
sqrtps %xmm0, %xmm4
vsqrtps %xmm0, %xmm4
vsqrtps 0(%rsp), %ymm5
sqrtpd %xmm1, %xmm4
vsqrtpd %xmm1, %xmm4
vsqrtpd 16(%rsp), %ymm5

# 4. Scalar sqrt: sqrtss, sqrtsd
sqrtss %xmm0, %xmm4
vsqrtss %xmm0, %xmm1, %xmm4
sqrtss 0(%rsp), %xmm4
vsqrtss 0(%rsp), %xmm1, %xmm4
sqrtsd %xmm1, %xmm4
vsqrtsd %xmm1, %xmm0, %xmm4
sqrtsd 16(%rsp), %xmm4
vsqrtsd 16(%rsp), %xmm0, %xmm4

# 5. Conversions: cvtdq2ps, cvtps2dq, cvttps2dq
cvtdq2ps %xmm2, %xmm4
vcvtdq2ps %xmm2, %xmm4
vcvtdq2ps 48(%rsp), %ymm5
cvtps2dq %xmm0, %xmm4
vcvtps2dq %xmm0, %xmm4
vcvtps2dq 0(%rsp), %ymm5
cvttps2dq %xmm0, %xmm4
vcvttps2dq %xmm0, %xmm4
vcvttps2dq 0(%rsp), %ymm5

# 6. Widening conversions: cvtdq2pd, cvtps2pd
cvtdq2pd %xmm2, %xmm4
vcvtdq2pd %xmm2, %xmm4
vcvtdq2pd 48(%rsp), %ymm5
cvtps2pd %xmm0, %xmm4
vcvtps2pd %xmm0, %xmm4
vcvtps2pd 0(%rsp), %ymm5

# 7. Narrowing conversions (128-bit only): cvtpd2ps, cvtpd2dq, cvttpd2dq
cvtpd2ps %xmm1, %xmm4
cvtpd2ps 16(%rsp), %xmm4
vcvtpd2ps %xmm1, %xmm4
cvtpd2dq %xmm1, %xmm4
cvtpd2dq 16(%rsp), %xmm4
vcvtpd2dq %xmm1, %xmm4
cvttpd2dq %xmm1, %xmm4
cvttpd2dq 16(%rsp), %xmm4
vcvttpd2dq %xmm1, %xmm4

# 8. Scalar conversions: cvtss2sd, cvtsd2ss
cvtss2sd %xmm0, %xmm4
vcvtss2sd %xmm0, %xmm1, %xmm4
cvtss2sd 0(%rsp), %xmm4
vcvtss2sd 0(%rsp), %xmm1, %xmm4
cvtsd2ss %xmm1, %xmm4
vcvtsd2ss %xmm1, %xmm0, %xmm4
cvtsd2ss 16(%rsp), %xmm4
vcvtsd2ss 16(%rsp), %xmm0, %xmm4

# 9. Horizontal min: phminposuw
phminposuw %xmm3, %xmm4
vphminposuw %xmm3, %xmm4
vphminposuw 64(%rsp), %xmm4

# 10. Broadcasts (VEX only)
vpbroadcastb %xmm2, %xmm4
vpbroadcastb %xmm2, %ymm5
vpbroadcastb 48(%rsp), %ymm5
vpbroadcastw %xmm2, %xmm4
vpbroadcastw %xmm2, %ymm5
vpbroadcastw 48(%rsp), %ymm5
vpbroadcastd %xmm2, %xmm4
vpbroadcastd %xmm2, %ymm5
vpbroadcastd 48(%rsp), %ymm5
vpbroadcastq %xmm2, %xmm4
vpbroadcastq %xmm2, %ymm5
vpbroadcastq 48(%rsp), %ymm5
vbroadcastss %xmm0, %xmm4
vbroadcastss %xmm0, %ymm5
vbroadcastss 0(%rsp), %ymm5
vbroadcastsd %xmm1, %ymm5
vbroadcastsd 16(%rsp), %ymm5
vbroadcasti128 0(%rsp), %ymm5
vbroadcastf128 0(%rsp), %ymm5

addq $0x60, %rsp
