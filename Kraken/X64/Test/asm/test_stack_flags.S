# Test leave, pushfq, and popfq
#
# Stack setup
subq $64, %rsp

# --- leave test ---
# Set up a fake stack frame:
# rbp points to 32(%rsp)
# At 32(%rsp), place saved old rbp = 0x1234567812345678
# Set rsp to 16(%rsp) (some local variables allocated)
movabsq $0x1234567812345678, %rax
movq %rax, 32(%rsp)
leaq 32(%rsp), %rbp
leaq 16(%rsp), %rsp

# Execute leave:
# rsp becomes rbp (32(%rsp_orig))
# rbp is popped from (rsp), which becomes 0x1234567812345678
# rsp becomes 40(%rsp_orig)
leave

# Verify rbp holds the saved value
movq %rbp, %r8

# --- pushfq and popfq test ---
# Clear flags first with an arithmetic op
addq $0, %rax
# Set flags: cf=1, zf=1, sf=1, of=1
# EFLAGS bits: CF(0)=1, 1(bit 1)=1, PF(2)=1, AF(4)=0, ZF(6)=1, SF(7)=1, IF(9)=1, OF(11)=1
# 1 + 2 + 4 + 64 + 128 + 512 + 2048 = 0xaf7
movq $0x0af7, %rax
pushq %rax
popfq

# Read flags back using pushfq
pushfq
popq %r9

# Test individual flag effects after popfq
# With CF = 1, adc with 0 produces 1
movq $0, %r10
adcq $0, %r10

# Test popping 0 into flags (clearing CF, ZF, etc.)
movq $0, %rax
pushq %rax
popfq
pushfq
popq %r11

# Clean up rsp back to function entry
# Current rsp is at 40(%rsp_orig)
# We need to restore it to the original rsp before subq $64
addq $24, %rsp
addq $64, %rsp
