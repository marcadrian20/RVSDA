#include <stdint.h>
// #include <stdbool.h>
#define DISPATCH_REG_ADDR 0x800
#define STATUS_REG_ADDR 0x804
#define WEIGHT_MEM_OFFSET_REG 0x808
#define ACT_MEM_OFFSET_REG 0x80C
int main()
{
    volatile uint32_t *dispatch_reg = (volatile uint32_t *)DISPATCH_REG_ADDR;    
    volatile uint32_t *weight_mem_offst_reg = (volatile uint32_t *)WEIGHT_MEM_OFFSET_REG;    
    volatile uint32_t *act_mem_offst_reg = (volatile uint32_t *)ACT_MEM_OFFSET_REG;    
    volatile uint32_t *status_reg = (volatile uint32_t *)STATUS_REG_ADDR;    
    
    *weight_mem_offst_reg = 0;
    *act_mem_offst_reg = 0;
    *dispatch_reg = 1;
    while((*status_reg&1)==0)
        ;
    *dispatch_reg = 1;
    // while(1);

    return 0;
}