#include <stdint.h>
// // #include <stdbool.h>
// #define SA_CTRL_REG_ADDR 0x800
// #define SA_STATUS_REG_ADDR 0x804
// #define SA_CMD_DESC_LO 0x808
// #define SA_CMD_DESC_HI 0x80C
// #define LSU_CTRL_REG_ADDR 0x810
// #define LSU_STATUS_REG_ADDR 0x814
// #define LSU_LOAD_DESC_LO 0x818
// #define LSU_LOAD_DESC_HI 0x81C
// #define LSU_STORE_DESC_LO 0x820
// #define LSU_STORE_DESC_HI 0x824

#define LSU_STORE_EN_BIT 0
#define LSU_LOAD_EN_BIT 1

#define NPU_ACTIVATION_BASE 0x00000
#define NPU_WEIGHT_BASE (1 << 14) // 0x200
#define NPU_OUTPUT_BASE 0x00000
#define AXI_DDR_BASE 0x00000000
#define TILE_SIZE 8

#define CONSUME_TOKEN 1
#define CONSUME_NONE 0
#define SIGNAL_DONE 1
#define SIGNAL_NONE 0
// volatile uint64_t *sa_cmd_desc = (volatile uint64_t *)SA_CMD_DESC_LO;
// volatile uint32_t *sa_ctrl_reg = (volatile uint32_t *)SA_CTRL_REG_ADDR;
// volatile uint32_t NPU_SA->STATUS = (volatile uint32_t *)SA_STATUS_REG_ADDR;
// volatile uint32_tNPU_LSU->CTRL = (volatile uint32_t *)LSU_CTRL_REG_ADDR;
// volatile uint32_t *lsu_status_reg = (volatile uint32_t *)LSU_STATUS_REG_ADDR;
// volatile uint64_t *lsu_load_desc = (volatile uint64_t *)LSU_LOAD_DESC_LO;
// volatile uint64_t *lsu_store_desc = (volatile uint64_t *)LSU_STORE_DESC_LO;

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
#define NPU_SA ((volatile NPU_SystolicRegs_t *)0x800)
#define NPU_LSU ((volatile NPU_LsuRegs_t *)0x810)

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

static inline void npu_sa_push_op(uint8_t pop_act_token, uint8_t pop_weight_token, uint8_t push_out_token, pool_type_t pool_type, uint8_t accum_out, uint8_t accum_in, uint8_t relu, uint8_t quant, uint8_t quant_shift, uint32_t output_offset, uint32_t weight_offset, uint32_t activation_offset)
{
    uint64_t desc = ((((uint64_t)(pop_act_token) & 0x1ULL) << 58) |
                     (((uint64_t)(pop_weight_token) & 0x1ULL) << 57) |
                     (((uint64_t)(push_out_token) & 0x1ULL) << 56) |
                     (((uint64_t)(pool_type) & 0x3ULL) << 54) |
                     (((uint64_t)(accum_out) & 0x1ULL) << 53) |
                     (((uint64_t)(accum_in) & 0x1ULL) << 52) |
                     (((uint64_t)(relu) & 0x1ULL) << 51) |
                     (((uint64_t)(quant) & 0x1ULL) << 50) |
                     (((uint64_t)(quant_shift) & 0x1FULL) << 45) |
                     (((uint64_t)(output_offset) & 0x7FFFULL) << 30) |
                     (((uint64_t)(weight_offset) & 0x7FFFULL) << 15) |
                     ((uint64_t)(activation_offset) & 0x7FFFULL));

    NPU_SA->CMD_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_SA->CMD_DESC_HI = (uint32_t)(desc >> 32);
}
// #define MAKE_DMA_DESCRIPTOR(len_bytes, internal_addr, axi_addr) \
//     ((((uint64_t)(len_bytes) & 0x1FFFULL) << 51) |              \
//      (((uint64_t)(internal_addr) & 0x7FFFFULL) << 32) |         \
//      ((uint64_t)(axi_addr)))

// #define MAKE_SYSTOLIC_OPERATION(pool_type, accum_out, accum_in, relu, quant, quant_shift, out_offst, weight_offst, act_offst) \
//     ((((uint64_t)(pool_type) & 0x3ULL) << 54) |                                                                               \
//      (((uint64_t)(accum_out) & 0x1ULL) << 53) |                                                                               \
//      (((uint64_t)(accum_in) & 0x1ULL) << 52) |                                                                                \
//      (((uint64_t)(relu) & 0x1ULL) << 51) |                                                                                    \
//      (((uint64_t)(quant) & 0x1ULL) << 50) |                                                                                   \
//      (((uint64_t)(quant_shift) & 0x1FULL) << 45) |                                                                            \
//      (((uint64_t)(out_offst) & 0x7FFFULL) << 30) |                                                                            \
//      (((uint64_t)(weight_offst) & 0x7FFFULL) << 15) |                                                                         \
//      ((uint64_t)(act_offst) & 0x7FFFULL))
void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                      uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                      uint8_t M_dim, uint8_t N_dim, uint8_t K_dim, uint8_t relu_en, uint8_t quant_en, uint8_t quant_shift_amount)
{
    const uint8_t BRAM_TILE_STRIDE = 8;
    const uint8_t AXI_TILE_STRIDE = 0x40; // its just 64 since 64 bytes is the size in bytes for an 8x8 tile
    const uint8_t TILE_SIZE_BYTES = 64;

    // MATRIX A
    // Tile 0 (Top-Left 8x8) -> Stays continuous in DDR for the first 8 rows

    // npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 32, AXI_DDR_BASE + 0x300, SIGNAL_DONE);
    // // Tile 1 (Top-Right 8x8)
    // npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 40, AXI_DDR_BASE + 0x340, SIGNAL_DONE);
    // // // Tile 2 (Bottom-Left 8x8)
    // npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 48, AXI_DDR_BASE + 0x380, SIGNAL_DONE);
    // // Tile 3 (Bottom-Right 8x8)
    // npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 56, AXI_DDR_BASE + 0x3C0, SIGNAL_DONE);

    // ////MATRIX B
    // // Tile 0 (Top-Left 8x8)
    // npu_lsu_push_load(64, NPU_WEIGHT_BASE + 32, AXI_DDR_BASE + 0x400, SIGNAL_DONE);
    // // // Tile 1 (Top-Right 8x8)
    // npu_lsu_push_load(64, NPU_WEIGHT_BASE + 40, AXI_DDR_BASE + 0x440, SIGNAL_DONE);
    // // // Tile 2 (Bottom-Left 8x8)
    // npu_lsu_push_load(64, NPU_WEIGHT_BASE + 48, AXI_DDR_BASE + 0x480, SIGNAL_DONE);
    // // Tile 3 (Bottom-Right 8x8)
    // npu_lsu_push_load(64, NPU_WEIGHT_BASE + 56, AXI_DDR_BASE + 0x4C0, SIGNAL_DONE);

    uint8_t m_tile_count = (M_dim + TILE_SIZE - 1) / TILE_SIZE;
    uint8_t n_tile_count = (N_dim + TILE_SIZE - 1) / TILE_SIZE;
    uint8_t k_tile_count = (K_dim + TILE_SIZE - 1) / TILE_SIZE;

    for (uint8_t i = 0; i < m_tile_count; i++)
    {
        for (uint8_t j = 0; j < n_tile_count; j++)
        {
            uint32_t out_offset = out_bram_base + (i * n_tile_count + j) * BRAM_TILE_STRIDE;

            for (uint8_t k = 0; k < k_tile_count; k++)
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
                npu_sa_push_op(consume_act, consume_weight, signal_done, POOL_BYPASS, accum_out, accum_in, relu_en, quant_en, quant_shift_amount, out_offset, weight_offset, act_offset);
            }
            uint32_t out_axi_addr = out_axi_base + (i * n_tile_count + j) * AXI_TILE_STRIDE;
            npu_lsu_push_store(TILE_SIZE_BYTES, out_offset, out_axi_addr, SIGNAL_DONE);
        }
    }

    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
}

void mat_mul_extensive_test();
void tiled_mat_mul_test();
void simple_matrix_mult_test();
void simple_max_pool_avg_pool_test();
// void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
//                       uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
//   uint8_t M_dim, uint8_t N_dim, uint8_t K_dim, uint8_t relu_en, uint8_t quant_en, uint8_t quant_shift_amount);
int main()
{

    // start lsu
    npu_lsu_enable_channel(1, 1);

    mat_mul_extensive_test();
    // tiled_mat_mul_test();
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, AXI_DDR_BASE + 0x300, AXI_DDR_BASE + 0x400, AXI_DDR_BASE + 0x500, 16, 16, 16, 1, 1, 0);

    simple_matrix_mult_test();
    simple_max_pool_avg_pool_test();
    while (1)
        ;

    return 0;
}

void simple_matrix_mult_test()
{
    //////////////////////
    // SIMPLE MATRIX MULT//
    //////////////////////
    // Matrix A
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 64, AXI_DDR_BASE + 0x600, SIGNAL_DONE);
    // // Matrix B
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 64, AXI_DDR_BASE + 0x640, SIGNAL_DONE);
    // // Matrix C
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 72, AXI_DDR_BASE + 0x680, SIGNAL_DONE);
    // // Matrix D
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 72, AXI_DDR_BASE + 0x6C0, SIGNAL_DONE);
    // for (uint32_t i = 0; i < 32; i++)
    // {
    //     ;
    // }
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_BYPASS, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 64, NPU_WEIGHT_BASE + 64, NPU_ACTIVATION_BASE + 64);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_BYPASS, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 72, NPU_WEIGHT_BASE + 72, NPU_ACTIVATION_BASE + 72);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    npu_lsu_push_store(128, NPU_OUTPUT_BASE + 64, AXI_DDR_BASE + 0x700, SIGNAL_DONE);
}
void simple_max_pool_avg_pool_test()
{
    ////////////////////
    // MAX POOLING TEST//(we reuse the previous matrices)
    ////////////////////
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_MAX, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 80, NPU_WEIGHT_BASE + 64, NPU_ACTIVATION_BASE + 64);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_MAX, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 80, NPU_WEIGHT_BASE + 72, NPU_ACTIVATION_BASE + 72);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    // npu_lsu_push_store(32, NPU_OUTPUT_BASE + 80, AXI_DDR_BASE + 0x780);
    ///////////
    // AVG POOL TEST
    ////////////
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_AVG, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 84, NPU_WEIGHT_BASE + 64, NPU_ACTIVATION_BASE + 64);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, POOL_AVG, 0, 0, 1, 1, 0, NPU_OUTPUT_BASE + 84, NPU_WEIGHT_BASE + 72, NPU_ACTIVATION_BASE + 72);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 80, AXI_DDR_BASE + 0x780, SIGNAL_DONE);
}
void mat_mul_extensive_test()
{
    // load desc 0 (Matrix A), 64 bytes from axi 0x0 to bram 0x0
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE, AXI_DDR_BASE, SIGNAL_DONE);
    // load desc 1(Matrix B), 64 bytes from axi
    npu_lsu_push_load(64, NPU_WEIGHT_BASE, AXI_DDR_BASE + 0x00000040, SIGNAL_DONE);

    // load descriptor MATRIX A   test semne
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 8, AXI_DDR_BASE + 0x00000080, SIGNAL_DONE);

    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 8, AXI_DDR_BASE + 0x000000C0, SIGNAL_DONE);

    // load descriptor MATRIX A Matrice Identitate
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 16, AXI_DDR_BASE + 0x00000100, SIGNAL_DONE);
    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 16, AXI_DDR_BASE + 0x00000140, SIGNAL_DONE);

    // load descriptor MATRIX A Matrice numere mari
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 24, AXI_DDR_BASE + 0x00000180, SIGNAL_DONE);

    // Matrix B load descriptor
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 24, AXI_DDR_BASE + 0x000001C0, SIGNAL_DONE);

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
                   1,
                   0,
                   NPU_OUTPUT_BASE,
                   NPU_WEIGHT_BASE,
                   NPU_ACTIVATION_BASE);
    // Sign test
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   1,
                   0,
                   NPU_OUTPUT_BASE + 8,
                   NPU_WEIGHT_BASE + 8,
                   NPU_ACTIVATION_BASE + 8);
    // Test matrice identitate
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   1,
                   0,
                   NPU_OUTPUT_BASE + 16,
                   NPU_WEIGHT_BASE + 16,
                   NPU_ACTIVATION_BASE + 16);
    // Test matrice numere mari
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,
                   POOL_BYPASS,
                   0,
                   0,
                   1,
                   1,
                   0,
                   NPU_OUTPUT_BASE + 24,
                   NPU_WEIGHT_BASE + 24,
                   NPU_ACTIVATION_BASE + 24);
    // while ((NPU_SA->STATUS & 1) == 0)
    //     ;
    // *sa_ctrl_reg = 1;
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE,
        AXI_DDR_BASE + 0x200, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 8,
        AXI_DDR_BASE + 0x240, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 16,
        AXI_DDR_BASE + 0x280, SIGNAL_DONE);
    npu_lsu_push_store(
        64,
        NPU_OUTPUT_BASE + 24,
        AXI_DDR_BASE + 0x2C0, SIGNAL_DONE);
}

// void tiled_mat_mul_test()
// {
//     // MATRIX A
//     // Tile 0 (Top-Left 8x8) -> Stays continuous in DDR for the first 8 rows

//     npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 32, AXI_DDR_BASE + 0x300);
//     // Tile 1 (Top-Right 8x8)
//     npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 40, AXI_DDR_BASE + 0x340);
//     // // Tile 2 (Bottom-Left 8x8)
//     npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 48, AXI_DDR_BASE + 0x380);
//     // Tile 3 (Bottom-Right 8x8)
//     npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 56, AXI_DDR_BASE + 0x3C0);

//     ////MATRIX B
//     // Tile 0 (Top-Left 8x8)
//     npu_lsu_push_load(64, NPU_WEIGHT_BASE + 32, AXI_DDR_BASE + 0x400);
//     // // Tile 1 (Top-Right 8x8)
//     npu_lsu_push_load(64, NPU_WEIGHT_BASE + 40, AXI_DDR_BASE + 0x440);
//     // // Tile 2 (Bottom-Left 8x8)
//     npu_lsu_push_load(64, NPU_WEIGHT_BASE + 48, AXI_DDR_BASE + 0x480);
//     // Tile 3 (Bottom-Right 8x8)
//     npu_lsu_push_load(64, NPU_WEIGHT_BASE + 56, AXI_DDR_BASE + 0x4C0);
//     for (uint32_t i = 0; i < 32; i++)
//     {
//         ;
//     }
//     // --- Sub-Quadrant Tile 0: C[0,0] ---
//     // Step 1: A0 * B0 (Save partial sum to Accumulator)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 0, 1, 0, 0, 0, NPU_OUTPUT_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_ACTIVATION_BASE + 32);
//     // Step 2: A1 * B2 (Read old sum, add to it, apply ReLU/Quantization, write to Output BRAM)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 1, 0, 1, 1, 0, NPU_OUTPUT_BASE + 32, NPU_WEIGHT_BASE + 48, NPU_ACTIVATION_BASE + 40);

//     // --- Sub-Quadrant Tile 1: C[0,1] ---
//     // Step 1: A0 * B1 (Save partial sum to Accumulator)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 0, 1, 0, 0, 0, NPU_OUTPUT_BASE + 40, NPU_WEIGHT_BASE + 40, NPU_ACTIVATION_BASE + 32);
//     // Step 2: A1 * B3 (Read old sum, add to it, apply ReLU/Quantization, write to Output BRAM)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 1, 0, 1, 1, 0, NPU_OUTPUT_BASE + 40, NPU_WEIGHT_BASE + 56, NPU_ACTIVATION_BASE + 40);

//     // --- Sub-Quadrant Tile 2: C[1,0] ---
//     // Step 1: A2 * B0 (Save partial sum to Accumulator)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 0, 1, 0, 0, 0, NPU_OUTPUT_BASE + 48, NPU_WEIGHT_BASE + 32, NPU_ACTIVATION_BASE + 48);
//     // Step 2: A3 * B2 (Read old sum, add to it, apply ReLU/Quantization, write to Output BRAM)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 1, 0, 1, 1, 0, NPU_OUTPUT_BASE + 48, NPU_WEIGHT_BASE + 48, NPU_ACTIVATION_BASE + 56);

//     // --- Sub-Quadrant Tile 3: C[1,1] ---
//     // Step 1: A2 * B1 (Save partial sum to Accumulator)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 0, 1, 0, 0, 0, NPU_OUTPUT_BASE + 56, NPU_WEIGHT_BASE + 40, NPU_ACTIVATION_BASE + 48);
//     // Step 2: A3 * B3 (Read old sum, add to it, apply ReLU/Quantization, write to Output BRAM)
//     npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE,POOL_BYPASS, 1, 0, 1, 1, 0, NPU_OUTPUT_BASE + 56, NPU_WEIGHT_BASE + 56, NPU_ACTIVATION_BASE + 56);

//     while ((NPU_SA->STATUS & 1) == 0)
//         ;
//     // Output Tile 0 (C_0,0)
//     npu_lsu_push_store(64, NPU_OUTPUT_BASE + 32, AXI_DDR_BASE + 0x500);

//     // Output Tile 1 (C_0,1)
//     npu_lsu_push_store(64, NPU_OUTPUT_BASE + 40, AXI_DDR_BASE + 0x540);

//     // Output Tile 2 (C_1,0)
//     npu_lsu_push_store(64, NPU_OUTPUT_BASE + 48, AXI_DDR_BASE + 0x580);

//     // Output Tile 3 (C_1,1)
//     npu_lsu_push_store(64, NPU_OUTPUT_BASE + 56, AXI_DDR_BASE + 0x5C0);
// }
