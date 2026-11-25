.section .text.boot

.global _boot
.global _reset
.global _start

_start:
_reset:
_boot:
	addi x1, zero, 0
	la sp, _stack_top
    la gp, __global_pointer
	addi x4, zero, 0
	addi x5, zero, 0
	addi x6, zero, 0
	addi x7, zero, 0
	addi x8, zero, 0
	addi x9, zero, 0
	addi x10, zero, 0
	addi x11, zero, 0
	addi x12, zero, 0
	addi x13, zero, 0
	addi x14, zero, 0
	addi x15, zero, 0
    addi  x16, zero, 0
    addi  x17, zero, 0
    addi  x18, zero, 0
    addi  x19, zero, 0
    addi  x20, zero, 0
    addi  x21, zero, 0
    addi  x22, zero, 0
    addi  x23, zero, 0
    addi  x24, zero, 0
    addi  x25, zero, 0
    addi  x26, zero, 0
    addi  x27, zero, 0
    addi  x28, zero, 0
    addi  x29, zero, 0
    addi  x30, zero, 0
    addi  x31, zero, 0
    la t0, __bss_start
    la t1, __bss_end
# li   t0, 0x200      # Load immediate: t0 = 0x00000200
# li   t1, 1          # Load immediate: t1 = 1
# sw   t1, 0(t0)      # Store Word: contents of t1 go to address (t0 + 0)

    # jal ra, main

    
    /* Clear BSS */
    

_bss_zero:
    bgeu t0, t1, _bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j _bss_zero

_bss_done:
    call main


# If main returns, hang forever
_hang:
    j _hang

.align 4
_exception_handler:
    j _hang         # Just hang on any exception