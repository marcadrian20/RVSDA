`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Systolic_Array with shadow weights.
//
// Timing contract (x = cycle at which word 0 of a weight tile is on column 0 of
// weight_i; t = cycle in which the tile's first activation row is issued):
//   weight_i  : column-skewed (lane j delayed j) weight words; word s, column j is
//               present at cycle x+s+j.  The bus is broadcast down the column.
//   wl_src_i  : one-cycle pulse at cycle x.  Row i sees it at x+i, PE[i][j] at x+i+j,
//               i.e. PE[i][j] captures word i (= weight W[i][j]) into its shadow reg.
//   first_i   : one-cycle strobe at cycle t.  Row i sees it at t+1+i, PE[i][j] at
//               t+1+i+j, which is exactly one cycle before tile row 0 reaches that PE
//               (t+2+i+j), so the PE switches to the new weights just in time.
// Requirement: x <= t (shadow written before swapped) and the next tile's x >= t+1
// (shadow not overwritten before the swap).  Execution_Controller guarantees both.
// -----------------------------------------------------------------------------
module Systolic_Array #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic wl_src_i,
    input  logic first_i,
    input  logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_i,
    input  logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_i,
    output logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] result_o
);
    logic signed [DATA_WIDTH-1:0] act_feed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0]  psum_feed[ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic wl_feed  [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic swp_feed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    // left-edge wave sources: row i = source delayed i cycles
    logic [ARRAY_SIZE-1:0] wl_q, sw_q;
    initial begin wl_q = '0; sw_q = '0; end
    always_ff @(posedge clk_i) begin
        wl_q[0] <= 1'b0;                       // unused (row 0 takes wl_src_i directly)
        for (int i = 1; i < ARRAY_SIZE; i++) wl_q[i] <= (i == 1) ? wl_src_i : wl_q[i-1];
        sw_q[0] <= first_i;
        for (int i = 1; i < ARRAY_SIZE; i++) sw_q[i] <= sw_q[i-1];
    end

    generate
        genvar i, j;
        for (i = 0; i < ARRAY_SIZE; i++) begin: gen_row
            wire wl_row  = (i == 0) ? wl_src_i : wl_q[i];
            wire swp_row = sw_q[i];
            for (j = 0; j < ARRAY_SIZE; j++) begin: gen_col
                PE #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) processing_element (
                    .clk_i(clk_i), .rst_n_i(rst_n_i),
                    .wl_en_i ((j == 0) ? wl_row  : wl_feed [i][j-1]),
                    .swap_i  ((j == 0) ? swp_row : swp_feed[i][j-1]),
                    .act_i   ((j == 0) ? activation_i[i*DATA_WIDTH +: DATA_WIDTH] : act_feed[i][j-1]),
                    .weight_i(weight_i[j*DATA_WIDTH +: DATA_WIDTH]),
                    .partial_sum_i((i == 0) ? '0 : psum_feed[i-1][j]),
                    .partial_sum_o(psum_feed[i][j]),
                    .act_o(act_feed[i][j]),
                    .wl_en_o(wl_feed[i][j]),
                    .swap_o(swp_feed[i][j])
                );
            end
        end
    endgenerate

    always_comb
        for (int c = 0; c < ARRAY_SIZE; c++)
            result_o[c*ACC_WIDTH +: ACC_WIDTH] = psum_feed[ARRAY_SIZE-1][c];
endmodule
