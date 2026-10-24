MEMORY {
    CODE (rx)  : ORIGIN = 0x00000000, LENGTH = 0x2000
    DATA (rw)  : ORIGIN = 0x00020100, LENGTH = 0x0F00
}
SECTIONS {
    .text   : { *(.text.start) *(.text*) } > CODE
    .rodata : { *(.rodata*) *(.srodata*) } > CODE
    .data   : { *(.data*) *(.sdata*) } > DATA
    .bss    : { __bss_start = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(4); __bss_end = .; } > DATA
}
