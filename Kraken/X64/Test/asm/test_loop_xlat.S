# Test: xlat/xlatb, jrcxz/jecxz, loop/loope/loopz/loopne/loopnz

  # ---------------------------------------------------------------------------
  # 1. Test xlat / xlatb
  # ---------------------------------------------------------------------------
  # Set up a small translation table at -256(%rsp)
  leaq -256(%rsp), %rbx
  movb $0x42, 0(%rbx)
  movb $0x99, 5(%rbx)
  movb $0x17, 255(%rbx)

  # Load table[5] -> 0x99, check that high bits of rax are preserved
  movabsq $0x1234567800000000, %rax
  movb $5, %al
  xlatb
  movq %rax, %r8

  # Load table[0] -> 0x42 using xlat (%rbx)
  movb $0, %al
  xlat (%rbx)
  movq %rax, %r9

  # Load table[255] -> 0x17
  movb $255, %al
  xlatb
  movq %rax, %r10

  # ---------------------------------------------------------------------------
  # 2. Test jrcxz
  # ---------------------------------------------------------------------------
  movq $0, %r11
  movq $0, %rcx
  jrcxz .Lrcx_zero
  jmp .Lrcx_done
.Lrcx_zero:
  addq $1, %r11
.Lrcx_done:

  # rcx non-zero should not jump
  movq $42, %rcx
  jrcxz .Lrcx_bad
  addq $2, %r11
  jmp .Lrcx_test2_done
.Lrcx_bad:
  addq $100, %r11
.Lrcx_test2_done:

  # ---------------------------------------------------------------------------
  # 3. Test jecxz
  # ---------------------------------------------------------------------------
  # High 32 bits non-zero, low 32 bits zero -> ecx is 0, so jecxz jumps
  movabsq $0x100000000, %rcx
  jecxz .Lecx_zero
  jmp .Lecx_done
.Lecx_zero:
  addq $4, %r11
.Lecx_done:

  # ecx non-zero should not jump
  movq $1, %rcx
  jecxz .Lecx_bad
  addq $8, %r11
  jmp .Lecx_test2_done
.Lecx_bad:
  addq $200, %r11
.Lecx_test2_done:

  # ---------------------------------------------------------------------------
  # 4. Test loop
  # ---------------------------------------------------------------------------
  movq $5, %rcx
  movq $0, %r12
.Lloop1:
  addq $1, %r12
  loop .Lloop1

  # ---------------------------------------------------------------------------
  # 5. Test loope / loopz
  # ---------------------------------------------------------------------------
  # Case A: ZF remains 1 (cmpq %rax, %rax), loops full 4 times
  movq $4, %rcx
  movq $0, %r13
.Lloope1:
  addq $1, %r13
  cmpq %rax, %rax
  loope .Lloope1

  # Case B: ZF becomes 0 on 2nd iteration, exits early
  movq $5, %rcx
  movq $0, %r14
.Lloope2:
  addq $1, %r14
  cmpq $2, %r14
  loope .Lloope2

  # ---------------------------------------------------------------------------
  # 6. Test loopne / loopnz
  # ---------------------------------------------------------------------------
  # Case A: ZF remains 0 (cmpq $1, %r15 with r15=0), loops full 3 times
  movq $3, %rcx
  movq $0, %r15
.Lloopne1:
  addq $10, %r15
  cmpq $1, %r15
  loopne .Lloopne1

  # Case B: ZF becomes 1 on 2nd iteration, exits early
  movq $5, %rcx
  movq $0, %rdx
.Lloopne2:
  addq $1, %rdx
  cmpq $2, %rdx
  loopne .Lloopne2

  # Clear rbx (was holding stack address)
  movq $0, %rbx

  # Define all flags
  addq %r11, %r11
