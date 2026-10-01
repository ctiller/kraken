# Test: 256-bit VEX bitwise instructions (from test_simd_logic.S)

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

# Upper halves differ from the lower ones.
vmovups 0(%rsp), %ymm0
vmovups 16(%rsp), %ymm1

vpor %ymm1, %ymm0, %ymm4
vpxor %ymm1, %ymm0, %ymm5
vandps %ymm1, %ymm0, %ymm8
vandnps %ymm1, %ymm0, %ymm9
vorps %ymm1, %ymm0, %ymm10
vxorps %ymm1, %ymm0, %ymm11
vandpd %ymm1, %ymm0, %ymm12
vandnpd %ymm1, %ymm0, %ymm13
vorpd %ymm1, %ymm0, %ymm14
vxorpd %ymm1, %ymm0, %ymm15

addq $0x40, %rsp
