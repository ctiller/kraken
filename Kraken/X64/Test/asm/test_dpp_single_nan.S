# Test dpps and dppd with exactly one NaN product (defined behavior)

subq $64, %rsp

# --- 1. dpps with exactly one NaN product ---
# xmm0: [NaN (0x7fc00001), 1.0f (0x3f800000), 2.0f (0x40000000), 3.0f (0x40400000)]
# xmm1: [1.0f, 1.0f, 1.0f, 1.0f]
# imm = 0xf1: select all 4 products, store sum to lane 0
# product 0 is NaN * 1.0f = NaN. products 1,2,3 are finite.
# Exactly one NaN product -> defined.
movl $0x7fc00001, 0(%rsp)
movl $0x3f800000, 4(%rsp)
movl $0x40000000, 8(%rsp)
movl $0x40400000, 12(%rsp)
movups 0(%rsp), %xmm0

movl $0x3f800000, 16(%rsp)
movl $0x3f800000, 20(%rsp)
movl $0x3f800000, 24(%rsp)
movl $0x3f800000, 28(%rsp)
movups 16(%rsp), %xmm1

dpps $0xf1, %xmm1, %xmm0
movaps %xmm0, %xmm2

# --- 2. dppd with exactly one NaN product ---
# xmm3: [NaN (0x7ff8000000000001), 2.0 (0x4000000000000000)]
# xmm4: [1.0, 1.0]
# imm = 0x31: select both products, store sum to lane 0
# product 0 is NaN. product 1 is finite.
# Exactly one NaN product -> defined.
movabsq $0x7ff8000000000001, %rax
movq %rax, 32(%rsp)
movabsq $0x4000000000000000, %rax
movq %rax, 40(%rsp)
movups 32(%rsp), %xmm3

movabsq $0x3ff0000000000000, %rax
movq %rax, 48(%rsp)
movq %rax, 56(%rsp)
movups 48(%rsp), %xmm4

dppd $0x31, %xmm4, %xmm3
movapd %xmm3, %xmm5

addq $64, %rsp
