# Test: memory hint instructions (prefetcht0, prefetcht1, prefetcht2, prefetchnta, prefetchw)

subq $0x40, %rsp

# Setup some memory
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movq %rax, 8(%rsp)

prefetcht0 0(%rsp)
prefetcht0 8(%rsp)
prefetcht1 0(%rsp)
prefetcht1 8(%rsp)
prefetcht2 0(%rsp)
prefetcht2 8(%rsp)
prefetchnta 0(%rsp)
prefetchnta 8(%rsp)
prefetchw 0(%rsp)
prefetchw 8(%rsp)

# Clear rbx
movq $0, %rbx
prefetcht0 (%rsp)
prefetcht1 8(%rsp)
prefetcht2 (%rsp,%rax,1)
prefetchnta -16(%rsp)
prefetchw (%rsp)

addq $0x40, %rsp
