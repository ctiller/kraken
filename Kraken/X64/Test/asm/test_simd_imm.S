# Test: SIMD immediate instructions (SimdUnImmOp and SimdBinImmOp)
# Exercises: pshufd, pshufhw, pshuflw, vpermq, vpermpd, vpermilps, vpermilpd, roundps, roundpd,
#            aeskeygenassist, shufps, shufpd, palignr, pblendw, blendps, blendpd, vpblendd,
#            pclmulqdq, mpsadbw, dpps, dppd, insertps, roundss, roundsd, cmpps, cmppd, cmpss,
#            cmpsd, vperm2f128, vperm2i128, sha1rnds4
# Requires: sha_ni, vpclmulqdq, vaes
# Results that a later instruction overwrites are first folded into %ymm15 with
# `vaesenc %ymmN, %ymm15, %ymm15` (unlike xor, equal results don't cancel), so that every
# result reaches the final state.

subq $0x80, %rsp

# Setup test vectors at (%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 16(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 24(%rsp)

movabsq $0x3f80000040000000, %rax  # 1.0f, 2.0f
movq %rax, 32(%rsp)
movabsq $0xc0400000c0a00000, %rax  # -3.0f, -5.0f
movq %rax, 40(%rsp)
movabsq $0x3f80000040000000, %rax
movq %rax, 48(%rsp)
movabsq $0xc0400000c0a00000, %rax
movq %rax, 56(%rsp)

movabsq $0x3ff0000000000000, %rax  # 1.0d
movq %rax, 64(%rsp)
movabsq $0xbfe0000000000000, %rax  # -0.5d
movq %rax, 72(%rsp)
movabsq $0x3ff0000000000000, %rax
movq %rax, 80(%rsp)
movabsq $0xbfe0000000000000, %rax
movq %rax, 88(%rsp)

vmovups 0(%rsp), %ymm0
vmovups 32(%rsp), %ymm1
vmovups 64(%rsp), %ymm2

# --- SimdUnImmOp ---

# pshufd
pshufd $0x1b, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
pshufd $0x4e, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpshufd $0xe4, %xmm0, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
vpshufd $0x39, %ymm1, %ymm6
vaesenc %ymm6, %ymm15, %ymm15
vpshufd $0x93, 0(%rsp), %ymm7
vaesenc %ymm7, %ymm15, %ymm15

# pshufhw / pshuflw
pshufhw $0x1b, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
pshufhw $0xe4, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpshufhw $0x4e, %xmm0, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
vpshufhw $0x39, %ymm1, %ymm6
vaesenc %ymm6, %ymm15, %ymm15
vpshufhw $0x93, 0(%rsp), %ymm7
vaesenc %ymm7, %ymm15, %ymm15

pshuflw $0x1b, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
pshuflw $0xe4, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpshuflw $0x4e, %xmm0, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
vpshuflw $0x39, %ymm1, %ymm6
vaesenc %ymm6, %ymm15, %ymm15
vpshuflw $0x93, 0(%rsp), %ymm7
vaesenc %ymm7, %ymm15, %ymm15

# vpermq / vpermpd (256-bit VEX only)
vpermq $0x1b, %ymm0, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
vpermq $0x4e, 0(%rsp), %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vpermpd $0x39, %ymm1, %ymm5
vaesenc %ymm5, %ymm15, %ymm15
vpermpd $0x93, 0(%rsp), %ymm6
vaesenc %ymm6, %ymm15, %ymm15

# vpermilps / vpermilpd (VEX only)
vpermilps $0x1b, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpermilps $0x4e, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpermilps $0xe4, %ymm1, %ymm5
vaesenc %ymm5, %ymm15, %ymm15
vpermilps $0x39, 0(%rsp), %ymm6
vaesenc %ymm6, %ymm15, %ymm15

vpermilpd $0x01, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpermilpd $0x02, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpermilpd $0x05, %ymm1, %ymm5
vaesenc %ymm5, %ymm15, %ymm15
vpermilpd $0x0a, 0(%rsp), %ymm6
vaesenc %ymm6, %ymm15, %ymm15

# roundps / roundpd
roundps $0x00, %xmm1, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
roundps $0x01, 16(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
roundps $0x02, %xmm1, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
roundps $0x03, %xmm1, %xmm6
vaesenc %ymm6, %ymm15, %ymm15
vroundps $0x08, %xmm1, %xmm7
vaesenc %ymm7, %ymm15, %ymm15
vroundps $0x09, %ymm1, %ymm8
vaesenc %ymm8, %ymm15, %ymm15
vroundps $0x0a, 16(%rsp), %ymm9
vaesenc %ymm9, %ymm15, %ymm15

roundpd $0x00, %xmm2, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
roundpd $0x01, 32(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
roundpd $0x02, %xmm2, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
roundpd $0x03, %xmm2, %xmm6
vaesenc %ymm6, %ymm15, %ymm15
vroundpd $0x08, %xmm2, %xmm7
vroundpd $0x09, %ymm2, %ymm8
vroundpd $0x0a, 32(%rsp), %ymm9

# aeskeygenassist
aeskeygenassist $0x55, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
aeskeygenassist $0xab, 0(%rsp), %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vaeskeygenassist $0x55, %xmm0, %xmm5
vaesenc %ymm5, %ymm15, %ymm15
vaeskeygenassist $0xab, 0(%rsp), %xmm6
vaesenc %ymm6, %ymm15, %ymm15

# --- SimdBinImmOp ---

# shufps / shufpd
shufps $0x1b, %xmm1, %xmm0
shufps $0x4e, 0(%rsp), %xmm0
vshufps $0xe4, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vshufps $0x39, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vshufps $0x93, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

shufpd $0x01, %xmm1, %xmm0
shufpd $0x02, 0(%rsp), %xmm0
vshufpd $0x01, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vshufpd $0x05, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vshufpd $0x0a, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# palignr
palignr $4, %xmm1, %xmm0
palignr $8, 0(%rsp), %xmm0
vpalignr $12, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpalignr $16, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vpalignr $20, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# pblendw
pblendw $0x55, %xmm1, %xmm0
pblendw $0xaa, 0(%rsp), %xmm0
vpblendw $0x0f, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpblendw $0xf0, 0(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vpblendw $0x55, %ymm1, %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15
vpblendw $0xaa, 0(%rsp), %ymm0, %ymm6
vaesenc %ymm6, %ymm15, %ymm15

# blendps / blendpd
blendps $0x05, %xmm1, %xmm0
blendps $0x0a, 0(%rsp), %xmm0
vblendps $0x03, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vblendps $0x09, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vblendps $0x06, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

blendpd $0x01, %xmm1, %xmm0
blendpd $0x02, 0(%rsp), %xmm0
vblendpd $0x01, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vblendpd $0x05, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vblendpd $0x0a, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# vpblendd (VEX only)
vpblendd $0x55, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpblendd $0xaa, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vpblendd $0x33, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# pclmulqdq
pclmulqdq $0x00, %xmm1, %xmm0
pclmulqdq $0x01, 0(%rsp), %xmm0
vpclmulqdq $0x10, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vpclmulqdq $0x11, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vpclmulqdq $0x00, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# mpsadbw
mpsadbw $0x00, %xmm1, %xmm0
mpsadbw $0x04, 0(%rsp), %xmm0
vmpsadbw $0x02, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vmpsadbw $0x05, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vmpsadbw $0x07, 0(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# insertps (memBytes? = 4)
insertps $0x10, %xmm1, %xmm0
insertps $0x25, 16(%rsp), %xmm0
vinsertps $0x3f, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vinsertps $0x42, 16(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15

# roundss / roundsd (memBytes? = 4/8)
roundss $0x00, %xmm1, %xmm0
roundss $0x01, 16(%rsp), %xmm0
vroundss $0x02, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vroundss $0x03, 16(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15

roundsd $0x00, %xmm2, %xmm0
roundsd $0x01, 32(%rsp), %xmm0
vroundsd $0x02, %xmm2, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vroundsd $0x03, 32(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15

# cmpps / cmppd
cmpps $0x00, %xmm1, %xmm0
cmpps $0x01, 16(%rsp), %xmm0
vcmpps $0x04, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vcmpps $0x0c, %ymm1, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vcmpps $0x18, 16(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

cmppd $0x00, %xmm2, %xmm0
cmppd $0x01, 32(%rsp), %xmm0
vcmppd $0x04, %xmm2, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vcmppd $0x0c, %ymm2, %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vcmppd $0x18, 32(%rsp), %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# cmpss / cmpsd (memBytes? = 4/8)
cmpss $0x00, %xmm1, %xmm0
cmpss $0x01, 16(%rsp), %xmm0
vcmpss $0x04, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vcmpss $0x12, 16(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15

cmpsd $0x00, %xmm2, %xmm0
cmpsd $0x01, 32(%rsp), %xmm0
vcmpsd $0x04, %xmm2, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vcmpsd $0x12, 32(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15

# vperm2f128 / vperm2i128 (256-bit VEX only)
vperm2f128 $0x02, %ymm1, %ymm0, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
vperm2f128 $0x20, 0(%rsp), %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vperm2f128 $0x88, %ymm1, %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

vperm2i128 $0x02, %ymm1, %ymm0, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
vperm2i128 $0x20, 0(%rsp), %ymm0, %ymm4
vaesenc %ymm4, %ymm15, %ymm15
vperm2i128 $0x88, %ymm1, %ymm0, %ymm5
vaesenc %ymm5, %ymm15, %ymm15

# sha1rnds4
sha1rnds4 $0, %xmm1, %xmm0
sha1rnds4 $1, %xmm1, %xmm0
sha1rnds4 $2, 0(%rsp), %xmm0
sha1rnds4 $3, 0(%rsp), %xmm0
vaesenc %ymm0, %ymm15, %ymm15

# dpps / dppd
vmovups 32(%rsp), %ymm0
dpps $0xf1, %xmm1, %xmm0
dpps $0xf5, 32(%rsp), %xmm0
vdpps $0xf1, %xmm1, %xmm0, %xmm3
vaesenc %ymm3, %ymm15, %ymm15
vdpps $0xf5, 32(%rsp), %xmm0, %xmm4
vaesenc %ymm4, %ymm15, %ymm15
vdpps $0xf1, %ymm1, %ymm0, %ymm5
vdpps $0xf5, 32(%rsp), %ymm0, %ymm6

dppd $0x31, %xmm2, %xmm0
dppd $0x33, 64(%rsp), %xmm0
vdppd $0x31, %xmm2, %xmm0, %xmm3
vdppd $0x33, 64(%rsp), %xmm0, %xmm4

addq $0x80, %rsp
