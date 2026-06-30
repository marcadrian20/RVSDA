`timescale 1ns/1ps

module PE_tb;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_I_PERIOD = 10;

    logic clk_i;
    logic rst_n_i;
    logic weight_load_en_i;
    logic signed [DATA_WIDTH-1:0] act_i;
    logic signed [DATA_WIDTH-1:0] weight_i;
    logic signed [ACC_WIDTH-1:0] partial_sum_i;
    logic signed [ACC_WIDTH-1:0] partial_sum_o;
    logic signed [DATA_WIDTH-1:0] act_o;
    logic signed [DATA_WIDTH-1:0] weight_o;

    PE #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .weight_load_en_i(weight_load_en_i),
        .act_i(act_i),
        .weight_i(weight_i),
        .partial_sum_i(partial_sum_i),
        .partial_sum_o(partial_sum_o),
        .act_o(act_o),
        .weight_o(weight_o)
    );

    initial begin
        clk_i = 0;
        forever #(CLK_I_PERIOD/2) clk_i = ~clk_i;
    end

    initial begin
        $dumpfile("pe_tb.vcd");
        $dumpvars(0, PE_tb);
        $monitor("Time: %0tns | act_in: %0d | wgt_in: %0d | psum_in: %0d | act_out: %0d | wgt_out: %0d | psum_out: %0d",
                 $time, act_i, weight_i, partial_sum_i, act_o, weight_o, partial_sum_o);
    end

    initial begin
        rst_n_i = 0;
        weight_load_en_i = 0;
        act_i = 0;
        weight_i = 0;
        partial_sum_i = 0;
        #CLK_I_PERIOD;
        rst_n_i = 1;

        weight_load_en_i = 1;
   
        weight_i = 8'd3;
        partial_sum_i = 32'd0;
        #CLK_I_PERIOD;

        weight_load_en_i = 0;
        partial_sum_i = 32'd100;
        act_i = 8'd7;
        #CLK_I_PERIOD;

        // act_i = 8'd2;
        // #CLK_I_PERIOD;

        #CLK_I_PERIOD;
        $finish;
    end
endmodule