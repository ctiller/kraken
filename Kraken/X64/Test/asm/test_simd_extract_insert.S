# Test: vextracti128 / vextractf128, vinserti128 / vinsertf128, and vcvtps2ph (F16C)
subq $0x80, %rsp

movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x1122334455667788, %rax
movq %rax, 16(%rsp)
movabsq $0x99aabbccddeeff00, %rax
movq %rax, 24(%rsp)

# Pre-fill ymm1-ymm3 and ymm10-ymm14 to verify upper-bit zeroing on register destinations
vmovups 0(%rsp), %ymm0
vmovups 0(%rsp), %ymm1
vmovups 0(%rsp), %ymm2
vmovups 0(%rsp), %ymm3
vmovups 0(%rsp), %ymm10
vmovups 0(%rsp), %ymm11
vmovups 0(%rsp), %ymm13
vmovups 0(%rsp), %ymm14

vextracti128 $0, %ymm0, %xmm1
vextracti128 $1, %ymm0, %xmm2
vextracti128 $1, %ymm0, 56(%rsp)
vextractf128 $0, %ymm0, 72(%rsp)
vextractf128 $1, %ymm0, %xmm3

vinserti128 $0, %xmm1, %ymm0, %ymm4
vinserti128 $1, %xmm2, %ymm0, %ymm5
vinserti128 $0, 56(%rsp), %ymm0, %ymm6
vinsertf128 $1, %xmm3, %ymm0, %ymm7
vinsertf128 $0, 72(%rsp), %ymm0, %ymm8

# Setup single-precision test vectors at 32(%rsp) for vcvtps2ph:
# Low 128b: 1.00048828125f (0x3f801000, halfway tie-to-even), -1.00146484375f (0xbf803000, odd tie),
#           100000.0f (0x47c35000, overflow), 1e-6f (0x358637bd, subnormal)
movabsq $0xbf8030003f801000, %rax
movq %rax, 32(%rsp)
movabsq $0x358637bd47c35000, %rax
movq %rax, 40(%rsp)
# High 128b: -100000.0f (0xc7c35000, neg overflow), -0.0f (0x80000000),
#            +inf (0x7f800000), SNaN with payload (0x7f800123)
movabsq $0x80000000c7c35000, %rax
movq %rax, 48(%rsp)
movabsq $0x7f8001237f800000, %rax
movq %rax, 56(%rsp)

vmovups 32(%rsp), %ymm9

# vcvtps2ph: xmm -> xmm (modes 0 and 4/MXCSR.RC; also verifies bits [255:64] are zeroed)
vcvtps2ph $0, %xmm9, %xmm10
vcvtps2ph $4, %xmm9, %xmm11

# vcvtps2ph: xmm -> m64 (modes 1, 2, 3; also verifies 96(%rsp) is not overwritten by 64-bit store)
movabsq $0xdeadbeefcafebabe, %rax
movq %rax, 96(%rsp)
vcvtps2ph $1, %xmm9, 88(%rsp)
movq 88(%rsp), %rbx
vmovups 88(%rsp), %xmm12
vcvtps2ph $2, %xmm9, 88(%rsp)
movq 88(%rsp), %rcx
vcvtps2ph $3, %xmm9, 88(%rsp)
movq 88(%rsp), %rdx

# vcvtps2ph: ymm -> xmm (modes 0 and 1; also verifies bits [255:128] are zeroed)
vcvtps2ph $0, %ymm9, %xmm13
vcvtps2ph $1, %ymm9, %xmm14

# vcvtps2ph: ymm -> m128 (modes 2, 3, 4, and 0xfa with ignored high imm8 bits)
vcvtps2ph $2, %ymm9, 104(%rsp)
movq 104(%rsp), %rsi
movq 112(%rsp), %rdi
vcvtps2ph $3, %ymm9, 104(%rsp)
movq 104(%rsp), %r8
movq 112(%rsp), %r9
vcvtps2ph $0xfa, %ymm9, 104(%rsp)
movq 104(%rsp), %r10
movq 112(%rsp), %r11
vcvtps2ph $4, %ymm9, 104(%rsp)
vmovups 104(%rsp), %xmm15

addq $0x80, %rsp
