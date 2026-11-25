#ifndef NPU_H
#define NPU_H
#include "npu_types.h"
#include "npu_regs.h"
#include <stdint.h>

void npu_init(void);
uint32_t npu_get_ddr_base(void);
static inline void npu_lsu_wait_load_room(void)
{
    while (NPU_LSU->STATUS & (1u << LSU_STATUS_LOAD_FIFO_FULL_BIT)) ;
}

static inline void npu_lsu_wait_store_room(void)
{
    while (NPU_LSU->STATUS & (1u << LSU_STATUS_STORE_FIFO_FULL_BIT)) ;
}

static inline void npu_sa_wait_cmd_room(void)
{
    while (NPU_SA->STATUS & (1u << SA_STATUS_CMD_FIFO_FULL_BIT)) ;
}
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
    npu_lsu_wait_load_room();
    uint64_t desc = (((uint64_t)(len_bytes) & 0x1FFF) << 51) |
                    (((uint64_t)(push_token) & 0x1ULL) << 50) |
                    (((uint64_t)(internal_dst_addr) & 0x3FFFF) << 32) |
                    ((uint64_t)(axi_src_addr));
    NPU_LSU->LOAD_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_LSU->LOAD_DESC_HI = (uint32_t)(desc >> 32);
}

static inline void npu_lsu_push_store(uint16_t len_bytes, uint32_t internal_src_addr, uint32_t axi_dst_addr, uint8_t push_token)
{
    npu_lsu_wait_store_room();                //
    uint64_t desc = (((uint64_t)(len_bytes) & 0x1FFF) << 51) |
                    (((uint64_t)(push_token) & 0x1ULL) << 50) |
                    (((uint64_t)(internal_src_addr) & 0x3FFFF) << 32) |
                    ((uint64_t)(axi_dst_addr));
    NPU_LSU->STORE_DESC_LO = (uint32_t)(desc & 0xFFFFFFFFULL);
    NPU_LSU->STORE_DESC_HI = (uint32_t)(desc >> 32);
}

static inline void npu_sa_push_op(uint8_t pop_act_token, uint8_t pop_weight_token, uint8_t push_out_token, pool_type_t pool_type, uint8_t accum_out, uint8_t accum_in, uint8_t relu, uint32_t output_offset, uint32_t weight_offset, uint32_t activation_offset)
{
    npu_sa_wait_cmd_room();                   // <-- NEW
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
        (((uint64_t)(feature_width) & 0xFFFULL) << 50) |
        (((uint64_t)(feature_height) & 0xFFFULL) << 38) |
        (((uint64_t)(valid_pixels) & 0xFFFFFFULL) << 14);

    NPU_SA->CMD_DESC_LO = (uint32_t)(desc);
    NPU_SA->CMD_DESC_HI = (uint32_t)(desc >> 32);
}

static inline void store_pooled_featuremap(
    uint32_t out_bram_base,
    uint32_t out_axi_base,
    uint32_t pooled_pixels,
    pool_type_t pool_type)
{
    if (pool_type == POOL_BYPASS)
        return;
    while (!(NPU_SA->STATUS & SA_FIFO_EMPTY_BIT)) ;
    while ( NPU_SA->STATUS & SA_BUSY_BIT) ;
    for (uint32_t row = 0; row < pooled_pixels; row += 4)
    {
        const uint8_t last = (row + 4U >= pooled_pixels);
        npu_lsu_push_store(32, out_bram_base + row, out_axi_base + row * 8,
                       last ? SIGNAL_DONE : SIGNAL_NONE);

        // npu_lsu_push_store(
        //     32,
        //     out_bram_base + row,
        //     out_axi_base + row * 8,
        //     SIGNAL_DONE);
    }
}

void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                      uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                      uint16_t M_dim, uint16_t N_dim, uint16_t K_dim, uint8_t relu_en, pool_type_t pool_type);

void conv_pooled(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                 uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                 uint16_t input_width, uint16_t input_height, uint16_t kernel_width,
                 uint16_t kernel_height, uint16_t in_channels, uint16_t out_channels, uint8_t stride, uint8_t pad,
                 uint8_t relu_en, pool_type_t pool_type, uint32_t quant_mult, uint8_t shift_amount);
                 
void dense_layer(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                 uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                 uint16_t in_features, uint16_t out_features, uint32_t quant_mult, uint8_t shift_amount);

// static inline void mem_fence(void)
// {
//     while ((NPU_LSU->STATUS & (1u << 7))||!(NPU_LSU->STATUS & LSU_STORE_FIFO_EMPTY_BIT)) ;
// }

static inline void mem_fence(void)
{
    for (;;) {
        uint32_t lsu = NPU_LSU->STATUS;
        uint32_t sa  = NPU_SA->STATUS;

        int load_idle  = (lsu & LSU_LOAD_FIFO_EMPTY_BIT)
                      && !(lsu & LSU_LOAD_BUSY_BIT);
        int store_idle = (lsu & LSU_STORE_FIFO_EMPTY_BIT)
                      && !(lsu & LSU_STORE_BUSY_BIT);
        int sa_idle    = (sa  & SA_FIFO_EMPTY_BIT)
                      && !(sa  & SA_BUSY_BIT);

        if (load_idle && store_idle && sa_idle) return;
    }
}
static inline void wait_start(void)
{
    while ((NPU_SLV_AXI->CTRL & (1 << 1)) == 0);
}

static inline void signal_done(void)
{
    NPU_SLV_AXI->STATUS = 1;
}
static inline void clear_status(void)
{
    NPU_SLV_AXI->STATUS = 0;
}

#endif