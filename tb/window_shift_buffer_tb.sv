`timescale 1ns/1ps
module Window_Shift_Buffer_tb;
    parameter ARRAY_SIZE = 8;
    parameter DATA_WIDTH = 8;
    parameter CLK_I_PERIOD = 10;
    
    logic clk_i;
    logic rst_n_i;
    logic en_i;
    logic [DATA_WIDTH*ARRAY_SIZE-1:0] data_i;
    logic [DATA_WIDTH*ARRAY_SIZE-1:0] data_o;
    
    Window_Shift_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(DATA_WIDTH)
    ) Window_Shift_Buffer_dut (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(en_i),
        .data_i(data_i), 
        .data_o(data_o)
    );
    
    initial begin
        clk_i = 0;
        forever #(CLK_I_PERIOD/2) clk_i = ~clk_i;
    end
    
    initial begin
        $dumpfile("window_shift_buffer_tb.vcd");
        $dumpvars(0, Window_Shift_Buffer_tb);
    end
    
    initial begin
        
        rst_n_i = 0;
        en_i = 0;
        data_i = '0;
        #CLK_I_PERIOD;
        rst_n_i = 1;
        
        $display("  Test 1: Sequential input  ");
        en_i = 1;
        
        for (int cycle = 0; cycle < 16; cycle++) begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                data_i[(i*DATA_WIDTH) +: DATA_WIDTH] = cycle + i + 1;
            end
            
            #1;
            
            $display("Cycle %0d | In: [", cycle);
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                $write("%0d ", data_i[(i*DATA_WIDTH) +: DATA_WIDTH]);
            end
            $write("] | Out: [");
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                $write("%0d ", data_o[(i*DATA_WIDTH) +: DATA_WIDTH]);
            end
            $display("]");
            
            #CLK_I_PERIOD;
        end
        
        $display("\n  Test 2: Enable disabled  ");
        en_i = 0;
        
        for (int cycle = 0; cycle < 3; cycle++) begin
            @(posedge clk_i);
            #1; 
            
            $display("Cycle (en=0) | Out: [");
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                $write("%0d ", data_o[(i*DATA_WIDTH) +: DATA_WIDTH]);
            end
            $display("]");
        end
        
        $finish;
    end
endmodule