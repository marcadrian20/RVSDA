`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// PE with shadow weights and two diagonal control waves.
//   shadow_weight : captured from the column weight bus when wl_en_i (load wave)
//   reg_weight    : active operand; copies shadow_weight when swap_i (swap wave)
// wl_en_o / swap_o are one-flop-per-PE copies that carry both waves rightward, so
// PE[i][j] sees them exactly j cycles after PE[i][0] -- the same skew as act_o.
// -----------------------------------------------------------------------------
(* use_dsp = "yes" *)
module PE#(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic wl_en_i,
    input  logic swap_i,
    input  logic signed [DATA_WIDTH-1:0] act_i,
    input  logic signed [DATA_WIDTH-1:0] weight_i,      // column weight bus
    input  logic signed [ACC_WIDTH-1:0]  partial_sum_i,
    output logic signed [ACC_WIDTH-1:0]  partial_sum_o,
    output logic signed [DATA_WIDTH-1:0] act_o,
    output logic wl_en_o,
    output logic swap_o
);
    logic signed [DATA_WIDTH-1:0] reg_act, reg_weight, shadow_weight;
    logic signed [ACC_WIDTH-1:0]  accumulator;

    initial begin
        reg_act = '0; reg_weight = '0; shadow_weight = '0; accumulator = '0;
        wl_en_o = 1'b0; swap_o = 1'b0;
    end

    always_ff @(posedge clk_i) begin
        reg_act <= act_i;
        if (wl_en_i) shadow_weight <= weight_i;
        if (swap_i)  reg_weight    <= shadow_weight;
        accumulator <= act_i*reg_weight + partial_sum_i;
        wl_en_o <= wl_en_i;
        swap_o  <= swap_i;
    end
    assign act_o         = reg_act;
    assign partial_sum_o = accumulator;
endmodule
