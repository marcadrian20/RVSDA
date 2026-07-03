#include <stdint.h>
#include "../npu.h"
#include "../npu_regs.h"




void mat_mul_extensive_test(uint32_t axi_ddr_base);
void tiled_mat_mul_test(uint32_t axi_ddr_base);
void simple_matrix_mult_test(uint32_t axi_ddr_base);
void simple_max_pool_avg_pool_test(uint32_t axi_ddr_base);
int main()
{
    uint32_t axi_ddr_base = NPU_SLV_AXI->DDR_BASE_REG;//NPU_DDR_BASE_REG;
    // start lsu
    npu_lsu_enable_channel(1, 1);
    while((NPU_SLV_AXI->CTRL & (1<<1))==0)
        ;
    mat_mul_extensive_test(axi_ddr_base);
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0x300, axi_ddr_base + 0x400, axi_ddr_base + 0x500, 16, 16, 16, 1, POOL_BYPASS);
    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0x800, axi_ddr_base + 0xA40, axi_ddr_base + 0xC80, 24, 24, 24, 1, POOL_BYPASS);
    simple_matrix_mult_test(axi_ddr_base);

    npu_tiled_matmul(NPU_ACTIVATION_BASE + 32, NPU_WEIGHT_BASE + 32, NPU_OUTPUT_BASE + 32, axi_ddr_base + 0xEC0, axi_ddr_base + 0xF80, axi_ddr_base + 0x1000, 24, 16, 8, 1, POOL_BYPASS);

    npu_pool_push_cfg(
        8, // feature_width
        8, // feature_height
        64 // valid_pixels
    );
    npu_lsu_push_load(64, NPU_WEIGHT_BASE + 128, axi_ddr_base + 0x00000140, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 128, axi_ddr_base + 0x1180, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 136, axi_ddr_base + 0x11C0, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 144, axi_ddr_base + 0x1200, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 152, axi_ddr_base + 0x1240, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 160, axi_ddr_base + 0x12C0, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 168, axi_ddr_base + 0x1280, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 176, axi_ddr_base + 0x1300, SIGNAL_DONE);
    npu_lsu_push_load(64, NPU_ACTIVATION_BASE + 184, axi_ddr_base + 0x1340, SIGNAL_DONE);

    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 128);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 136);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 144);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 152);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 160);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 168);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_NONE, SIGNAL_NONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 176);
    npu_sa_push_op(CONSUME_TOKEN, CONSUME_TOKEN, SIGNAL_DONE, MAX_POOL, 0, 0, 0, NPU_OUTPUT_BASE + 128, NPU_WEIGHT_BASE + 128, NPU_ACTIVATION_BASE + 184);

    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 128, axi_ddr_base + 0x1380, SIGNAL_DONE);
    npu_lsu_push_store(64, NPU_OUTPUT_BASE + 136, axi_ddr_base + 0x13C0, SIGNAL_DONE);
    
    NPU_SLV_AXI->STATUS = 1;

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
