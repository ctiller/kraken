# Tests for div, idiv, cbw, cwd variants
# Includes signed negatives, remainders, 8-bit forms with AH, 32-bit zero-extension.

# 1. 8-bit div: AX / src -> AL (quotient), AH (remainder)
movw $0x0119, %ax       # AX = 281 (0x0119)
movb $10, %bl           # 281 / 10 = 28 (0x1c) rem 1 (0x01) -> AL=28, AH=1 -> AX=0x011c
divb %bl
movw %ax, %r8w

# 2. 8-bit idiv: AX / src -> AL (quot), AH (rem) with negative dividend
movw $-281, %ax         # AX = -281
movb $10, %cl           # -281 / 10 = -28 (0xe4), rem -1 (0xff) -> AL=0xe4, AH=0xff
idivb %cl
movw %ax, %r9w

# 3. 16-bit div and idiv
movw $0x0001, %dx
movw $0x86a0, %ax       # DX:AX = 100000
movw $300, %cx          # 100000 / 300 = 333 (AX), rem 100 (DX)
divw %cx
movw %ax, %r10w
movw %dx, %r11w

# 16-bit idiv: negative divisor
movw $0, %dx
movw $1000, %ax         # DX:AX = 1000
movw $-30, %cx          # 1000 / -30 = -33 (AX), rem 10 (DX)
idivw %cx
movw %ax, %r12w
movw %dx, %r13w

# 4. 32-bit div and idiv, checking 32-bit zero-extension of 64-bit registers
movq $-1, %rax
movq $-1, %rdx
movl $0, %edx
movl $1000000, %eax     # EDX:EAX = 1000000, upper 32 bits of rax/rdx are zeroed
movl $7, %ecx           # 1000000 / 7 = 142857 rem 1
divl %ecx
movq %rax, %r14
movq %rdx, %r15

# 32-bit idiv with negative dividend
movl $0, %edx
movl $1000000, %eax
negl %eax
cltd                    # sign-extend EAX into EDX (EDX = -1)
movl $7, %ecx           # -1000000 / 7 = -142857 rem -1
idivl %ecx
movq %rax, -8(%rsp)
movq %rdx, -16(%rsp)

# 5. 64-bit div and idiv
movq $0, %rdx
movabsq $1000000000000, %rax
movq $3, %rcx
divq %rcx
movq %rax, -24(%rsp)
movq %rdx, -32(%rsp)

# 64-bit idiv
movabsq $-1000000000000, %rax
cqto                    # sign-extend RAX into RDX
movq $3, %rcx
idivq %rcx
movq %rax, -40(%rsp)
movq %rdx, -48(%rsp)

# 6. Conversion instructions: cbtw, cwtl, cltq, cwtd, cltd, cqto
# cbtw: AL -> AX
movw $0, %ax
movb $-5, %al           # AL = 0xfb
cbtw                    # AX = 0xfffb
movw %ax, -50(%rsp)

# cwtl: AX -> EAX (zero extends into RAX)
movq $-1, %rax
movw $-5, %ax
cwtl                    # EAX = 0xfffffffb, RAX = 0x00000000fffffffb
movq %rax, -64(%rsp)

# cltq: EAX -> RAX
movabsq $0x0000000080000000, %rax
cltq                    # RAX = 0xffffffff80000000
movq %rax, -72(%rsp)

# cwtd: AX -> DX:AX (sets DX)
movw $-100, %ax
cwtd                    # DX = 0xffff
movw %dx, -74(%rsp)

# cltd: EAX -> EDX (zero extends RDX)
movq $-1, %rdx
movl $-100, %eax
cltd                    # EDX = 0xffffffff, RDX = 0x00000000ffffffff
movq %rdx, -88(%rsp)

# cqto: RAX -> RDX
movq $-100, %rax
cqto                    # RDX = 0xffffffffffffffff
movq %rdx, -96(%rsp)

# Also test positive sign extension
movw $0x12, %ax
cbtw
movw %ax, -98(%rsp)
cwtl
movq %rax, -112(%rsp)
cltq
movq %rax, -120(%rsp)
cwtd
movw %dx, -122(%rsp)
cltd
movq %rdx, -136(%rsp)
cqto
movq %rdx, -144(%rsp)

# End with an instruction that defines all flags
movq $1, %r11
addq %r11, %r11
