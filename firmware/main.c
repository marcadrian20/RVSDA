#include <stdint.h>
#include "npu.h"
#include "npu_regs.h"

int main()
{
    uint32_t axi_ddr_base = npu_get_ddr_base();
    // start lsu
    // npu_init();
    npu_lsu_enable_channel(1, 1);
    while (1)
    {
        while ((NPU_SLV_AXI->CTRL & (1 << 1)) == 0)
            ;
        // conv_pooled(NPU_ACTIVATION_BASE,
        //             NPU_WEIGHT_BASE,
        //             NPU_OUTPUT_BASE,

        //             axi_ddr_base + 0x0000, // A
        //             axi_ddr_base + 0x2A80, // B
        //             axi_ddr_base + 0x2B00, // C output
        //             28, 28, 3, 3, 1, 8, 1, 0, 1, POOL_BYPASS, 1581244756, 8);

        conv_pooled(NPU_ACTIVATION_BASE,
                    NPU_WEIGHT_BASE,
                    NPU_OUTPUT_BASE,

                    axi_ddr_base + 0x5500, // A
                    axi_ddr_base + 0x0000, // B
                    // axi_ddr_base + 0x2A80, // B
                    axi_ddr_base + 0x7F80, // C output
                    28, 28, 3, 3, 1, 8, 1, 0, 1, POOL_MAX, 1581244756, 8);
        mem_fence();

        NPU_SLV_AXI->STATUS = 1;
        while ((NPU_SLV_AXI->CTRL & (1 << 1)) == 0)
            ;
        NPU_SLV_AXI->STATUS = 0;

        npu_quant_push_cfg(1249548715, 10);
        npu_tiled_matmul(
            NPU_ACTIVATION_BASE,
            NPU_WEIGHT_BASE,
            NPU_OUTPUT_BASE,

            axi_ddr_base + 0x5500, // A
            // axi_ddr_base + 0x2A40, // B
            axi_ddr_base + 0x0080, // B
            axi_ddr_base + 0x7F80, // C output

            8,    // M
            16,   // N
            1352, // K

            0, // relu
            POOL_BYPASS);
        NPU_SLV_AXI->STATUS = 1;
    }
    while (1)
        ;

    return 0;
}
