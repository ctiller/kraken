# Test movbe, crc32, and rorx instructions
#
# Stack setup
subq $64, %rsp

# --- movbe tests ---
# Store little-endian 0x0102030405060708
movabsq $0x0102030405060708, %rax
movq %rax, (%rsp)

# 16-bit movbe load
movbew (%rsp), %bx
# (%rsp) starts with 0x08, 0x07 -> swapped is 0x0708

# 32-bit movbe load (zero-extends into rcx)
movbel (%rsp), %ecx
# (%rsp) starts with 08 07 06 05 -> swapped is 0x05060708

# 64-bit movbe load
movbeq (%rsp), %rdx
# swapped is 0x0807060504030201

# 16-bit movbe store
movw $0x1122, %r8w
movbew %r8w, 8(%rsp)
# In memory at 8(%rsp): 0x11, 0x22

# 32-bit movbe store
movl $0x11223344, %r9d
movbel %r9d, 16(%rsp)

# 64-bit movbe store
movabsq $0x1122334455667788, %r10
movbeq %r10, 24(%rsp)

# Verify stores with normal loads
movw 8(%rsp), %r11w
movl 16(%rsp), %r12d
movq 24(%rsp), %r13

# --- crc32 tests ---
# Initialize CRC accumulator in r14d
xorl %r14d, %r14d
# crc32b with byte 0x41
movb $0x41, %al
crc32b %al, %r14d

# crc32w with word 0x1234
movw $0x1234, %ax
crc32w %ax, %r14d

# crc32l with dword 0xdeadbeef
movl $0xdeadbeef, %eax
crc32l %eax, %r14d

# crc32q into 64-bit destination (accumulates 32-bit CRC from r15, zero-extends result)
movq $0xffffffff12345678, %r15
movabsq $0x0102030405060708, %rax
crc32q %rax, %r15

# crc32 from memory
movq $0x8877665544332211, %rax
movq %rax, 32(%rsp)
crc32b 32(%rsp), %r14d
crc32w 32(%rsp), %r14d
crc32l 32(%rsp), %r14d
crc32q 32(%rsp), %r15

# --- rorx tests ---
# 32-bit rorx: rorx $imm, src, dst
movl $0x12345678, %eax
rorxl $4, %eax, %ebx
# 64-bit rorx: rorx $imm, src, dst
movabsq $0x123456789abcdef0, %rax
rorxq $8, %rax, %rcx
# rorx from memory
rorxl $12, 16(%rsp), %edx
rorxq $16, 24(%rsp), %rsi

# Clean up stack
addq $64, %rsp
