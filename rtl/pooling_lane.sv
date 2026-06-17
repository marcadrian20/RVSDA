`timescale 1ns/1ps

module Pooling_Lane #(
    parameter MAX_FEATURE_WIDTH = 26,
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    // input logic [3:0] pool_shift_amount_i,
    input logic [1:0] pool_type_i,
    input logic data_valid_i,
    input logic [11:0] pixel_x_i,
    input logic [11:0] pixel_y_i,
    input logic [11:0] pool_col_idx_i,
    // input logic output_mem_we_i,
    // output logic output_mem_we_o,
(* mark_debug = "true" *)    input logic signed [DATA_WIDTH-1: 0] lane_data_i,
(* mark_debug = "true" *)    output logic signed [DATA_WIDTH-1:0] lane_data_o

);
localparam BYPASS = 2'b00;
localparam MAX_POOL = 2'b01;
localparam AVG_POOL = 2'b10;
localparam GLOBAL_AVG_POOL = 2'b11;
logic signed [DATA_WIDTH-1:0] line_buffer [(MAX_FEATURE_WIDTH/2)-1:0];
// logic signed [ACC_WIDTH-1:0] avg_line_buffer [(MAX_FEATURE_WIDTH/2)-1:0];
logic signed [DATA_WIDTH-1:0] max_out_reg;
// logic signed [ACC_WIDTH-1:0] avg_out_reg; 
// logic signed [DATA_WIDTH-1:0] avg_pool_out;
(* mark_debug = "true" *)logic odd_col, odd_row;
assign odd_col = pixel_x_i[0];
assign odd_row = pixel_y_i[0];
always_ff @( posedge clk_i ) begin
    if (!rst_n_i) begin
        max_out_reg <= '0;
        // avg_out_reg <= '0;
        for(int i = 0; i < MAX_FEATURE_WIDTH/2; i++) begin
                line_buffer[i]     <= '0;
                // avg_line_buffer[i] <= '0;
            end
    end else if(data_valid_i) begin
         if(!odd_row) begin
            if(!odd_col) begin
                line_buffer[pool_col_idx_i] <= lane_data_i;
                // avg_line_buffer[pool_col_idx_i]<= $signed(lane_data_i);    
            end else begin
                line_buffer[pool_col_idx_i] <= (line_buffer[pool_col_idx_i]>lane_data_i)?line_buffer[pool_col_idx_i]:lane_data_i;
                // avg_line_buffer[pool_col_idx_i]<= avg_line_buffer[pool_col_idx_i]+$signed(lane_data_i);
            end
        end
        else begin
            if(!odd_col) begin 
                line_buffer[pool_col_idx_i] <= (line_buffer[pool_col_idx_i]>lane_data_i)?line_buffer[pool_col_idx_i]:lane_data_i;
                // avg_line_buffer[pool_col_idx_i]<= avg_line_buffer[pool_col_idx_i]+$signed(lane_data_i);
            end
            else begin
                max_out_reg <= (line_buffer[pool_col_idx_i]>lane_data_i)?line_buffer[pool_col_idx_i]:lane_data_i;
                // avg_out_reg <= (avg_line_buffer[pool_col_idx_i]+$signed(lane_data_i))>>>2;
            end
        end
    end
end

// logic signed [ACC_WIDTH-1:0] shft_avg;
// assign shft_avg = avg_line_buffer[pool_col_idx_i]>>>2;
// assign lane_data_o = (pool_type_i == MAX_POOL)? max_out_reg:avg_out_reg[DATA_WIDTH-1:0];
assign lane_data_o = max_out_reg;
// assign avg_pool_out = avg_line_buffer
endmodule