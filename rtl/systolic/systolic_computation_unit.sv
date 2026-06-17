`timescale 1ns/1ps

module Systolic_Computation_Unit#(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter BRAM_ADDR_WIDTH = 9
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [63:0] systolic_cmd_fifo_wdata_i,
    input logic systolic_cmd_fifo_fifo_we_i,
    output logic systolic_cmd_fifo_full_o,
    output logic systolic_cmd_fifo_empty_o,
    output logic weight_mem_enb_o,
    output logic [BRAM_ADDR_WIDTH-1:0] weight_addrb_o,
    output logic act_mem_enb_o, 
    output logic [BRAM_ADDR_WIDTH-1:0] act_addrb_o, 
    output logic [BRAM_ADDR_WIDTH-1:0] output_addra_o,
    output logic output_mem_we_o, 
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_mem_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_mem_i,
    output logic [DATA_WIDTH*ARRAY_SIZE-1:0] output_mem_o,

    input logic scu_act_ready_i,
    input logic scu_weight_ready_i,
    output logic scu_consumed_act_o,
    output logic scu_consumed_weight_o,
    output logic scu_produced_out_o,
    output logic sa_done_o,
    output logic sa_busy_o
);

logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_stream;
logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] systolic_output;
logic [63:0] systolic_cmd_fifo_fifo_rdata;
// logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] output_deskew_data;
logic act_data_feeder_en, output_data_deskewer_en;
FIFO  #(.DATA_WIDTH(64),
        .FIFO_DEPTH(8),
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
logic signed [31:0] quant_mult;
logic [$clog2(ARRAY_SIZE)-1:0] accumulate_rd_addr;
logic [$clog2(ARRAY_SIZE)-1:0] accumulate_wr_addr;
logic accumulate_rd_en, accumulate_wr_en, accumulate_en;
logic output_mem_valid;
logic [BRAM_ADDR_WIDTH-1:0] output_addr_before_pooling;
logic [3:0] pool_shift_amount;
logic [1:0] pool_type;
logic [11:0] pool_feature_width;
logic [11:0] pool_feature_height;
logic [23:0] pool_valid_pixels;

logic pool_cfg_valid;
Systolic_Controller #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
) systolic_controller(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .cmd_fifo_empty_i(systolic_cmd_fifo_empty_o),
        .cmd_fifo_pop_o(systolic_cmd_fifo_fifo_re),
        .cmd_fifo_data_i(systolic_cmd_fifo_fifo_rdata),
        .quant_en_o(quant_en),
        .relu_en_o(relu_en),
        .quant_shift_amount_o(quant_shift_amount),
        .quant_mult_o(quant_mult),
        .pool_type_o(pool_type),
        .pool_feature_width_o(pool_feature_width),
        .pool_feature_height_o(pool_feature_height),
        .pool_valid_pixels_o(pool_valid_pixels),
        .pool_cfg_valid_o(pool_cfg_valid),
        .act_data_feeder_en_o(act_data_feeder_en),
        .output_data_deskewer_en_o(output_data_deskewer_en),
        .accumulate_en_o(accumulate_en),
        .accumulate_rd_en_o(accumulate_rd_en),
        .accumulate_wr_en_o(accumulate_wr_en),
        .accumulate_rd_addr_o(accumulate_rd_addr),
        .accumulate_wr_addr_o(accumulate_wr_addr),
        .weight_mem_enb_o(weight_mem_enb_o),
        .weight_load_en_o(weight_load_en),
        .act_mem_enb_o(act_mem_enb_o),
        .output_mem_we_o(output_mem_valid),
        .weight_addrb_o(weight_addrb_o),
        .act_addrb_o(act_addrb_o),
        .output_addra_o(output_addr_before_pooling),
        .act_ready_i(scu_act_ready_i),         
        .weight_ready_i(scu_weight_ready_i),         
        .consumed_act_o(scu_consumed_act_o),         
        .consumed_weight_o(scu_consumed_weight_o),         
        .produced_out_o(scu_produced_out_o),
        .busy_o(sa_busy_o),
        .done_o(sa_done_o)
);

Systolic_Array #(
                .ARRAY_SIZE(ARRAY_SIZE),
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH))
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
logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] deskew_output;
Window_Unskew_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(ACC_WIDTH)
) Output_Deskewer (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(output_data_deskewer_en),
        .data_i(systolic_output), 
        .data_o(deskew_output)
    );

logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] accumulation_buff_output;
Accumulation_Buffer #( 
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(ACC_WIDTH)
)accumulation_buff(
    .clk_i(clk_i), 
    .rst_n_i(rst_n_i), 
    .addra_i(accumulate_wr_addr),
    .addrb_i(accumulate_rd_addr),
    .we_i(accumulate_wr_en),
    .re_i(accumulate_rd_en),
    .accumulate_en_i(accumulate_en),
    .data_i(deskew_output),
    .data_o(accumulation_buff_output)
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
                .quant_mult_i(quant_mult),
                .shift_amount_i(quant_shift_amount),
                .relu_en_i(relu_en),
                .data_i(accumulation_buff_output[i*ACC_WIDTH +: ACC_WIDTH]),
                .quantized_data_o(quantized_data[i*DATA_WIDTH +: DATA_WIDTH])
            );
    end
endgenerate
assign pool_shift_amount = '0;
Pooling_Unit #(
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
    )pooling_unit(
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .pool_shift_amount_i(pool_shift_amount),
        .pool_type_i(pool_type),
        .feature_width_i(pool_feature_width),
        .feature_height_i(pool_feature_height),
        .valid_pixels_i(pool_valid_pixels),
        .pool_cfg_valid_i(pool_cfg_valid),
        .data_valid_i(output_mem_valid), 
        .data_valid_o(output_mem_we_o),
        .output_addr_i(output_addr_before_pooling), 
        .output_addr_o(output_addra_o),
        // .output_mem_we_i(), 
        // .output_mem_we_o(),
        .data_i(quantized_data), 
        .data_o(output_mem_o) 
    );
endmodule