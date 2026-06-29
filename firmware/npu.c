#include "npu.h"
#include "npu_regs.h"
#include "npu_types.h"



void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                      uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                      uint16_t M_dim, uint16_t N_dim, uint16_t K_dim, uint8_t relu_en, pool_type_t pool_type)
{
    static const uint8_t BRAM_TILE_STRIDE = 8;
    static const uint8_t AXI_TILE_STRIDE = 0x40; // its just 64 since 64 bytes is the size in bytes for an 8x8 tile
    static const uint8_t TILE_SIZE_BYTES = 64;

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
            if (pool_type == POOL_BYPASS)
            {
                uint32_t out_axi_addr = out_axi_base + (i * n_tile_count + j) * AXI_TILE_STRIDE;
                npu_lsu_push_store(TILE_SIZE_BYTES, out_offset, out_axi_addr, SIGNAL_DONE);
            }
        }
    }
}

void conv_pooled(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                 uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                 uint16_t input_width, uint16_t input_height, uint16_t kernel_width,
                 uint16_t kernel_height, uint16_t in_channels, uint16_t out_channels, uint8_t stride, uint8_t pad,
                 uint8_t relu_en, pool_type_t pool_type, uint32_t quant_mult, uint8_t shift_amount)
{
    uint16_t out_height = (input_height + 2 * pad - kernel_height) / stride + 1;
    uint16_t out_width = (input_width + 2 * pad - kernel_width) / stride + 1;
    uint16_t pooled_width = out_width >> 1;
    uint16_t pooled_height = out_height >> 1;
    const uint32_t pooled_pixels = pooled_width *
                                   pooled_height;
    const uint32_t valid_pixels = out_height * out_width;

    uint16_t M = out_height * out_width;
    uint16_t K = kernel_height * kernel_width * in_channels;
    uint16_t N = out_channels;

    uint16_t M_pad = ((M + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    uint16_t N_pad = ((N + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    uint16_t K_pad = ((K + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    npu_pool_push_cfg(out_width, out_height, valid_pixels);
    npu_quant_push_cfg(quant_mult, shift_amount);

    npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
                     act_axi_base, weight_axi_base, out_axi_base,
                     M_pad, N_pad, K_pad, relu_en, pool_type);

    store_pooled_featuremap(out_bram_base, out_axi_base, pooled_pixels, pool_type);
}


void dense_layer(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
                 uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
                 uint16_t in_features, uint16_t out_features, uint32_t quant_mult, uint8_t shift_amount)
{
    
    // uint16_t M = 1;
    uint16_t K = in_features;
    uint16_t N = out_features;

    uint16_t M_pad = 8;//((M + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    uint16_t N_pad = ((N + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    uint16_t K_pad = ((K + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
    npu_quant_push_cfg(quant_mult, shift_amount);

    npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
                     act_axi_base, weight_axi_base, out_axi_base,
                     M_pad, N_pad, K_pad, 0, POOL_BYPASS);

}


void npu_init(void)
{
    npu_lsu_enable_channel(1, 1);
}
uint32_t npu_get_ddr_base(void)
{
    return NPU_SLV_AXI->DDR_BASE_REG;
}