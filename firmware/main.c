#include <stdint.h>
// #include <stdbool.h>
#define SA_CTRL_REG_ADDR 0x800
#define SA_STATUS_REG_ADDR 0x804
#define SA_CMD_DESC_LO 0x808
#define SA_CMD_DESC_HI 0x80C
#define LSU_CTRL_REG_ADDR 0x810
#define LSU_STATUS_REG_ADDR 0x814
#define LSU_LOAD_DESC_LO 0x818
#define LSU_LOAD_DESC_HI 0x81C
#define LSU_STORE_DESC_LO 0x820
#define LSU_STORE_DESC_HI 0x824

#define LSU_STORE_EN_BIT 0
#define LSU_LOAD_EN_BIT 1

#define MAKE_DMA_DESCRIPTOR(len_bytes, internal_addr, axi_addr) \
        ((((uint64_t)(len_bytes) &0x1FFFULL) << 51) |            \
        (((uint64_t)(internal_addr) &0x7FFFFULL) << 32) |        \
        ((uint64_t)(axi_addr)))

#define MAKE_SYSTOLIC_OPERATION(relu, quant, quant_shift, out_offst, weight_offst, act_offst)   \
        ((((uint64_t)(relu) &0x1ULL) << 60) |                                                   \
        (((uint64_t)(quant) &0x1ULL) << 59) |                                                   \
        (((uint64_t)(quant_shift) &0x1FULL) << 54) |                                            \
        (((uint64_t)(out_offst) &0x3FFFFULL) << 36) |                                           \
        (((uint64_t)(weight_offst) &0x3FFFFULL) << 18) |                                        \
        ((uint64_t)(act_offst) &0x3FFFFULL))                                                    \

int main()
{
    volatile uint64_t *sa_cmd_desc = (volatile uint64_t *)SA_CMD_DESC_LO;
    volatile uint32_t *sa_ctrl_reg = (volatile uint32_t *)SA_CTRL_REG_ADDR;    
  
    volatile uint32_t *sa_status_reg = (volatile uint32_t *)SA_STATUS_REG_ADDR;    
    volatile uint32_t *lsu_ctrl_reg = (volatile uint32_t *)LSU_CTRL_REG_ADDR;
    volatile uint32_t *lsu_status_reg = (volatile uint32_t *)LSU_STATUS_REG_ADDR;
    volatile uint64_t *lsu_load_desc = (volatile uint64_t *)LSU_LOAD_DESC_LO;
    volatile uint64_t *lsu_store_desc = (volatile uint64_t *)LSU_STORE_DESC_LO;

    //load desc 0, 64 bytes from axi 0x0 to bram 0x0
    *lsu_load_desc = MAKE_DMA_DESCRIPTOR(
        64,
        0x00000,
        0x00000000
    );
    //start lsu
    *lsu_ctrl_reg = (1 << LSU_LOAD_EN_BIT);
    //load desc 1, 64 bytes from axi 0x0 to bram 0x0200 (1<<9)
    *lsu_load_desc = MAKE_DMA_DESCRIPTOR(
        64,
        (1<<9),
        0x00000000
    );
    // while((*lsu_status_reg&(1<<1))==0)
    //     ;
    for(uint32_t i = 0; i < 32; i++)
    {
        ;
    }
    // *sa_ctrl_reg = 1;
    //systolic operation cmd, relu =1, quant = 1, quant_shift = 0, output offst = 0x000, weight_offset = 0x00, act_offset = 0x00
    *sa_cmd_desc = MAKE_SYSTOLIC_OPERATION(1,1,0,0x0,0x0,0x0);
    // *sa_cmd_desc = MAKE_SYSTOLIC_OPERATION(1,1,0,0x0,0x0,0x0);
    while((*sa_status_reg&1)==0)
        ;
    *lsu_ctrl_reg |=(1 << LSU_STORE_EN_BIT);

    // *sa_ctrl_reg = 1;
    *lsu_store_desc = MAKE_DMA_DESCRIPTOR(
        64,
        0x00000,
        0x00000000
    );

    while(1);

    return 0;
}