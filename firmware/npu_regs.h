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
#define LSU_STATUS_LOAD_FIFO_FULL_BIT   3
#define LSU_STATUS_STORE_FIFO_FULL_BIT  8
#define SA_STATUS_CMD_FIFO_FULL_BIT     3
#define LSU_LOAD_FIFO_EMPTY_BIT   (1u << 4)
#define LSU_LOAD_BUSY_BIT         (1u << 2)
#define LSU_STORE_FIFO_EMPTY_BIT  (1u << 9)
#define LSU_STORE_BUSY_BIT        (1u << 7)
#define SA_FIFO_EMPTY_BIT         (1u << 2)
#define SA_BUSY_BIT               (1u << 1)
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