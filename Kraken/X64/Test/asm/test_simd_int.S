# Test: packed integer SIMD instructions
# Results that a later instruction overwrites are first folded into %ymm15 with
# `vaesenc %ymmN, %ymm15, %ymm15` (unlike xor, equal results don't cancel), so that every
# result reaches the final state.
subq $0x40, %rsp
movabsq $0x0123456789abcdef, %rax
movq %rax, 0(%rsp)
movabsq $0xfedcba9876543210, %rax
movq %rax, 8(%rsp)
movabsq $0x7fff80007fff8000, %rax
movq %rax, 16(%rsp)
movabsq $0x0001ffff0001ffff, %rax
movq %rax, 24(%rsp)
movups 0(%rsp), %xmm0
movups 16(%rsp), %xmm1
paddsb %xmm1, %xmm0
vpaddsb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpaddsb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
paddsw %xmm1, %xmm0
vpaddsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpaddsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
paddusb %xmm1, %xmm0
vpaddusb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpaddusb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
paddusw %xmm1, %xmm0
vpaddusw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpaddusw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psubsb %xmm1, %xmm0
vpsubsb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsubsb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psubsw %xmm1, %xmm0
vpsubsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsubsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psubusb %xmm1, %xmm0
vpsubusb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsubusb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psubusw %xmm1, %xmm0
vpsubusw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsubusw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmullw %xmm1, %xmm0
vpmullw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmullw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmulhw %xmm1, %xmm0
vpmulhw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmulhw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmulhuw %xmm1, %xmm0
vpmulhuw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmulhuw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmulld %xmm1, %xmm0
vpmulld %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmulld 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmuludq %xmm1, %xmm0
vpmuludq %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmuludq 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmuldq %xmm1, %xmm0
vpmuldq %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmuldq 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaddwd %xmm1, %xmm0
vpmaddwd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaddwd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaddubsw %xmm1, %xmm0
vpmaddubsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaddubsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmulhrsw %xmm1, %xmm0
vpmulhrsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmulhrsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pavgb %xmm1, %xmm0
vpavgb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpavgb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pavgw %xmm1, %xmm0
vpavgw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpavgw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminub %xmm1, %xmm0
vpminub %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminub 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminuw %xmm1, %xmm0
vpminuw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminuw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminud %xmm1, %xmm0
vpminud %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminud 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminsb %xmm1, %xmm0
vpminsb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminsb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminsw %xmm1, %xmm0
vpminsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pminsd %xmm1, %xmm0
vpminsd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpminsd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxub %xmm1, %xmm0
vpmaxub %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxub 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxuw %xmm1, %xmm0
vpmaxuw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxuw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxud %xmm1, %xmm0
vpmaxud %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxud 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxsb %xmm1, %xmm0
vpmaxsb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxsb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxsw %xmm1, %xmm0
vpmaxsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
pmaxsd %xmm1, %xmm0
vpmaxsd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpmaxsd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psadbw %xmm1, %xmm0
vpsadbw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsadbw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psignb %xmm1, %xmm0
vpsignb %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsignb 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psignw %xmm1, %xmm0
vpsignw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsignw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
psignd %xmm1, %xmm0
vpsignd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vpsignd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phaddw %xmm1, %xmm0
vphaddw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vphaddw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phaddd %xmm1, %xmm0
vphaddd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vphaddd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phaddsw %xmm1, %xmm0
vphaddsw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vphaddsw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phsubw %xmm1, %xmm0
vphsubw %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vphsubw 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phsubd %xmm1, %xmm0
vphsubd %xmm1, %xmm0, %xmm2
vaesenc %ymm2, %ymm15, %ymm15
vphsubd 0(%rsp), %ymm1, %ymm3
vaesenc %ymm3, %ymm15, %ymm15
phsubsw %xmm1, %xmm0
vphsubsw %xmm1, %xmm0, %xmm2
vphsubsw 0(%rsp), %ymm1, %ymm3
addq $0x40, %rsp
