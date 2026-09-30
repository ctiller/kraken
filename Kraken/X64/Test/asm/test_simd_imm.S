# Test: SIMD immediate instructions (SimdUnImmOp and SimdBinImmOp)
# Exercises: pshufd, pshufhw, pshuflw, vpermq, vpermpd, vpermilps, vpermilpd, roundps, roundpd
#            shufps, shufpd, palignr, pblendw, blendps, blendpd, vpblendd, pclmulqdq
#            mpsadbw, insertps, roundss, roundsd, cmpps, cmppd, cmpss, cmpsd, vperm2f128, vperm2i128

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
pshufd $0x4e, 0(%rsp), %xmm4
vpshufd $0xe4, %xmm0, %xmm5
vpshufd $0x39, %ymm1, %ymm6
vpshufd $0x93, 0(%rsp), %ymm7

# pshufhw / pshuflw
pshufhw $0x1b, %xmm0, %xmm3
pshufhw $0xe4, 0(%rsp), %xmm4
vpshufhw $0x4e, %xmm0, %xmm5
vpshufhw $0x39, %ymm1, %ymm6
vpshufhw $0x93, 0(%rsp), %ymm7

pshuflw $0x1b, %xmm0, %xmm3
pshuflw $0xe4, 0(%rsp), %xmm4
vpshuflw $0x4e, %xmm0, %xmm5
vpshuflw $0x39, %ymm1, %ymm6
vpshuflw $0x93, 0(%rsp), %ymm7

# vpermq / vpermpd (256-bit VEX only)
vpermq $0x1b, %ymm0, %ymm3
vpermq $0x4e, 0(%rsp), %ymm4
vpermpd $0x39, %ymm1, %ymm5
vpermpd $0x93, 0(%rsp), %ymm6

# vpermilps / vpermilpd (VEX only)
vpermilps $0x1b, %xmm0, %xmm3
vpermilps $0x4e, 0(%rsp), %xmm4
vpermilps $0xe4, %ymm1, %ymm5
vpermilps $0x39, 0(%rsp), %ymm6

vpermilpd $0x01, %xmm0, %xmm3
vpermilpd $0x02, 0(%rsp), %xmm4
vpermilpd $0x05, %ymm1, %ymm5
vpermilpd $0x0a, 0(%rsp), %ymm6

# roundps / roundpd
roundps $0x00, %xmm1, %xmm3
roundps $0x01, 16(%rsp), %xmm4
roundps $0x02, %xmm1, %xmm5
roundps $0x03, %xmm1, %xmm6
vroundps $0x08, %xmm1, %xmm7
vroundps $0x09, %ymm1, %ymm8
vroundps $0x0a, 16(%rsp), %ymm9

roundpd $0x00, %xmm2, %xmm3
roundpd $0x01, 32(%rsp), %xmm4
roundpd $0x02, %xmm2, %xmm5
roundpd $0x03, %xmm2, %xmm6
vroundpd $0x08, %xmm2, %xmm7
vroundpd $0x09, %ymm2, %ymm8
vroundpd $0x0a, 32(%rsp), %ymm9

# --- SimdBinImmOp ---

# shufps / shufpd
shufps $0x1b, %xmm1, %xmm0
shufps $0x4e, 0(%rsp), %xmm0
vshufps $0xe4, %xmm1, %xmm0, %xmm3
vshufps $0x39, %ymm1, %ymm0, %ymm4
vshufps $0x93, 0(%rsp), %ymm0, %ymm5

shufpd $0x01, %xmm1, %xmm0
shufpd $0x02, 0(%rsp), %xmm0
vshufpd $0x01, %xmm1, %xmm0, %xmm3
vshufpd $0x05, %ymm1, %ymm0, %ymm4
vshufpd $0x0a, 0(%rsp), %ymm0, %ymm5

# palignr
palignr $4, %xmm1, %xmm0
palignr $8, 0(%rsp), %xmm0
vpalignr $12, %xmm1, %xmm0, %xmm3
vpalignr $16, %ymm1, %ymm0, %ymm4
vpalignr $20, 0(%rsp), %ymm0, %ymm5

# pblendw
pblendw $0x55, %xmm1, %xmm0
pblendw $0xaa, 0(%rsp), %xmm0
vpblendw $0x0f, %xmm1, %xmm0, %xmm3
vpblendw $0xf0, 0(%rsp), %xmm0, %xmm4

# blendps / blendpd
blendps $0x05, %xmm1, %xmm0
blendps $0x0a, 0(%rsp), %xmm0
vblendps $0x03, %xmm1, %xmm0, %xmm3
vblendps $0x09, %ymm1, %ymm0, %ymm4
vblendps $0x06, 0(%rsp), %ymm0, %ymm5

blendpd $0x01, %xmm1, %xmm0
blendpd $0x02, 0(%rsp), %xmm0
vblendpd $0x01, %xmm1, %xmm0, %xmm3
vblendpd $0x05, %ymm1, %ymm0, %ymm4
vblendpd $0x0a, 0(%rsp), %ymm0, %ymm5

# vpblendd (VEX only)
vpblendd $0x55, %xmm1, %xmm0, %xmm3
vpblendd $0xaa, %ymm1, %ymm0, %ymm4
vpblendd $0x33, 0(%rsp), %ymm0, %ymm5

# pclmulqdq
pclmulqdq $0x00, %xmm1, %xmm0
pclmulqdq $0x01, 0(%rsp), %xmm0
vpclmulqdq $0x10, %xmm1, %xmm0, %xmm3
vpclmulqdq $0x11, %ymm1, %ymm0, %ymm4
vpclmulqdq $0x00, 0(%rsp), %ymm0, %ymm5

# mpsadbw
mpsadbw $0x00, %xmm1, %xmm0
mpsadbw $0x04, 0(%rsp), %xmm0
vmpsadbw $0x02, %xmm1, %xmm0, %xmm3
vmpsadbw $0x05, %ymm1, %ymm0, %ymm4
vmpsadbw $0x07, 0(%rsp), %ymm0, %ymm5

# insertps (memBytes? = 4)
insertps $0x10, %xmm1, %xmm0
insertps $0x25, 16(%rsp), %xmm0
vinsertps $0x3f, %xmm1, %xmm0, %xmm3
vinsertps $0x42, 16(%rsp), %xmm0, %xmm4

# roundss / roundsd (memBytes? = 4/8)
roundss $0x00, %xmm1, %xmm0
roundss $0x01, 16(%rsp), %xmm0
vroundss $0x02, %xmm1, %xmm0, %xmm3
vroundss $0x03, 16(%rsp), %xmm0, %xmm4

roundsd $0x00, %xmm2, %xmm0
roundsd $0x01, 32(%rsp), %xmm0
vroundsd $0x02, %xmm2, %xmm0, %xmm3
vroundsd $0x03, 32(%rsp), %xmm0, %xmm4

# cmpps / cmppd
cmpps $0x00, %xmm1, %xmm0
cmpps $0x01, 16(%rsp), %xmm0
vcmpps $0x04, %xmm1, %xmm0, %xmm3
vcmpps $0x0c, %ymm1, %ymm0, %ymm4
vcmpps $0x18, 16(%rsp), %ymm0, %ymm5

cmppd $0x00, %xmm2, %xmm0
cmppd $0x01, 32(%rsp), %xmm0
vcmppd $0x04, %xmm2, %xmm0, %xmm3
vcmppd $0x0c, %ymm2, %ymm0, %ymm4
vcmppd $0x18, 32(%rsp), %ymm0, %ymm5

# cmpss / cmpsd (memBytes? = 4/8)
cmpss $0x00, %xmm1, %xmm0
cmpss $0x01, 16(%rsp), %xmm0
vcmpss $0x04, %xmm1, %xmm0, %xmm3
vcmpss $0x12, 16(%rsp), %xmm0, %xmm4

cmpsd $0x00, %xmm2, %xmm0
cmpsd $0x01, 32(%rsp), %xmm0
vcmpsd $0x04, %xmm2, %xmm0, %xmm3
vcmpsd $0x12, 32(%rsp), %xmm0, %xmm4

# vperm2f128 / vperm2i128 (256-bit VEX only)
vperm2f128 $0x02, %ymm1, %ymm0, %ymm3
vperm2f128 $0x20, 0(%rsp), %ymm0, %ymm4
vperm2f128 $0x88, %ymm1, %ymm0, %ymm5

vperm2i128 $0x02, %ymm1, %ymm0, %ymm3
vperm2i128 $0x20, 0(%rsp), %ymm0, %ymm4
vperm2i128 $0x88, %ymm1, %ymm0, %ymm5

addq $0x80, %rsp
