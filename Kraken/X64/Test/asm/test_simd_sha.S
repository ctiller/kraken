# Test: SHA instructions
# Requires: sha_ni

subq $0x80, %rsp

# xmm5 and xmm6 operands, and 48(%rsp) memory operand
movabsq $0x0123456789abcdef, %rax
movq %rax, 32(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 40(%rsp)
movups 32(%rsp), %xmm5
movabsq $0x1111111122222222, %rax
movq %rax, 48(%rsp)
movabsq $0x3333333344444444, %rax
movq %rax, 56(%rsp)
movups 48(%rsp), %xmm6

# sha1msg1, sha1msg2, sha1nexte
sha1msg1 %xmm6, %xmm5
sha1msg1 48(%rsp), %xmm5
sha1msg2 %xmm6, %xmm5
sha1msg2 48(%rsp), %xmm5
sha1nexte %xmm6, %xmm5
sha1nexte 48(%rsp), %xmm5

# sha256msg1, sha256msg2
sha256msg1 %xmm6, %xmm5
sha256msg1 48(%rsp), %xmm5
sha256msg2 %xmm6, %xmm5
sha256msg2 48(%rsp), %xmm5

addq $0x80, %rsp
