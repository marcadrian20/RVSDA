#include "npu.h"

void npu_tiled_matmul(uint32_t act_bram_base,
                      uint32_t weight_bram_base,
                      uint32_t out_bram_base,
                      uint32_t act_axi_base,
                      uint32_t weight_axi_base,
                      uint32_t out_axi_base,
                      uint16_t M_dim,
                      uint16_t N_dim,
                      uint16_t K_dim,
                      uint8_t relu_en,
                      pool_type_t pool_type)
{
    /* Dimensions are padded to multiples of eight by the callers. */
    const uint32_t m_tiles = ((uint32_t)M_dim + 7U) >> 3;
    const uint32_t n_tiles = ((uint32_t)N_dim + 7U) >> 3;
    const uint32_t k_tiles = ((uint32_t)K_dim + 7U) >> 3;

    const uint32_t act_bram_row_step = k_tiles << 3;
    const uint32_t act_axi_row_step = k_tiles << 6;
    const uint32_t weight_bram_col_step = n_tiles << 3;
    const uint32_t weight_axi_col_step = n_tiles << 6;
    const uint32_t out_bram_row_step = n_tiles << 3;
    const uint32_t out_axi_row_step = n_tiles << 6;

    uint32_t act_bram_i = act_bram_base;
    uint32_t act_axi_i = act_axi_base;
    uint32_t out_bram_i = out_bram_base;
    uint32_t out_axi_i = out_axi_base;

    for (uint32_t i = 0U; i < m_tiles; ++i)
    {
        uint32_t out_bram_j = out_bram_i;
        uint32_t out_axi_j = out_axi_i;
        uint32_t weight_bram_j = weight_bram_base;
        uint32_t weight_axi_j = weight_axi_base;

        for (uint32_t j = 0U; j < n_tiles; ++j)
        {
            uint32_t act_bram_k = act_bram_i;
            uint32_t act_axi_k = act_axi_i;
            uint32_t weight_bram_k = weight_bram_j;
            uint32_t weight_axi_k = weight_axi_j;

            for (uint32_t k = 0U; k < k_tiles; ++k)
            {
                if (j == 0U)
                {
                    npu_lsu_push_load(64U, act_bram_k,
                                      act_axi_k, SIGNAL_DONE);
                }

                if (i == 0U)
                {
                    npu_lsu_push_load(64U, weight_bram_k,
                                      weight_axi_k, SIGNAL_DONE);
                }

                // npu_sa_push_op((uint8_t)(j == 0U),
                //                (uint8_t)(i == 0U),
                //                (uint8_t)(k == (k_tiles - 1U)),
                //                pool_type,
                //                (uint8_t)(k != 0U),
                //                (uint8_t)(k != (k_tiles - 1U)),
                //                relu_en,
                //                out_bram_j,
                //                weight_bram_k,
                //                act_bram_k);
                const uint8_t last_k   = (k == k_tiles - 1U);
                const uint8_t push_out = (pool_type == POOL_BYPASS)
                                    ? last_k
                                    : (last_k && i == m_tiles - 1U && j == n_tiles - 1U);

                npu_sa_push_op((uint8_t)(j == 0U), (uint8_t)(i == 0U), push_out, pool_type,
                            (uint8_t)(k != 0U), (uint8_t)(k != (k_tiles - 1U)), relu_en,
                            out_bram_j, weight_bram_k, act_bram_k);
                act_bram_k += 8U;
                act_axi_k += 64U;
                weight_bram_k += weight_bram_col_step;
                weight_axi_k += weight_axi_col_step;
            }

            if (pool_type == POOL_BYPASS)
            {
                while (!(NPU_SA->STATUS & SA_FIFO_EMPTY_BIT)) ;
                while ( NPU_SA->STATUS & SA_BUSY_BIT) ;
                npu_lsu_push_store(64U, out_bram_j,
                                   out_axi_j, SIGNAL_DONE);
            }

            out_bram_j += 8U;
            out_axi_j += 64U;
            weight_bram_j += 8U;
            weight_axi_j += 64U;
        }

        act_bram_i += act_bram_row_step;
        act_axi_i += act_axi_row_step;
        out_bram_i += out_bram_row_step;
        out_axi_i += out_axi_row_step;
    }
}

void conv_pooled(uint32_t act_bram_base,
                 uint32_t weight_bram_base,
                 uint32_t out_bram_base,
                 uint32_t act_axi_base,
                 uint32_t weight_axi_base,
                 uint32_t out_axi_base,
                 uint16_t input_width,
                 uint16_t input_height,
                 uint16_t kernel_width,
                 uint16_t kernel_height,
                 uint16_t in_channels,
                 uint16_t out_channels,
                 uint8_t stride,
                 uint8_t pad,
                 uint8_t relu_en,
                 pool_type_t pool_type,
                 uint32_t quant_mult,
                 uint8_t shift_amount)
{
    /* stride must be nonzero, as in the original implementation. */
    const uint32_t height_num = (uint32_t)input_height +
                                (2U * (uint32_t)pad) - kernel_height;
    const uint32_t width_num = (uint32_t)input_width +
                               (2U * (uint32_t)pad) - kernel_width;

    uint16_t out_height;
    uint16_t out_width;

    /* Avoid software division for the common CNN strides. */
    if (stride == 1U)
    {
        out_height = height_num + 1U;
        out_width = width_num + 1U;
    }
    else if (stride == 2U)
    {
        out_height = (height_num >> 1) + 1U;
        out_width = (width_num >> 1) + 1U;
    }
    else
    {
        out_height = height_num / stride + 1U;
        out_width = width_num / stride + 1U;
    }

    const uint32_t pooled_width = out_width >> 1;
    const uint32_t pooled_height = out_height >> 1;
    const uint32_t pooled_pixels = pooled_width * pooled_height;
    const uint32_t valid_pixels = (uint32_t)out_height * out_width;

    /* Keep the original 16-bit dimension/padding semantics. */
    const uint16_t m = (uint16_t)valid_pixels;
    const uint16_t k = (uint16_t)((uint32_t)kernel_height *
                                  kernel_width * in_channels);
    const uint16_t n = out_channels;

    const uint16_t m_pad = (uint16_t)(((uint32_t)m + 7U) & ~7U);
    const uint16_t n_pad = (uint16_t)(((uint32_t)n + 7U) & ~7U);
    const uint16_t k_pad = (uint16_t)(((uint32_t)k + 7U) & ~7U);

    npu_pool_push_cfg((uint16_t)out_width, (uint16_t)out_height,
                      valid_pixels);
    npu_quant_push_cfg(quant_mult, shift_amount);

    npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
                     act_axi_base, weight_axi_base, out_axi_base,
                     m_pad, n_pad, k_pad, relu_en, pool_type);

    store_pooled_featuremap(out_bram_base, out_axi_base,
                            pooled_pixels, pool_type);
}

void dense_layer(uint32_t act_bram_base,
                 uint32_t weight_bram_base,
                 uint32_t out_bram_base,
                 uint32_t act_axi_base,
                 uint32_t weight_axi_base,
                 uint32_t out_axi_base,
                 uint16_t in_features,
                 uint16_t out_features,
                 uint32_t quant_mult,
                 uint8_t shift_amount)
{
    const uint16_t n_pad = (uint16_t)(((uint32_t)out_features + 7U) & ~7U);
    const uint16_t k_pad = (uint16_t)(((uint32_t)in_features + 7U) & ~7U);

    npu_quant_push_cfg(quant_mult, shift_amount);

    npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
                     act_axi_base, weight_axi_base, out_axi_base,
                     8U, n_pad, k_pad, 0U, POOL_BYPASS);
}

void npu_init(void)
{
    npu_lsu_enable_channel(1U, 1U);
}

uint32_t npu_get_ddr_base(void)
{
    return NPU_SLV_AXI->DDR_BASE_REG;
}


// #include "npu.h"
// #include "npu_regs.h"
// #include "npu_types.h"



// void npu_tiled_matmul(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
//                       uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
//                       uint16_t M_dim, uint16_t N_dim, uint16_t K_dim, uint8_t relu_en, pool_type_t pool_type)
// {
//     static const uint8_t BRAM_TILE_STRIDE = 8;
//     static const uint8_t AXI_TILE_STRIDE = 0x40; // its just 64 since 64 bytes is the size in bytes for an 8x8 tile
//     static const uint8_t TILE_SIZE_BYTES = 64;

//     uint16_t m_tile_count = (M_dim + TILE_SIZE - 1) / TILE_SIZE;
//     uint16_t n_tile_count = (N_dim + TILE_SIZE - 1) / TILE_SIZE;
//     uint16_t k_tile_count = (K_dim + TILE_SIZE - 1) / TILE_SIZE;

//     for (uint16_t i = 0; i < m_tile_count; i++)
//     {
//         for (uint16_t j = 0; j < n_tile_count; j++)
//         {
//             uint32_t out_offset = out_bram_base + (i * n_tile_count + j) * BRAM_TILE_STRIDE;

//             for (uint16_t k = 0; k < k_tile_count; k++)
//             {
//                 uint32_t act_offset = act_bram_base + (i * k_tile_count + k) * BRAM_TILE_STRIDE;
//                 uint32_t weight_offset = weight_bram_base + (k * n_tile_count + j) * BRAM_TILE_STRIDE;
//                 if (j == 0)
//                 {
//                     uint32_t act_axi_addr = act_axi_base + (i * k_tile_count + k) * AXI_TILE_STRIDE;
//                     npu_lsu_push_load(TILE_SIZE_BYTES, act_offset, act_axi_addr, SIGNAL_DONE);
//                 }
//                 if (i == 0)
//                 {
//                     uint32_t weight_axi_addr = weight_axi_base + (k * n_tile_count + j) * AXI_TILE_STRIDE;
//                     npu_lsu_push_load(TILE_SIZE_BYTES, weight_offset, weight_axi_addr, SIGNAL_DONE);
//                 }
//                 uint8_t accum_out = (k != 0);
//                 uint8_t accum_in = (k != k_tile_count - 1);
//                 uint8_t consume_act = (j == 0);
//                 uint8_t consume_weight = (i == 0);
//                 uint8_t signal_done = (k == k_tile_count - 1) ? SIGNAL_DONE : SIGNAL_NONE;
//                 npu_sa_push_op(consume_act, consume_weight, signal_done, pool_type, accum_out, accum_in, relu_en, out_offset, weight_offset, act_offset);
//             }
//             if (pool_type == POOL_BYPASS)
//             {
//                 uint32_t out_axi_addr = out_axi_base + (i * n_tile_count + j) * AXI_TILE_STRIDE;
//                 npu_lsu_push_store(TILE_SIZE_BYTES, out_offset, out_axi_addr, SIGNAL_DONE);
//             }
//         }
//     }
// }

// void conv_pooled(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
//                  uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
//                  uint16_t input_width, uint16_t input_height, uint16_t kernel_width,
//                  uint16_t kernel_height, uint16_t in_channels, uint16_t out_channels, uint8_t stride, uint8_t pad,
//                  uint8_t relu_en, pool_type_t pool_type, uint32_t quant_mult, uint8_t shift_amount)
// {
//     uint16_t out_height = (input_height + 2 * pad - kernel_height) / stride + 1;
//     uint16_t out_width = (input_width + 2 * pad - kernel_width) / stride + 1;
//     uint16_t pooled_width = out_width >> 1;
//     uint16_t pooled_height = out_height >> 1;
//     const uint32_t pooled_pixels = pooled_width *
//                                    pooled_height;
//     const uint32_t valid_pixels = out_height * out_width;

//     uint16_t M = out_height * out_width;
//     uint16_t K = kernel_height * kernel_width * in_channels;
//     uint16_t N = out_channels;

//     uint16_t M_pad = ((M + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     uint16_t N_pad = ((N + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     uint16_t K_pad = ((K + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     npu_pool_push_cfg(out_width, out_height, valid_pixels);
//     npu_quant_push_cfg(quant_mult, shift_amount);

//     npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
//                      act_axi_base, weight_axi_base, out_axi_base,
//                      M_pad, N_pad, K_pad, relu_en, pool_type);

//     store_pooled_featuremap(out_bram_base, out_axi_base, pooled_pixels, pool_type);
// }


// void dense_layer(uint32_t act_bram_base, uint32_t weight_bram_base, uint32_t out_bram_base,
//                  uint32_t act_axi_base, uint32_t weight_axi_base, uint32_t out_axi_base,
//                  uint16_t in_features, uint16_t out_features, uint32_t quant_mult, uint8_t shift_amount)
// {
    
//     // uint16_t M = 1;
//     uint16_t K = in_features;
//     uint16_t N = out_features;

//     uint16_t M_pad = 8;//((M + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     uint16_t N_pad = ((N + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     uint16_t K_pad = ((K + TILE_SIZE - 1) / TILE_SIZE) * TILE_SIZE;
//     npu_quant_push_cfg(quant_mult, shift_amount);

//     npu_tiled_matmul(act_bram_base, weight_bram_base, out_bram_base,
//                      act_axi_base, weight_axi_base, out_axi_base,
//                      M_pad, N_pad, K_pad, 0, POOL_BYPASS);

// }


// void npu_init(void)
// {
//     npu_lsu_enable_channel(1, 1);
// }
// uint32_t npu_get_ddr_base(void)
// {
//     return NPU_SLV_AXI->DDR_BASE_REG;
// }