`timescale 1ns/1ps

module Computation_Unit#(
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

localparam ROW_W = $clog2(ARRAY_SIZE);
// Register stages inside Quantization_Unit (data_i_reg, product_reg, rounded_reg,
// scaled_data_reg, output_reg).  Change this if the quantizer pipeline changes.
localparam QUANT_LATENCY = 5;

logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_stream;
logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] systolic_output;
logic [63:0] systolic_cmd_fifo_fifo_rdata;
logic systolic_cmd_fifo_fifo_re;
logic wl_src;

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

logic [4:0] quant_shift_amount;
logic signed [31:0] quant_mult;
logic [1:0] pool_type;
logic [11:0] pool_feature_width;
logic [11:0] pool_feature_height;
logic [23:0] pool_valid_pixels;
logic pool_cfg_valid;
logic [3:0] pool_shift_amount;

// ---------------- issue tag (from controller) ----------------
logic issue_valid, issue_first, issue_last, issue_accum_rd, issue_accum_wr, issue_relu, issue_push;
logic tile_done, tile_push;
logic [ROW_W-1:0] issue_row;
logic [BRAM_ADDR_WIDTH-1:0] issue_out_addr;

Execution_Controller #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
) execution_controller(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .cmd_fifo_empty_i(systolic_cmd_fifo_empty_o),
        .cmd_fifo_pop_o(systolic_cmd_fifo_fifo_re),
        .cmd_fifo_data_i(systolic_cmd_fifo_fifo_rdata),
        .quant_shift_amount_o(quant_shift_amount),
        .quant_mult_o(quant_mult),
        .pool_type_o(pool_type),
        .pool_feature_width_o(pool_feature_width),
        .pool_feature_height_o(pool_feature_height),
        .pool_valid_pixels_o(pool_valid_pixels),
        .pool_cfg_valid_o(pool_cfg_valid),
        .weight_mem_enb_o(weight_mem_enb_o),
        .weight_addrb_o(weight_addrb_o),
        .wl_src_o(wl_src),
        .act_mem_enb_o(act_mem_enb_o),
        .act_addrb_o(act_addrb_o),
        .issue_valid_o(issue_valid),
        .issue_first_o(issue_first),
        .issue_last_o(issue_last),
        .issue_row_o(issue_row),
        .issue_out_addr_o(issue_out_addr),
        .issue_accum_rd_o(issue_accum_rd),
        .issue_accum_wr_o(issue_accum_wr),
        .issue_relu_o(issue_relu),
        .issue_push_o(issue_push),
        .tile_done_i(tile_done),
        .tile_push_i(tile_push),
        .consumed_act_o(scu_consumed_act_o),
        .consumed_weight_o(scu_consumed_weight_o),
        .produced_out_o(scu_produced_out_o),
        .act_ready_i(scu_act_ready_i),
        .weight_ready_i(scu_weight_ready_i),
        .busy_o(sa_busy_o),
        .done_o(sa_done_o)
);

// ---------------- tag pipeline: all downstream control derives from here ----------------
logic acc_rd_en, acc_en, acc_wr_en;
logic [ROW_W-1:0] acc_rd_addr, acc_wr_addr;
logic pool_valid;
logic [BRAM_ADDR_WIDTH-1:0] pool_addr;
logic [1:0] pool_type_tag;
logic relu_tag;

Tag_Pipeline #(
    .ARRAY_SIZE(ARRAY_SIZE),
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .QUANT_LATENCY(QUANT_LATENCY)
) tag_pipeline (
    .clk_i(clk_i),
    .issue_valid_i(issue_valid),
    .issue_last_i(issue_last),
    .issue_row_i(issue_row),
    .issue_out_addr_i(issue_out_addr),
    .issue_accum_rd_i(issue_accum_rd),
    .issue_accum_wr_i(issue_accum_wr),
    .issue_pool_type_i(pool_type),
    .issue_relu_i(issue_relu),
    .issue_push_i(issue_push),
    .acc_rd_en_o(acc_rd_en),
    .acc_rd_addr_o(acc_rd_addr),
    .acc_en_o(acc_en),
    .acc_wr_en_o(acc_wr_en),
    .acc_wr_addr_o(acc_wr_addr),
    .pool_valid_o(pool_valid),
    .pool_addr_o(pool_addr),
    .pool_type_o(pool_type_tag),
    .relu_o(relu_tag),
    .tile_done_o(tile_done),
    .tile_push_o(tile_push)
);

// ---------------- activation path ----------------
// Memory_Block holds its last read value while enb is low.  The skew buffer is
// free-running, so idle cycles must feed zeros instead of re-feeding stale data.
logic act_rd_valid_q;
always_ff @(posedge clk_i) act_rd_valid_q <= act_mem_enb_o;

logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_masked;
assign activation_masked = act_rd_valid_q ? activation_mem_i : '0;

Window_Shift_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(DATA_WIDTH)
) Activation_Feeder (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(1'b1),
        .data_i(activation_masked), 
        .data_o(activation_stream)
    );

// Weight words are column-skewed exactly like activations are row-skewed; lane j output
// of word s appears at x+s+j, matching the capture wave inside the array.
logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_stream;
Window_Shift_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
) Weight_Feeder (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .en_i(1'b1),
        .data_i(weight_mem_i),
        .data_o(weight_stream)
    );

Systolic_Array #(
                .ARRAY_SIZE(ARRAY_SIZE),
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH))
    systolic_array(
                .clk_i(clk_i),
                .rst_n_i(rst_n_i),
                .wl_src_i(wl_src),
                .first_i(issue_valid & issue_first),
                .activation_i(activation_stream),
                .weight_i(weight_stream),
                .result_o(systolic_output)
    );

logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] deskew_output;
Window_Unskew_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(ACC_WIDTH)
) Output_Deskewer (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(1'b1),
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
    .addra_i(acc_wr_addr),
    .addrb_i(acc_rd_addr),
    .we_i(acc_wr_en),
    .re_i(acc_rd_en),
    .accumulate_en_i(acc_en),
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
                .relu_en_i(relu_tag),
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
        .pool_type_i(pool_type_tag),
        .feature_width_i(pool_feature_width),
        .feature_height_i(pool_feature_height),
        .valid_pixels_i(pool_valid_pixels),
        .pool_cfg_valid_i(pool_cfg_valid),
        .data_valid_i(pool_valid), 
        .data_valid_o(output_mem_we_o),
        .output_addr_i(pool_addr), 
        .output_addr_o(output_addra_o),
        .data_i(quantized_data), 
        .data_o(output_mem_o) 
    );
endmodule
