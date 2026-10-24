    .section .text.start
    .globl _start
_start:
    lui   sp, 0x21          # stack top = 0x0002_1000
    la    t0, __bss_start
    la    t1, __bss_end
1:  bge   t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:  call  main
3:  j     3b
