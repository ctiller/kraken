# Regression: shrd/shld with a count equal to the operand size leave the status flags
# undefined but must not touch DF.

movq $5, %rax
movq $7, %rbx
shrdw $16, %ax, %bx
shldw $16, %ax, %bx
addq %rax, %rax
