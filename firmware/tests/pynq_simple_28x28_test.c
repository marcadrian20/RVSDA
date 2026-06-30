#include <stdint.h>
#include "../npu.h"
#include "../npu_regs.h"

int main()
{
    uint32_t axi_ddr_base = npu_get_ddr_base();
    // start lsu
    npu_init();


    conv_pooled(NPU_ACTIVATION_BASE,
        NPU_WEIGHT_BASE,
        NPU_OUTPUT_BASE,

        axi_ddr_base + 0x5500,   // A
        axi_ddr_base + 0x0000,   // B
        axi_ddr_base + 0x7F80,   // C output
        28, 28, 3, 3, 1, 8, 1, 0, 1, POOL_BYPASS, 1529741541, 8);


    // conv_pooled(NPU_ACTIVATION_BASE,
    //     NPU_WEIGHT_BASE,
    //     NPU_OUTPUT_BASE,

    //     axi_ddr_base + 0x5500,   // A
    //     axi_ddr_base + 0x0000,   // B
    //     axi_ddr_base + 0x7F80,   // C output
    //     28, 28, 3, 3, 1, 8, 1, 0, 1, MAX_POOL, 1529741541, 8
    // );
    mem_fence();
    signal_done();
    wait_start();
    clear_status();
    npu_quant_push_cfg(1417290823, 10);
    npu_tiled_matmul(
        NPU_ACTIVATION_BASE,
        NPU_WEIGHT_BASE,
        NPU_OUTPUT_BASE,

        axi_ddr_base + 0x5500,   // A
        axi_ddr_base + 0x0080,   // B
        axi_ddr_base + 0x7F80,   // C output

        8,                     // M
        16,                       // N
        1352,                      // K

        0,                       // relu
     POOL_BYPASS
    );
    NPU_SLV_AXI->STATUS = 1;

    while (1)
        ;

    return 0;
}
