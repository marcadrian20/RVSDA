module Pooling_Lane #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    // input logic [3:0] pool_shift_amount_i,
    input logic [1:0] pool_type_i,
    input logic data_valid_i,
    input [3:0] pool_cnt_i,
    // input logic output_mem_we_i,
    // output logic output_mem_we_o,
    input logic signed [DATA_WIDTH-1: 0] lane_data_i,
    output logic signed [DATA_WIDTH-1:0] lane_data_o

);
localparam BYPASS = 2'b00;
localparam MAX_POOL = 2'b01;
localparam AVG_POOL = 2'b10;
localparam GLOBAL_AVG_POOL = 2'b11;
logic signed [DATA_WIDTH-1:0] line_buffer [ARRAY_SIZE/2-1:0];
logic signed [ACC_WIDTH-1:0] avg_line_buffer [ARRAY_SIZE/2-1:0];
logic signed [DATA_WIDTH-1:0] max_out_reg;
logic signed [ACC_WIDTH-1:0] avg_out_reg; 
// logic signed [DATA_WIDTH-1:0] avg_pool_out;
logic [1:0] pair_idx;
logic odd_col, odd_row;
assign pair_idx = pool_cnt_i[2:1];
assign odd_col = pool_cnt_i[0];
assign odd_row = pool_cnt_i[3];
always_ff @( posedge clk_i ) begin
    if (!rst_n_i) begin
        max_out_reg <= '0;
        avg_out_reg <= '0;
        for(int i = 0; i < ARRAY_SIZE/2; i++) begin
                line_buffer[i]     <= '0;
                avg_line_buffer[i] <= '0;
            end
    end else if(data_valid_i) begin
         if(!odd_row) begin
            if(!odd_col) begin
                line_buffer[pair_idx] <= lane_data_i;
                avg_line_buffer[pair_idx]<= $signed(lane_data_i);    
            end else begin
                line_buffer[pair_idx] <= (line_buffer[pair_idx]>lane_data_i)?line_buffer[pair_idx]:lane_data_i;
                avg_line_buffer[pair_idx]<= avg_line_buffer[pair_idx]+$signed(lane_data_i);
            end
        end
        else begin
            if(!odd_col) begin 
                line_buffer[pair_idx] <= (line_buffer[pair_idx]>lane_data_i)?line_buffer[pair_idx]:lane_data_i;
                avg_line_buffer[pair_idx]<= avg_line_buffer[pair_idx]+$signed(lane_data_i);
            end
            else begin
                max_out_reg <= (line_buffer[pair_idx]>lane_data_i)?line_buffer[pair_idx]:lane_data_i;
                avg_out_reg <= (avg_line_buffer[pair_idx]+$signed(lane_data_i))>>>2;
            end
        end
    end
end

// logic signed [ACC_WIDTH-1:0] shft_avg;
// assign shft_avg = avg_line_buffer[pair_idx]>>>2;
assign lane_data_o = (pool_type_i == MAX_POOL)? max_out_reg:avg_out_reg[DATA_WIDTH-1:0];

// assign avg_pool_out = avg_line_buffer
endmodule