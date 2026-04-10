OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 2K
}



SECTIONS
{
    .text : {
        KEEP(*(.text.boot))      /* Boot func must be first */
        *(.text)
        *(.text.*)
    } > BRAM
    .rodata : ALIGN(4) {
         *(.rodata .rodata.*)
         *(.srodata .srodata.*)
        . = ALIGN(4); 
    } > BRAM
    .data : ALIGN(4) {
        __global_pointer = . + 0x800;
         *(.data .data.*)
         *(.sdata .sdata.*)
        . = ALIGN(4); 
    } > BRAM
    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4); 
        __bss_end = .;
    } > BRAM
/*END OF MEM*/
    _end = .;
/*STACK*/
    _stack_top = ORIGIN(BRAM) + LENGTH(BRAM);
/* ── Safety check ───────────────────────────────────────── *
     * Catch the case where code + data grows into the stack.    *
     * 64 bytes minimum headroom reserved for stack.             */
    ASSERT(_end <= (_stack_top - 64),
           "BRAM overflow: code+data too large, no room for stack!")
}