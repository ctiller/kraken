# Test: unary SIMD ops, including widening ones with a narrower source
subq $0x40, %rsp
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movups 0(%rsp), %xmm1
vpcmpeqb %ymm0, %ymm0, %ymm0
pmovzxbw %xmm1, %xmm0
vpcmpeqb %ymm2, %ymm2, %ymm2
pmovzxbw 8(%rsp), %xmm2
vpmovzxbw %xmm1, %ymm3
vpmovzxbw 0(%rsp), %ymm4
vpmovzxbw 8(%rsp), %xmm5
pabsb %xmm1, %xmm6
vpabsw %ymm3, %ymm7
addq $0x40, %rsp
