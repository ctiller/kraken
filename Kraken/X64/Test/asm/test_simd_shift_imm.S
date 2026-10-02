# Test: SSE and VEX packed shifts (psllw, pslld, psllq, psrlw, psrld, psrlq,
# psraw, psrad, pslldq, psrldq and v* forms) with immediate, XMM register,
# and 128-bit memory counts, including edge cases (count = 0, count >= width,
# non-zero upper 64 bits of 128-bit count operand, count[63:0] = 0x100 with
# zero low byte, unaligned VEX memory count, legacy upper-lane preservation
# vs VEX upper-lane zeroing).

subq $0x80, %rsp

# 32-byte test vector at 0(%rsp): signed/unsigned boundary patterns across lanes
movabsq $0x80017fff0000ffff, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x800000017fffffff, %rax
movq %rax, 16(%rsp)
movabsq $0x0123456789abcdef, %rax
movq %rax, 24(%rsp)

# 128-bit count at 32(%rsp): low64 = 3, high64 = 0xffffffffffffffff (ignored by CPU)
movq $3, %rax
movq %rax, 32(%rsp)
movq $-1, %rax
movq %rax, 40(%rsp)

# 128-bit count at 48(%rsp): low64 = 20 (> 15 for words, < 32 for dwords), high64 = 99
movq $20, %rax
movq %rax, 48(%rsp)
movq $99, %rax
movq %rax, 56(%rsp)

# 128-bit count at 64(%rsp): low64 = 0x100 (low 8 bits = 0, full 64-bit count = 256 > 63)
movq $0x100, %rax
movq %rax, 64(%rsp)
movq $0, %rax
movq %rax, 72(%rsp)

# 128-bit count at 80(%rsp): low64 = 0, high64 = 0xffffffffffffffff
movq $0, %rax
movq %rax, 80(%rsp)
movq $-1, %rax
movq %rax, 88(%rsp)

# Unaligned 128-bit count at 100(%rsp) (not 16-byte aligned, for VEX memory count): low64 = 5
movq $5, %rax
movq %rax, 100(%rsp)
movq $0, %rax
movq %rax, 108(%rsp)

# Load vectors and counts
vmovups 0(%rsp), %ymm12
movups 32(%rsp), %xmm13
movups 48(%rsp), %xmm14

# 1. Immediate shifts (SSE 128-bit preserving upper bits of %ymm0..%ymm3)
vmovups 0(%rsp), %ymm0
psllw $0, %xmm0
psllw $4, %xmm0
pslld $7, %xmm0
psllq $13, %xmm0

vmovups 0(%rsp), %ymm1
psrlw $3, %xmm1
psrld $9, %xmm1
psrlq $17, %xmm1

vmovups 0(%rsp), %ymm2
psraw $5, %xmm2
psrad $11, %xmm2

vmovups 0(%rsp), %ymm3
pslldq $3, %xmm3
psrldq $2, %xmm3

# Immediate count >= width edge cases (SSE), folded into %ymm15 with rotation
vmovups 0(%rsp), %ymm4
psllw $16, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
pslld $32, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psllq $64, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrlw $16, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrld $35, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrlq $255, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psraw $16, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrad $32, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
pslldq $16, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrldq $20, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# 2. VEX byte shifts (per 128-bit lane in 256-bit mode)
vpslldq $5, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrldq $7, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpslldq $0, %xmm12, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrldq $16, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# 3. XMM register and memory counts (SSE and VEX 128/256-bit)
# Count = 3 with high 64 bits all 1s (at 32(%rsp) and %xmm13)
vmovups 0(%rsp), %ymm4
psllw %xmm13, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
pslld 32(%rsp), %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psllq %xmm13, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrlw 32(%rsp), %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrld %xmm13, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrlq 32(%rsp), %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psraw %xmm13, %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vmovups 0(%rsp), %ymm4
psrad 32(%rsp), %xmm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# Count = 20 (> 15 for w, < 32 for d/q) at 48(%rsp) and %xmm14
vpsllw %xmm14, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpslld 48(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsllq %xmm14, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrlw 48(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrld %xmm14, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrlq 48(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsraw %xmm14, %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrad 48(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# Count = 0x100 (low 8 bits = 0, 64-bit count = 256 > 63) at 64(%rsp)
vpsllq 64(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrlq 64(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsraw 64(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

vpsrad 64(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# Unaligned VEX memory count at 100(%rsp) (count = 5)
vpsllw 100(%rsp), %ymm12, %ymm4
vpsllq $7, %ymm15, %ymm10
vpsrlq $57, %ymm15, %ymm15
vpor %ymm10, %ymm15, %ymm15
vpxor %ymm4, %ymm15, %ymm15

# 4. Final live results in %ymm4..%ymm11 (128-bit VEX zeroing upper 128 bits, and 256-bit VEX)
vmovups 0(%rsp), %ymm4
vpsllw 80(%rsp), %xmm12, %xmm4
vpslld $12, %ymm12, %ymm5
vpsllq $25, %ymm12, %ymm6
vpsrlw $6, %ymm12, %ymm7
vpsrld $14, %xmm12, %xmm8
vpsrlq $33, %ymm12, %ymm9
vpsraw $15, %ymm12, %ymm10
vpsrad $31, %ymm12, %ymm11

addq $0x80, %rsp
