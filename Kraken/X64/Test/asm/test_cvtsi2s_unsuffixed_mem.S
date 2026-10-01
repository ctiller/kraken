# Test: an unsuffixed cvtsi2ss/cvtsi2sd with a memory source reads 32 bits (GNU as: `l`)

subq $0x10, %rsp

# The low dword is 3, the high dword 1: a 64-bit read would give 2^32 + 3.
movabsq $0x0000000100000003, %rax
movq %rax, 0(%rsp)

cvtsi2sd 0(%rsp), %xmm0
cvtsi2ss 0(%rsp), %xmm1
vcvtsi2sd 0(%rsp), %xmm0, %xmm2
vcvtsi2ss 0(%rsp), %xmm1, %xmm3

addq $0x10, %rsp
