# Test: packed integer SIMD instructions
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
vpaddsb 0(%rsp), %ymm1, %ymm3
paddsw %xmm1, %xmm0
vpaddsw %xmm1, %xmm0, %xmm2
vpaddsw 0(%rsp), %ymm1, %ymm3
paddusb %xmm1, %xmm0
vpaddusb %xmm1, %xmm0, %xmm2
vpaddusb 0(%rsp), %ymm1, %ymm3
paddusw %xmm1, %xmm0
vpaddusw %xmm1, %xmm0, %xmm2
vpaddusw 0(%rsp), %ymm1, %ymm3
psubsb %xmm1, %xmm0
vpsubsb %xmm1, %xmm0, %xmm2
vpsubsb 0(%rsp), %ymm1, %ymm3
psubsw %xmm1, %xmm0
vpsubsw %xmm1, %xmm0, %xmm2
vpsubsw 0(%rsp), %ymm1, %ymm3
psubusb %xmm1, %xmm0
vpsubusb %xmm1, %xmm0, %xmm2
vpsubusb 0(%rsp), %ymm1, %ymm3
psubusw %xmm1, %xmm0
vpsubusw %xmm1, %xmm0, %xmm2
vpsubusw 0(%rsp), %ymm1, %ymm3
pmullw %xmm1, %xmm0
vpmullw %xmm1, %xmm0, %xmm2
vpmullw 0(%rsp), %ymm1, %ymm3
pmulhw %xmm1, %xmm0
vpmulhw %xmm1, %xmm0, %xmm2
vpmulhw 0(%rsp), %ymm1, %ymm3
pmulhuw %xmm1, %xmm0
vpmulhuw %xmm1, %xmm0, %xmm2
vpmulhuw 0(%rsp), %ymm1, %ymm3
pmulld %xmm1, %xmm0
vpmulld %xmm1, %xmm0, %xmm2
vpmulld 0(%rsp), %ymm1, %ymm3
pmuludq %xmm1, %xmm0
vpmuludq %xmm1, %xmm0, %xmm2
vpmuludq 0(%rsp), %ymm1, %ymm3
pmuldq %xmm1, %xmm0
vpmuldq %xmm1, %xmm0, %xmm2
vpmuldq 0(%rsp), %ymm1, %ymm3
pmaddwd %xmm1, %xmm0
vpmaddwd %xmm1, %xmm0, %xmm2
vpmaddwd 0(%rsp), %ymm1, %ymm3
pmaddubsw %xmm1, %xmm0
vpmaddubsw %xmm1, %xmm0, %xmm2
vpmaddubsw 0(%rsp), %ymm1, %ymm3
pmulhrsw %xmm1, %xmm0
vpmulhrsw %xmm1, %xmm0, %xmm2
vpmulhrsw 0(%rsp), %ymm1, %ymm3
pavgb %xmm1, %xmm0
vpavgb %xmm1, %xmm0, %xmm2
vpavgb 0(%rsp), %ymm1, %ymm3
pavgw %xmm1, %xmm0
vpavgw %xmm1, %xmm0, %xmm2
vpavgw 0(%rsp), %ymm1, %ymm3
pminub %xmm1, %xmm0
vpminub %xmm1, %xmm0, %xmm2
vpminub 0(%rsp), %ymm1, %ymm3
pminuw %xmm1, %xmm0
vpminuw %xmm1, %xmm0, %xmm2
vpminuw 0(%rsp), %ymm1, %ymm3
pminud %xmm1, %xmm0
vpminud %xmm1, %xmm0, %xmm2
vpminud 0(%rsp), %ymm1, %ymm3
pminsb %xmm1, %xmm0
vpminsb %xmm1, %xmm0, %xmm2
vpminsb 0(%rsp), %ymm1, %ymm3
pminsw %xmm1, %xmm0
vpminsw %xmm1, %xmm0, %xmm2
vpminsw 0(%rsp), %ymm1, %ymm3
pminsd %xmm1, %xmm0
vpminsd %xmm1, %xmm0, %xmm2
vpminsd 0(%rsp), %ymm1, %ymm3
pmaxub %xmm1, %xmm0
vpmaxub %xmm1, %xmm0, %xmm2
vpmaxub 0(%rsp), %ymm1, %ymm3
pmaxuw %xmm1, %xmm0
vpmaxuw %xmm1, %xmm0, %xmm2
vpmaxuw 0(%rsp), %ymm1, %ymm3
pmaxud %xmm1, %xmm0
vpmaxud %xmm1, %xmm0, %xmm2
vpmaxud 0(%rsp), %ymm1, %ymm3
pmaxsb %xmm1, %xmm0
vpmaxsb %xmm1, %xmm0, %xmm2
vpmaxsb 0(%rsp), %ymm1, %ymm3
pmaxsw %xmm1, %xmm0
vpmaxsw %xmm1, %xmm0, %xmm2
vpmaxsw 0(%rsp), %ymm1, %ymm3
pmaxsd %xmm1, %xmm0
vpmaxsd %xmm1, %xmm0, %xmm2
vpmaxsd 0(%rsp), %ymm1, %ymm3
psadbw %xmm1, %xmm0
vpsadbw %xmm1, %xmm0, %xmm2
vpsadbw 0(%rsp), %ymm1, %ymm3
psignb %xmm1, %xmm0
vpsignb %xmm1, %xmm0, %xmm2
vpsignb 0(%rsp), %ymm1, %ymm3
psignw %xmm1, %xmm0
vpsignw %xmm1, %xmm0, %xmm2
vpsignw 0(%rsp), %ymm1, %ymm3
psignd %xmm1, %xmm0
vpsignd %xmm1, %xmm0, %xmm2
vpsignd 0(%rsp), %ymm1, %ymm3
phaddw %xmm1, %xmm0
vphaddw %xmm1, %xmm0, %xmm2
vphaddw 0(%rsp), %ymm1, %ymm3
phaddd %xmm1, %xmm0
vphaddd %xmm1, %xmm0, %xmm2
vphaddd 0(%rsp), %ymm1, %ymm3
phaddsw %xmm1, %xmm0
vphaddsw %xmm1, %xmm0, %xmm2
vphaddsw 0(%rsp), %ymm1, %ymm3
phsubw %xmm1, %xmm0
vphsubw %xmm1, %xmm0, %xmm2
vphsubw 0(%rsp), %ymm1, %ymm3
phsubd %xmm1, %xmm0
vphsubd %xmm1, %xmm0, %xmm2
vphsubd 0(%rsp), %ymm1, %ymm3
phsubsw %xmm1, %xmm0
vphsubsw %xmm1, %xmm0, %xmm2
vphsubsw 0(%rsp), %ymm1, %ymm3
addq $0x40, %rsp
