`timescale 1ns/1ps
(* use_dsp = "yes" *)
module PE#(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic weight_load_en_i,
    input logic signed [DATA_WIDTH-1:0] act_i,
    input logic signed [DATA_WIDTH-1:0] weight_i,
    input logic signed [ACC_WIDTH-1:0] partial_sum_i,
    output logic signed [ACC_WIDTH-1:0] partial_sum_o,
    output logic signed [DATA_WIDTH-1:0] act_o,
    output logic signed [DATA_WIDTH-1:0] weight_o
);

    logic signed [DATA_WIDTH-1:0] reg_act;
    logic signed [DATA_WIDTH-1:0] reg_weight;
    logic signed [ACC_WIDTH-1:0] accumulator;

initial begin
    reg_act = '0;
    reg_weight = '0;
    accumulator = '0;
end

    always_ff @( posedge clk_i ) begin
        // if(!rst_n_i) begin
        //     {reg_act,reg_weight,accumulator}<='0;
        // end else begin
        reg_act<=act_i;
        if(weight_load_en_i)
            reg_weight<=weight_i;
        accumulator<=act_i*reg_weight+partial_sum_i;
        // end
    end
    assign act_o=reg_act;
    assign weight_o=reg_weight;
    assign partial_sum_o=accumulator;
endmodule