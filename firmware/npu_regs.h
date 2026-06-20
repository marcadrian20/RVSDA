#ifndef NPU_REGS_H
#define NPU_REGS_H
#include <stdint.h>
#define MMIO_BASE 0x2000
typedef struct __attribute__((packed))
{
    uint32_t CTRL;          // Offset 0x00
    uint32_t STATUS;        // Offset 0x04
    uint32_t LOAD_DESC_LO;  // Offset 0x08
    uint32_t LOAD_DESC_HI;  // Offset 0x0C
    uint32_t STORE_DESC_LO; // Offset 0x10
    uint32_t STORE_DESC_HI; // Offset 0x14
} NPU_LsuRegs_t;

typedef struct __attribute__((packed))
{
    uint32_t CTRL;        // Offset 0x00
    uint32_t STATUS;      // Offset 0x04
    uint32_t CMD_DESC_LO; // Offset 0x08
    uint32_t CMD_DESC_HI; // Offset 0x0C
} NPU_ExecRegs_t;

typedef struct __attribute__((packed))
{
    uint32_t CTRL;        // Offset 0x00
    uint32_t STATUS;      // Offset 0x04
    uint32_t DDR_BASE_REG; // Offset 0x08
} NPU_AxiSlvRegs_t;

#define NPU_SA ((volatile NPU_ExecRegs_t *)(MMIO_BASE + 0x000))
#define NPU_LSU ((volatile NPU_LsuRegs_t *)(MMIO_BASE + 0x010))
#define NPU_SLV_AXI ((volatile NPU_AxiSlvRegs_t *)(MMIO_BASE + 0x028))
#endif