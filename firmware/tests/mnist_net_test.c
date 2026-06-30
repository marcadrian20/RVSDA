#include <stdint.h>
#include "../npu.h"
#include "../npu_regs.h"

#define INPUT_WIDTH 28
#define INPUT_HEIGHT 28
#define KERNEL_WIDTH 3
#define KERNEL_HEIGHT 3
#define INPUT_CHANNELS 1
#define OUTPUT_CHANNELS 8
#define CONV_STRIDE 1
#define CONV_PADDING 0
#define CONV_RELU_ENABLE 1
#define CONV_M0 1529741541
#define CONV_SHIFT 8

#define FC_INPUT_SIZE 1352
#define FC_OUTPUT_SIZE 10
#define FC_M0 1417290823
#define FC_SHIFT 10

int main()
{
    uint32_t axi_ddr_base = npu_get_ddr_base();
    npu_init();
    while (1)
    {
        wait_start();
        conv_pooled(NPU_ACTIVATION_BASE,
                    NPU_WEIGHT_BASE,
                    NPU_OUTPUT_BASE,

                    axi_ddr_base + 0x5500, /*Activation matrix address*/
                    axi_ddr_base + 0x0000, /*Weights matrix address*/
                    axi_ddr_base + 0x7F80, /*Output address*/
                    INPUT_WIDTH, INPUT_HEIGHT, KERNEL_WIDTH, KERNEL_HEIGHT, INPUT_CHANNELS, OUTPUT_CHANNELS,
                    CONV_STRIDE, CONV_PADDING, CONV_RELU_ENABLE, MAX_POOL, CONV_M0, CONV_SHIFT);
        mem_fence();
        signal_done();
        wait_start();
        clear_status();
        dense_layer(
            NPU_ACTIVATION_BASE,
            NPU_WEIGHT_BASE,
            NPU_OUTPUT_BASE,
            axi_ddr_base + 0x5500, /*Activation matrix address*/
            axi_ddr_base + 0x0080, /*Weights matrix address*/
            axi_ddr_base + 0x7F80, /*Output address*/
            FC_INPUT_SIZE,
            FC_OUTPUT_SIZE,
            FC_M0,
            FC_SHIFT
        );
        signal_done();
    }
    while (1)
        ;
    return 0;
}
