# Test: 256-bit VEX integer comparisons

subq $0x40, %rsp

# Setup pattern 1 at 0(%rsp): 0x0f0f...
movabsq $0x0f0f0f0f0f0f0f0f, %rax
movq %rax, 0(%rsp)
movq %rax, 8(%rsp)

# Setup pattern 2 at 16(%rsp): 0x3333...
movabsq $0x3333333333333333, %rbx
movq %rbx, 16(%rsp)
movq %rbx, 24(%rsp)

# Setup pattern 3 at 32(%rsp): interesting comparison values with signed boundaries
# Byte: (127, -128, 0, -1, 42, -42, 1, 0)
# Quadword 1: 0x7f8000ff2ad60100
# Quadword 2: 0x0123456789abcdef
movabsq $0x7f8000ff2ad60100, %rcx
movq %rcx, 32(%rsp)
movabsq $0x0123456789abcdef, %rcx
movq %rcx, 40(%rsp)

# Copy pattern 3 to 48(%rsp): ymm0 = (pattern 3, pattern 3), ymm1 = (pattern 2, pattern 3).
movups 32(%rsp), %xmm0
movups %xmm0, 48(%rsp)
vmovups 32(%rsp), %ymm0
vmovups 16(%rsp), %ymm1

vpcmpeqb %ymm1, %ymm0, %ymm2
vpcmpeqw %ymm1, %ymm0, %ymm3
vpcmpeqd %ymm1, %ymm0, %ymm4
vpcmpeqq %ymm1, %ymm0, %ymm5
vpcmpgtb %ymm1, %ymm0, %ymm6
vpcmpgtw %ymm1, %ymm0, %ymm7
vpcmpgtd %ymm1, %ymm0, %ymm8
vpcmpgtq %ymm1, %ymm0, %ymm9

addq $0x40, %rsp
