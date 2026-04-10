`timescale 1ns/1ps

module Systolic_Array #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic dispatch_i,
    input logic weight_load_en_i,
    // input logic stall,
    // output logic done_o,
    output logic busy_o,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_i,
    output logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] result_o
);

logic signed [DATA_WIDTH-1:0] PE_ARR_activation_feed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
logic signed [DATA_WIDTH-1:0] PE_ARR_weight_feed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
logic signed [ACC_WIDTH-1:0] PE_ARR_partial_sum_feed [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];


generate
    genvar i,j;
    for (i = 0; i<ARRAY_SIZE; i++ ) begin: gen_row
        for (j = 0; j<ARRAY_SIZE; j++ ) begin: gen_col
            PE#(.DATA_WIDTH(DATA_WIDTH))
            processing_element(
                .clk_i(clk_i),
                .rst_n_i(rst_n_i),
                .weight_load_en_i(weight_load_en_i),
                .act_i((j==0)?activation_i[i*DATA_WIDTH+:DATA_WIDTH]:PE_ARR_activation_feed[i][j-1]),
                .weight_i((i==0)?weight_i[j*DATA_WIDTH+:DATA_WIDTH]:PE_ARR_weight_feed[i-1][j]),
                .partial_sum_i((i==0)?'0:PE_ARR_partial_sum_feed[i-1][j]),
                .partial_sum_o(PE_ARR_partial_sum_feed[i][j]),
                .act_o(PE_ARR_activation_feed[i][j]),
                .weight_o(PE_ARR_weight_feed[i][j])
            );
        end
    end
endgenerate
//#TODO for weights andd activations maybe try -: instead of +:? 
//#TODO maybe i should do an explicit if instead 
//##of conditional/ternary expressions for the PEs

logic signed [ACC_WIDTH-1 : 0]debug,debug2,debug3,debug4,debug5,debug6,debug7,debug8;

always_comb begin
    for (int i = 0; i<ARRAY_SIZE; i++ ) begin
        result_o[i*ACC_WIDTH +: ACC_WIDTH] = PE_ARR_partial_sum_feed[ARRAY_SIZE-1][i];
    end
end

always_comb begin
    debug=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][0];
    debug2=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][1];
    debug3=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][2];
    debug4=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][3];
    debug5=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][4];
    debug6=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][5];
    debug7=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][6];
    debug8=PE_ARR_partial_sum_feed[ARRAY_SIZE-1][7];
end
// generate
//     for (genvar i = 0; i<ARRAY_SIZE; i++ ) begin: gen_pack
//         assign RESULT_O[i*ACC_WIDTH +: ACC_WIDTH] = PE_ARR_partial_sum_feed[ARRAY_SIZE-1][i];
//     end
// endgenerate

endmodule