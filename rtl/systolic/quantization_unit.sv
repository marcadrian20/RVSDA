`timescale 1ns/1ps

module Quantization_Unit#(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [4:0] shift_amount_i,
    input logic signed [31:0] quant_mult_i,
    input logic relu_en_i,

    input logic signed [ACC_WIDTH-1 : 0] data_i,
    output logic signed [DATA_WIDTH-1 : 0] quantized_data_o
);
localparam signed [ACC_WIDTH-1:0] MAX_VAL = (1<<DATA_WIDTH-1)-1; //so basically im using 127 as an upper bound,
                                                                //as ive seen use for INT8 in different sources
localparam signed [ACC_WIDTH-1:0] MIN_VAL = -(1<<DATA_WIDTH-1); // -128 as an lower bound,


logic signed [(ACC_WIDTH+31)-1:0] product_reg;
logic [4:0] shift_amount_reg;
logic relu_en_reg;

//multiplies 32bit signed acc with the 32bit Multiplier
always_ff @( posedge clk_i ) begin : MULT_PIPELINE_STAGE
    if(!rst_n_i) begin
            product_reg<='0;
            shift_amount_reg<='0;
            relu_en_reg<='0;
        end else begin
            product_reg <= data_i * quant_mult_i;
            shift_amount_reg <= shift_amount_i;
            relu_en_reg <= relu_en_i;
        end
end


logic [5:0] total_shift;
logic signed [(ACC_WIDTH+31)-1:0] rounding_term;
logic signed [(ACC_WIDTH+31)-1:0] prod_rounded;
logic signed [ACC_WIDTH-1 : 0] scaled_data_reg;

always_comb begin : ROUNDING_MATH
    total_shift = 6'd31 + shift_amount_reg;
    rounding_term = 64'sd1 <<< (total_shift-1);
    
    if (total_shift > 0) begin
        if (product_reg >= 0) begin
            prod_rounded = product_reg + rounding_term;
        end else begin
                prod_rounded = product_reg + rounding_term - 64'sd1;
            end
    end else begin
        prod_rounded = product_reg;
    end
end


    always_ff @( posedge clk_i ) begin : DATA_SCALE_PIPELINE_STAGE
        if(!rst_n_i) begin
            scaled_data_reg<='0;
        end else begin
            scaled_data_reg <= $signed(prod_rounded >>> total_shift);
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