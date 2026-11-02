# Test NullaryOp flag instructions: clc, stc, cmc, lahf, sahf, cld, std

# 1. stc, cmc, clc
stc
setc %r8b
cmc
setc %r9b
cmc
setc %r10b
clc
setc %r12b

# 2. lahf and sahf
# Preserve low byte (%al) and upper 48 bits of %rax when lahf writes %ah
movabsq $0x11223344556600aa, %rax
stc
lahf
movq %rax, %r13

# Load all 5 low status flags (SF, ZF, AF, PF, CF) via sahf, verify reserved bits
# 1, 3, 5 in %ah are ignored and bit 1 reads back as 1 via lahf
movb $0xff, %ah
sahf
movb $0x00, %ah
lahf
movzbl %ah, %ebx

movb $0x00, %ah
sahf
movb $0xff, %ah
lahf
movzbl %ah, %ecx

# 3. cld and std
std
stc
cld

# 4. lahf/clc/sahf sequence
# Set flags via subtraction, load into AH, modify AH, store back with SAHF
movq $0x8000000000000000, %r11
subq $1, %r11
lahf
movb %ah, %dl
# Clear flags, then restore with sahf
clc
sahf

# Set all status flags deterministically
movq $0x4000000000000000, %r11
addq %r11, %r11
