#ifndef NPU_TYPES_H
#define NPU_TYPES_H

#define LSU_STORE_EN_BIT 0
#define LSU_LOAD_EN_BIT 1


#define NPU_ACTIVATION_BASE 0x00000
#define NPU_WEIGHT_BASE (1 << 14) // 0x200
#define NPU_OUTPUT_BASE 0x00000
// #define axi_ddr_base 0x00000000
#define TILE_SIZE 8

// sync system token defines
#define CONSUME_TOKEN 1
#define CONSUME_NONE 0
#define SIGNAL_DONE 1
#define SIGNAL_NONE 0

// the opcodes used for the POOL/SA ops
#define NPU_DESC_POOL 0x1ULL
#define NPU_DESC_SA 0x2ULL
#define NPU_DESC_QUANT 0x3ULL

// Quantizer passthrough
#define QUANT_DEFAULT_MULT 0x7FFFFFFF



typedef enum
{
    POOL_BYPASS = 0,
    POOL_MAX = 1,
    POOL_AVG = 2,
    POOL_GLOBAL_AVG = 3
} pool_type_t;

#endif