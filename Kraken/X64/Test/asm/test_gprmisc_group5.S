# Test Group 5 instructions:
# cld, std, movsb/w/l/q, stosb/w/l/q, lodsb/w/l/q, cmpsb/w/l/q, scasb/w/l/q
# and rep prefixes (rep, repe, repne)

# Allocate buffer on stack
subq $128, %rsp

# Initialize source buffer at (%rsp): 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, ...
movabsq $0x0807060504030201, %rax
movq %rax, (%rsp)
movabsq $0x100f0e0d0c0b0a09, %rax
movq %rax, 8(%rsp)

# Test cld and std
std
pushfq
popq %r8
cld
pushfq
popq %r9

# --- Test movsb (forward) ---
cld
leaq (%rsp), %rsi
leaq 32(%rsp), %rdi
movsb
# rsi should have advanced by 1, rdi by 1 (relative to rsp: 1 and 33)
subq %rsp, %rsi
movq %rsi, %r10
subq %rsp, %rdi
movq %rdi, %r11
# Destination byte should be 0x01
movzbq 32(%rsp), %r12

# --- Test movsw, movsl, movsq ---
leaq (%rsp), %rsi
leaq 40(%rsp), %rdi
movsw
movl (%rsp), %eax
movsl
movq (%rsp), %rax
movsq

# --- Test stosb, stosw, stosl, stosq ---
leaq 64(%rsp), %rdi
movb $0x55, %al
stosb
movw $0x6677, %ax
stosw
movl $0x11223344, %eax
stosl
movabsq $0xaabbccddeeff0011, %rax
stosq

# --- Test lodsb, lodsw, lodsl, lodsq ---
leaq (%rsp), %rsi
lodsb
movzbq %al, %r13
lodsw
movzwq %ax, %r14
lodsl
movl %eax, %r15d
lodsq
movq %rax, %r8

# --- Test rep movsb ---
leaq (%rsp), %rsi
leaq 80(%rsp), %rdi
movq $8, %rcx
rep movsb
# Check rcx is 0 and destination has 8 bytes
movq 80(%rsp), %r9

# --- Test rep stosb ---
leaq 96(%rsp), %rdi
movb $0xaa, %al
movq $4, %rcx
rep stosb
movl 96(%rsp), %r10d

# --- Test repe cmpsb ---
# Compare 80(%rsp) and (%rsp) which should be identical for 8 bytes
leaq 80(%rsp), %rsi
leaq (%rsp), %rdi
movq $8, %rcx
repe cmpsb
# rcx should be 0 and ZF should be 1
pushfq
popq %r11

# --- Test repne scasb ---
# Search for byte 0x05 in (%rsp) which has 0x01, 0x02, 0x03, 0x04, 0x05...
leaq (%rsp), %rdi
movb $0x05, %al
movq $8, %rcx
repne scasb
# rcx should have stopped when 0x05 was matched
movq %rcx, %r12

# --- Test std backward movsb ---
std
leaq 7(%rsp), %rsi
leaq 119(%rsp), %rdi
movsb
movsb
cld
movzbq 119(%rsp), %r13
movzbq 118(%rsp), %r14

# Clean up registers holding stack addresses
xorq %rsi, %rsi
xorq %rdi, %rdi

# Clean up stack
addq $128, %rsp
