OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

SECTIONS
{
    . = 0x2000;
    .text.init : { *(.text.init) }
    . = ALIGN(0x1000);

    .text : { *(.text) }
    . = ALIGN(0x1000);

    .tohost : { *(.tohost) }
    . = ALIGN(0x10);

    .fromhost : { *(.fromhost) }
    . = ALIGN(0x10);

    .sig_begin : { *(.sig_begin) }
    . = ALIGN(0x10);

    .sig_end : { *(.sig_end) }
    . = ALIGN(0x1000);

    .data : { *(.data) }
    .data.string : { *(.data.string)}
    .bss : { *(.bss) }
    _end = .;
}
