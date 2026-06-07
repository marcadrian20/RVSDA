`timescale 1ns/1ps

module Quantization_Unit#(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [4:0] shift_amount_i,
    input logic relu_en_i,

    input logic signed [ACC_WIDTH-1 : 0] data_i,
    output logic signed [DATA_WIDTH-1 : 0] quantized_data_o
);
localparam signed [ACC_WIDTH-1:0] MAX_VAL = (1<<DATA_WIDTH-1)-1; //so basically im using 127 as an upper bound,
                                                                //as ive seen use for INT8 in different sources
localparam signed [ACC_WIDTH-1:0] MIN_VAL = -(1<<DATA_WIDTH-1); // -128 as an lower bound,

logic signed [ACC_WIDTH-1 : 0] scaled_data_reg;
    always_ff @( posedge clk_i ) begin : DATA_SCALE
        if(!rst_n_i) begin
            scaled_data_reg<='0;
        end else begin
            scaled_data_reg <= data_i >>> shift_amount_i;
        end
    end
logic signed [DATA_WIDTH-1:0] clamped_data;
    always_comb begin : CLAMP_ACTIVATE
        if(scaled_data_reg > MAX_VAL) begin
            clamped_data = MAX_VAL;
        end 
        else if(scaled_data_reg < MIN_VAL) begin
            clamped_data = MIN_VAL;    
        end 
        else 
            clamped_data = scaled_data_reg[DATA_WIDTH-1:0];
        quantized_data_o =(relu_en_i && clamped_data < 0)? '0 : clamped_data[DATA_WIDTH-1:0];
    end
endmodule