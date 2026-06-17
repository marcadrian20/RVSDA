#include <stdint.h>

#define LSU_STORE_EN_BIT 0
#define LSU_LOAD_EN_BIT 1

#define MMIO_BASE 0x2000
#define NPU_ACTIVATION_BASE 0x00000
#define NPU_WEIGHT_BASE (1 << 14) // 0x200
#define NPU_OUTPUT_BASE 0x00000
// #define axi_ddr_base 0x00000000
#define TILE_SIZE 8

//sync system token defines
#define CONSUME_TOKEN 1
#define CONSUME_NONE 0
#define SIGNAL_DONE 1
#define SIGNAL_NONE 0

//the opcodes used for the POOL/SA ops
#define NPU_DESC_POOL 0x1ULL
#define NPU_DESC_SA   0x2ULL
#define NPU_DESC_QUANT  0x3ULL

//Quantizer passthrough
#define QUANT_DEFAULT_MULT 0x7FFFFFFF

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
} NPU_SystolicRegs_t;

typedef enum
{
    POOL_BYPASS = 0,
    POOL_MAX = 1,
    POOL_AVG = 2,
    POOL_GLOBAL_AVG = 3
} pool_type_t;
#define NPU_SA ((volatile NPU_SystolicRegs_t *)(MMIO_BASE + 0x000))
#define NPU_LSU ((volatile NPU_LsuRegs_t *)(MMIO_BASE + 0x010))
#define NPU_DDR_BASE_REG (*(volatile uint32_t *)(MMIO_BASE + 0x028)) //Offset 0x28

static inline void npu_lsu_enable_channel(uint8_t load_en, uint8_t store_en)
{
    uint32_t ctrl = NPU_LSU->CTRL;
    ctrl &= ~((1 << LSU_LOAD_EN_BIT) | (1 << LSU_STORE_EN_BIT));
    if (load_en)
        ctrl |= (1 << LSU_LOAD_EN_BIT);
    if (store_en)
        ctrl |= (1 << LSU_STORE_EN_BIT);
    NPU_LSU->CTRL = ctrl;
}

static inline void npu_lsu_push_load(uint16_t len_bytes, uint32_t internal_dst_addr, uint32_t axi_src_addr, uint8_t push_token)
{
    uint64_t desc = (((uint64_t)(len_bytes) & 0x1FFF) << 51) |
                    (((uint64_t)(push_token) & 0x1ULL) << 50) |
                    (((uint64_t)(internal_dst_addr) & 0x3FFFF) << 32) |
                    ((uint64_t)(axi_src_addr));
    NPU_LSU->LOAD_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_LSU->LOAD_DESC_HI = (uint32_t)(desc >> 32);
}

static inline void npu_lsu_push_store(uint16_t len_bytes, uint32_t internal_src_addr, uint32_t axi_dst_addr, uint8_t push_token)
{
    uint64_t desc = (((uint64_t)(len_bytes) & 0x1FFF) << 51) |
                    (((uint64_t)(push_token) & 0x1ULL) << 50) |
                    (((uint64_t)(internal_src_addr) & 0x3FFFF) << 32) |
                    ((uint64_t)(axi_dst_addr));
    NPU_LSU->STORE_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_LSU->STORE_DESC_HI = (uint32_t)(desc >> 32);
}

static inline void npu_sa_push_op(uint8_t pop_act_token, uint8_t pop_weight_token, uint8_t push_out_token, pool_type_t pool_type, uint8_t accum_out, uint8_t accum_in, uint8_t relu, uint32_t output_offset, uint32_t weight_offset, uint32_t activation_offset)
{
    uint64_t desc = ((((uint64_t)NPU_DESC_SA) << 62) |
                     (((uint64_t)(pop_act_token) & 0x1ULL) << 58) |
                     (((uint64_t)(pop_weight_token) & 0x1ULL) << 57) |
                     (((uint64_t)(push_out_token) & 0x1ULL) << 56) |
                     (((uint64_t)(pool_type) & 0x3ULL) << 54) |
                     (((uint64_t)(accum_out) & 0x1ULL) << 53) |
                     (((uint64_t)(accum_in) & 0x1ULL) << 52) |
                     (((uint64_t)(relu) & 0x1ULL) << 51) |
                        /* bits [50:45] reserved */
                     (((uint64_t)(output_offset) & 0x7FFFULL) << 30) |
                     (((uint64_t)(weight_offset) & 0x7FFFULL) << 15) |
                     ((uint64_t)(activation_offset) & 0x7FFFULL));

    NPU_SA->CMD_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_SA->CMD_DESC_HI = (uint32_t)(desc >> 32);
}
static inline void npu_quant_push_cfg(
    uint32_t quant_mult,
    uint8_t shift_amount)
{
    uint64_t desc =
        (((uint64_t)NPU_DESC_QUANT) << 62) |
        (((uint64_t)(shift_amount & 0x1FULL)) << 57) |
        ((uint64_t)quant_mult);

    NPU_SA->CMD_DESC_LO = (uint32_t)desc;
    NPU_SA->CMD_DESC_HI = (uint32_t)(desc >> 32);
}
static inline void npu_pool_push_cfg(
    uint16_t feature_width,
    uint16_t feature_height,
    uint32_t valid_pixels)
{
    uint64_t desc =
        (((uint64_t)NPU_DESC_POOL) << 62) |
        (((uint64_t)(feature_width)  & 0xFFFULL)    << 50) |
        (((uint64_t)(feature_height) & 0xFFFULL)    << 38) |
        (((uint64_t)(valid_pixels)   & 0xFFFFFFULL) << 14);

    NPU_SA->CMD_DESC_LO = (uint32_t)(desc);
    NPU_SA->CMD_DESC_HI = (uint32_t)(desc >> 32);
}

void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                      uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                      uint16_t M_dim, uint16_t N_dim, uint16_t K_dim, uint8_t relu_en, pool_type_t pool_type)
{
    uint8_t BRAM_TILE_STRIDE = 8;
    uint8_t AXI_TILE_STRIDE = 0x40; // its just 64 since 64 bytes is the size in bytes for an 8x8 tile
    uint8_t TILE_SIZE_BYTES = 64;
    // if(pool_type != POOL_BYPASS){
    //     BRAM_TILE_STRIDE = 4;
    //     AXI_TILE_STRIDE = 0x20;
    //     TILE_SIZE_BYTES = 32;
    // }

    uint16_t m_tile_count = (M_dim + TILE_SIZE - 1) / TILE_SIZE;
    uint16_t n_tile_count = (N_dim + TILE_SIZE - 1) / TILE_SIZE;
    uint16_t k_tile_count = (K_dim + TILE_SIZE - 1) / TILE_SIZE;

    for (uint16_t i = 0; i < m_tile_count; i++)
    {
        for (uint16_t j = 0; j < n_tile_count; j++)
        {
            uint32_t out_offset = out_bram_base + (i * n_tile_count + j) * BRAM_TILE_STRIDE;

            for (uint16_t k = 0; k < k_tile_count; k++)
            {
                uint32_t act_offset = act_bram_base + (i * k_tile_count + k) * BRAM_TILE_STRIDE;
                uint32_t weight_offset = weight_bram_base + (k * n_tile_count + j) * BRAM_TILE_STRIDE;
                if (j == 0)
                {
                    uint32_t act_axi_addr = act_axi_base + (i * k_tile_count + k) * AXI_TILE_STRIDE;
                    npu_lsu_push_load(TILE_SIZE_BYTES, act_offset, act_axi_addr, SIGNAL_DONE);
                }
                if (i == 0)
                {
                    uint32_t weight_axi_addr = weight_axi_base + (k * n_tile_count + j) * AXI_TILE_STRIDE;
                    npu_lsu_push_load(TILE_SIZE_BYTES, weight_offset, weight_axi_addr, SIGNAL_DONE);
                }
                uint8_t accum_out = (k != 0);
                uint8_t accum_in = (k != k_tile_count - 1);
                uint8_t consume_act = (j == 0);
                uint8_t consume_weight = (i == 0);
                uint8_t signal_done = (k == k_tile_count - 1) ? SIGNAL_DONE : SIGNAL_NONE;
                npu_sa_push_op(consume_act, consume_weight, signal_done, pool_type, accum_out, accum_in, relu_en, out_offset, weight_offset, act_offset);
            }
            uint32_t out_axi_addr = out_axi_base + (i * n_tile_count + j) * AXI_TILE_STRIDE;
            npu_lsu_push_store(TILE_SIZE_BYTES, out_offset, out_axi_addr, SIGNAL_DONE);
        }
    }
    // if(pool_type != POOL_BYPASS)
    // {
    //     for(uint32_t p = 0; p < 170; p += 4)
    //     {
    //         npu_lsu_push_store(
    //             32,
    //             out_bram_base + p,
    //             out_axi_base + p * 8,
    //             SIGNAL_DONE
    //         );
    //     }
    // }

}

void mat_mul_extensive_test(uint32_t axi_ddr_base);
void tiled_mat_mul_test(uint32_t axi_ddr_base);
void simple_matrix_mult_test(uint32_t axi_ddr_base);
void simple_max_pool_avg_pool_test(uint32_t axi_ddr_base);
int main()
{
    uint32_t axi_ddr_base = NPU_DDR_BASE_REG;
    // start lsu
    npu_lsu_enable_channel(1, 1);

    mat_mul_extensive_test(axi_ddr_base);
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0x300, axi_ddr_base + 0x400, axi_ddr_base + 0x500, 16, 16, 16, 1, POOL_BYPASS);
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0x800, axi_ddr_base + 0xA40, axi_ddr_base + 0xC80, 24, 24, 24, 1, POOL_BYPASS);
    simple_matrix_mult_test(axi_ddr_base);

    // // npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0x1000, axi_ddr_base + 0x1100, axi_ddr_base + 0x1200, 16, 16, 16, 1, 1, 0, POOL_BYPASS);
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0xEC0, axi_ddr_base + 0xF80, axi_ddr_base + 0x1000, 24, 16, 8, 1, POOL_BYPASS);
    
//     npu_quant_push_cfg(1895921721, 8);

//     npu_tiled_matmul(
//     NPU_ACTIVATION_BASE,
//     NPU_WEIGHT_BASE,
//     NPU_OUTPUT_BASE,

//     axi_ddr_base + 0x0000,   // A
//     axi_ddr_base + 0x2A80,   // B
//     axi_ddr_base + 0x2B00,   // C output

//     680,                     // M
//     8,                       // N
//     16,                      // K

//     1,                       // relu
//  POOL_BYPASS
// );
    npu_pool_push_cfg(
        8,    // feature_width
        8,    // feature_height
        64    // valid_pixels
    );
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 128, axi_ddr_base + 0x00000140, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE+128,axi_ddr_base + 0x1180, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE+136, axi_ddr_base +0x11C0, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE+144, axi_ddr_base +0x1200, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE+152, axi_ddr_base +0x1240, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 160, axi_ddr_base +0x12C0, SIGNAL_DONE);     
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 168,axi_ddr_base + 0x1280, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 176,axi_ddr_base + 0x1300, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 184, axi_ddr_base +0x1340, SIGNAL_DONE); 

    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE+128);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE+136);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE+144);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE+152);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 160);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 168);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 176);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_MAX, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128,NPU_ACTIVATION_BASE + 184);
    
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 128, axi_ddr_base + 0x1380, SIGNAL_DONE);
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 136, axi_ddr_base + 0x13C0, SIGNAL_DONE);
    
//     npu_pool_push_cfg(
//         26,    // feature_width
//         26,    // feature_height
//         676    // valid_pixels
//     );
// npu_tiled_matmul(
//     NPU_ACTIVATION_BASE,
//     NPU_WEIGHT_BASE,
//     NPU_OUTPUT_BASE,

//     axi_ddr_base + 0x0000,   // A
//     axi_ddr_base + 0x2A80,   // B
//     axi_ddr_base + 0x4040,   // C output

//     680,                     // M
//     8,                       // N
//     16,                      // K

//     1,                       // relu
//  POOL_MAX
// );
    while (1)
        ;

    return 0;
}

void simple_matrix_mult_test(uint32_t axi_ddr_base)
{
    //////////////////////
    // SIMPLE MATRIX MULT//
    //////////////////////
    // Matrix A
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 64, axi_ddr_base + 0x600, SIGNAL_DONE);
    // // Matrix B
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 64, axi_ddr_base + 0x640, SIGNAL_DONE);
    // // Matrix C
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 72, axi_ddr_base + 0x680, SIGNAL_DONE);
    // // Matrix D
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 72, axi_ddr_base + 0x6C0, SIGNAL_DONE);
    // for (uint32_t i = 0; i < 32; i++)
    // {
    //     ;
    // }
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_BYPASS, 0, 0, 1, NPU_OUTPUT_BASE + 64, NPU_WEIGHT_BASE + 64, NPU_ACTIVATION_BASE + 64);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_BYPASS, 0, 0, 1, NPU_OUTPUT_BASE + 72, NPU_WEIGHT_BASE + 72, NPU_ACTIVATION_BASE + 72);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 64, axi_ddr_base + 0x700, SIGNAL_DONE);
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 72, axi_ddr_base + 0x740, SIGNAL_DONE);
}

void mat_mul_extensive_test(uint32_t axi_ddr_base)
{
    // load desc 0 (Matrix A), 64 bytes from axi 0x0 to bram 0x0
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE, axi_ddr_base, SIGNAL_DONE);
    // load desc 1(Matrix B), 64 bytes from axi
    npu_lsu_push_load(64, NPU_WEIGHT_BASE, axi_ddr_base + 0x00000040, SIGNAL_DONE);

    // load descriptor MATRIX A   test semne
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 8, axi_ddr_base + 0x00000080, SIGNAL_DONE);

    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 8, axi_ddr_base + 0x000000C0, SIGNAL_DONE);

    // load descriptor MATRIX A Matrice Identitate
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 16, axi_ddr_base + 0x00000100, SIGNAL_DONE);
    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 16, axi_ddr_base + 0x00000140, SIGNAL_DONE);

    // load descriptor MATRIX A Matrice numere mari
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 24, axi_ddr_base + 0x00000180, SIGNAL_DONE);

    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 24, axi_ddr_base + 0x000001C0, SIGNAL_DONE);

    //
    // while((*lsu_status_reg&(1<<1))==0)
    //     ;
    // for (uint32_t i = 0; i < 32; i++)
    // {
    //     ;
    // }
    // *sa_ctrl_reg = 1;
    // systolic operation cmd, relu =1, quant = 1, quant_shift = 0, output offst = 0x000, weight_offset = 0x00, act_offset = 0x00

    // Test normal
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   NPU_OUTPUT_BASE,
                   NPU_WEIGHT_BASE,
                   NPU_ACTIVATION_BASE);
    // Sign test
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   NPU_OUTPUT_BASE + 8,
                   NPU_WEIGHT_BASE + 8,
                   NPU_ACTIVATION_BASE + 8);
    // Test matrice identitate
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   NPU_OUTPUT_BASE + 16,
                   NPU_WEIGHT_BASE + 16,
                   NPU_ACTIVATION_BASE + 16);
    // Test matrice numere mari
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   NPU_OUTPUT_BASE + 24,
                   NPU_WEIGHT_BASE + 24,
                   NPU_ACTIVATION_BASE + 24);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    // *sa_ctrl_reg = 1;
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE,
        axi_ddr_base + 0x200, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 8,
        axi_ddr_base + 0x240, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 16,
        axi_ddr_base + 0x280, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 24,
        axi_ddr_base + 0x2C0, SIGNAL_DONE);
}

