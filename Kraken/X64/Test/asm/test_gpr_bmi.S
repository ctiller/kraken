# Tests for BMI1/BMI2 instructions in GprBinOp:
# bextr, bzhi, pdep, pext, sarx, shlx, shrx
# Covers 32-bit and 64-bit operands, zero inputs, all-ones, high bits,
# register and memory sources.

movq $0, %rax
movq $-1, %rbx
movabsq $0x8000000000000001, %rcx
movabsq $0x5555555555555555, %rdx
movabsq $0xaaaaaaaaaaaaaaaa, %rsi

# Stack memory setup
movq %rbx, -64(%rsp)
movq %rcx, -56(%rsp)
movq %rdx, -48(%rsp)
movq %rsi, -40(%rsp)

# bextr: control in src1 (start=7:0, len=15:8), data in src2
# 64-bit: extract bits 4..11 (start=4, len=8 -> 0x0804) from 0x5555...
movq $0x0804, %r8
bextr %r8, %rdx, %r9
# 32-bit with memory src2
movl $0x0804, %r10d
bextr %r10d, -48(%rsp), %r11d
# bextr zero input and start >= width
movq $0x4000, %r8
bextr %r8, %rbx, %r12
# bextr all ones
movq $0x3f00, %r8
bextr %r8, %rbx, %r13

# bzhi: index in src1[7:0]
# index < n
movq $8, %r8
bzhi %r8, %rbx, %r14
# index == 0
movq $0, %r8
bzhi %r8, %rbx, %r15
# index > n - 1 (sets CF)
movl $32, %r8d
bzhi %r8d, -56(%rsp), %eax

# pdep / pext: src2First = true (AT&T: op mask, src, dst)
# pdep: mask in src2 (first in AT&T), val in src1 (second in AT&T)
movabsq $0x0f0f0f0f0f0f0f0f, %r8
movabsq $0x123456789abcdef0, %r9
pdep %r8, %r9, %r10
# memory mask
pdep -48(%rsp), %r9, %r11
# pext: extract using mask
pext %r8, %r10, %r12
pext -48(%rsp), %r11, %r13
# 32-bit zero and all-ones
pdep %r8d, %eax, %ebx
pext %r8d, %ebx, %ecx

# sarx / shlx / shrx: count in src1 (first in AT&T), val in src2 (second in AT&T)
# 64-bit shift by 4
movq $4, %r8
sarx %r8, %rcx, %r14
shlx %r8, %rcx, %r15
shrx %r8, %rcx, %rax
# 32-bit shift with memory operand
movl $68, %r8d # 68 masked to 5 bits is 4
sarx %r8d, -56(%rsp), %ebx
shlx %r8d, -56(%rsp), %ecx
shrx %r8d, -56(%rsp), %edx
# 64-bit shift by 0 and max (63)
movq $0, %r8
sarx %r8, %rcx, %rsi
movq $63, %r8
shrx %r8, -56(%rsp), %rdi

# End with an instruction that defines all flags
addq %r11, %r11
