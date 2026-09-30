# Regression: upper-lane immediate bits and memory-source forms the fuzzer missed while
# ymm registers were seeded only in their low 128 bits.

subq $0x40, %rsp
movabsq $0x3ff0000000000000, %rax   # 1.0
movq %rax, 0(%rsp)
movabsq $0x4000000000000000, %rax   # 2.0
movq %rax, 8(%rsp)
movabsq $0x4008000000000000, %rax   # 3.0
movq %rax, 16(%rsp)
movabsq $0x4010000000000000, %rax   # 4.0
movq %rax, 24(%rsp)
movabsq $0x0102030405060708, %rax
movq %rax, 32(%rsp)
movabsq $0x90a0b0c0d0e0f011, %rax
movq %rax, 40(%rsp)
movabsq $0x40490fdb8899aabb, %rax   # pi (float) in the low dword's neighbour
movq %rax, 48(%rsp)
movabsq $0x7f80ff0011223344, %rax
movq %rax, 56(%rsp)
vmovdqu 0(%rsp), %ymm0
vmovdqu 32(%rsp), %ymm1

# vshufpd uses imm bits 2 and 3 for the upper 128-bit lane.
vshufpd $4, %ymm1, %ymm0, %ymm2
vshufpd $8, %ymm0, %ymm1, %ymm3
# vmpsadbw uses imm bits 5:3 for the upper lane.
vmpsadbw $0x08, %ymm1, %ymm0, %ymm4
vmpsadbw $0x35, %ymm0, %ymm1, %ymm5
# insertps ignores COUNT_S (imm[7:6]) for a memory source.
movups 16(%rsp), %xmm6
insertps $0x40, 52(%rsp), %xmm6
vinsertps $0xd0, 48(%rsp), %xmm0, %xmm7
# vpmovmskb/vmovmskps/vmovmskpd with a ymm source.
vpmovmskb %ymm1, %ebx
vmovmskps %ymm1, %ecx
vmovmskpd %ymm0, %edx
addq $0x40, %rsp
