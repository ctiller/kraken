# xchg/xadd with a memory destination addressed through the source register:
# the store must use the original address.

subq $64, %rsp

# xchg: %rbx = 5, %r8 = (stored address) - address = 0
movq $5, 16(%rsp)
leaq 16(%rsp), %rax
xchgq %rax, (%rax)
movq %rax, %rbx
movq 16(%rsp), %r8
leaq 16(%rsp), %r9
subq %r9, %r8

# xadd: %rsi = 7, %r10 = (7 + address) - address = 7
movq $7, 24(%rsp)
leaq 24(%rsp), %rdx
xaddq %rdx, (%rdx)
movq %rdx, %rsi
movq 24(%rsp), %r10
leaq 24(%rsp), %r11
subq %r11, %r10

# Same-register xadd: the sum wins, %r12 = 6
movq $3, %r12
xaddq %r12, %r12

xorl %eax, %eax
xorl %edx, %edx
xorl %r9d, %r9d
xorl %r11d, %r11d
addq $64, %rsp
