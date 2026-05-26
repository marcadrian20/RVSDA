`timescale 1ns/1ps

module Systolic_Computation_Unit#(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [63:0] systolic_cmd_fifo_wdata_i,
    input logic systolic_cmd_fifo_fifo_we_i,
    output logic systolic_cmd_fifo_full_o,
    output logic systolic_cmd_fifo_empty_o,
    output logic weight_mem_enb_o,
    output logic [8:0] weight_addrb_o,
    output logic act_mem_enb_o, 
    output logic [8:0] act_addrb_o, 
    output logic [8:0] output_addrb_o,
    output logic output_mem_we_o, 
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_mem_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_mem_i,
    output logic [DATA_WIDTH*ARRAY_SIZE-1:0] output_mem_o,
    output logic sa_done_o,
    output logic sa_busy_o
);

logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_stream;
logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] systolic_output;
logic [63:0] systolic_cmd_fifo_fifo_rdata;
// logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] output_deskew_data;
logic act_data_feeder_en, output_data_deskewer_en;
FIFO  #(.DATA_WIDTH(32),
        .FIFO_DEPTH(4),
        .FWFT(1)
)systolic_cmd_fifo(
            .clk_i(clk_i),
            .rst_n_i(rst_n_i),
            .wdata_i(systolic_cmd_fifo_wdata_i),
            .we_i(systolic_cmd_fifo_fifo_we_i),
            .re_i(systolic_cmd_fifo_fifo_re),
            .full_o(systolic_cmd_fifo_full_o),
            .empty_o(systolic_cmd_fifo_empty_o),
            .rdata_o(systolic_cmd_fifo_fifo_rdata)    
        );

Window_Shift_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(DATA_WIDTH)
) Activation_Feeder (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(act_data_feeder_en),
        .data_i(activation_mem_i), 
        .data_o(activation_stream)
    );
logic quant_en, relu_en;
logic [4:0] quant_shift_amount;
Systolic_Controller #(
        .ARRAY_SIZE(ARRAY_SIZE)
) systolic_controller(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .cmd_fifo_empty_i(systolic_cmd_fifo_empty_o),
        .cmd_fifo_pop_o(systolic_cmd_fifo_fifo_re),
        .cmd_fifo_data_i(systolic_cmd_fifo_fifo_rdata),
        .quant_en_o(quant_en),
        .relu_en_o(relu_en),
        .quant_shift_amount_o(quant_shift_amount),
        .act_data_feeder_en_o(act_data_feeder_en),
        .output_data_deskewer_en_o(output_data_deskewer_en),
        .weight_mem_enb_o(weight_mem_enb_o),
        .weight_load_en_o(weight_load_en),
        .act_mem_enb_o(act_mem_enb_o),
        .output_mem_we_o(output_mem_we_o),
        .weight_addrb_o(weight_addrb_o),
        .act_addrb_o(act_addrb_o),
        .output_addrb_o(output_addrb_o),
        .busy_o(sa_busy_o),
        .done_o(sa_done_o)
);

Systolic_Array #(
                .ARRAY_SIZE(ARRAY_SIZE),
                .DATA_WIDTH(DATA_WIDTH))
    systolic_array(
                .clk_i(clk_i),
                .rst_n_i(rst_n_i),
                .dispatch_i(1'b0/*dispatch_reg*/),
                .weight_load_en_i(weight_load_en),
                // .sa_done_o(sa_done_o),
                .activation_i(activation_stream),
                .weight_i(weight_mem_i),
                .result_o(systolic_output)
    );

logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] quantized_data;
genvar  i;
generate
    for(i = 0; i < ARRAY_SIZE; i = i+1) begin : generate_quantizers
        Quantization_Unit #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
            )quant_unit(
                .clk_i(clk_i),
                .rst_n_i(rst_n_i),
                .shift_amount_i(quant_shift_amount),
                .relu_en_i(relu_en),
                .data_i(systolic_output[i*ACC_WIDTH +: ACC_WIDTH]),
                .quantized_data_o(quantized_data[i*DATA_WIDTH +: DATA_WIDTH])
            );
    end
endgenerate

Window_Unskew_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(DATA_WIDTH)
) Output_Deskewer (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(output_data_deskewer_en),
        .data_i(quantized_data), 
        .data_o(output_mem_o)
    );

endmodule