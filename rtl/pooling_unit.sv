`timescale 1ns/1ps

module Pooling_Unit #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter BRAM_ADDR_WIDTH = 9
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [3:0] pool_shift_amount_i,
    input logic [1:0] pool_type_i,
    input logic pool_cfg_valid_i,
    input logic [11:0] feature_width_i,
    input logic [11:0] feature_height_i,
    input logic [23:0] valid_pixels_i,
    input logic data_valid_i,
    output logic data_valid_o,
    input logic [BRAM_ADDR_WIDTH-1:0] output_addr_i,
    output logic [BRAM_ADDR_WIDTH-1:0] output_addr_o,
    // input logic output_mem_we_i,
    // output logic output_mem_we_o,
    input logic signed [DATA_WIDTH*ARRAY_SIZE-1:0] data_i,
    output logic signed [DATA_WIDTH*ARRAY_SIZE-1:0] data_o

);
localparam BYPASS = 2'b00;
localparam MAX_POOL = 2'b01;
localparam AVG_POOL = 2'b10;
localparam GLOBAL_AVG_POOL = 2'b11;
logic signed [DATA_WIDTH*ARRAY_SIZE-1:0] lane_outputs;
logic max_or_avg_valid;
logic odd_col, odd_row;
logic [BRAM_ADDR_WIDTH-1:0] pool_addr_reg;
// logic [1:0] pool_type_reg;

(* mark_debug = "true" *)logic [11:0] feature_width_reg;
logic [11:0] feature_height_reg;
(* mark_debug = "true" *)logic [23:0] valid_pixels_reg;

always_ff @(posedge clk_i)
begin
    if(!rst_n_i)
    begin
        feature_width_reg  <= '0;
        feature_height_reg <= '0;
        valid_pixels_reg   <= '0;
    end
    else if(pool_cfg_valid_i)
    begin
        feature_width_reg  <= feature_width_i;
        feature_height_reg <= feature_height_i;
        valid_pixels_reg   <= valid_pixels_i;
    end
end

(* mark_debug = "true" *)logic [11:0] pixel_x;
(* mark_debug = "true" *)logic [11:0] pixel_y;
(* mark_debug = "true" *)logic [23:0] pixel_count;

always_ff @(posedge clk_i)
begin
    if(!rst_n_i)
    begin
        pixel_x     <= '0;
        pixel_y     <= '0;
        pixel_count <= '0;
    end
    else if(data_valid_i)
    begin
        if(pixel_count < valid_pixels_reg)
        begin
            pixel_count <= pixel_count + 1;

            if(pixel_x == feature_width_reg - 1)
            begin
                pixel_x <= 0;
                pixel_y <= pixel_y + 1;
            end
            else
            begin
                pixel_x <= pixel_x + 1;
            end
        end
    end
    if(pool_cfg_valid_i) begin
        pixel_x     <= '0;
        pixel_y     <= '0;
        pixel_count <= '0;
    end
end
logic pixel_valid_for_pool;
assign pixel_valid_for_pool =
        data_valid_i &&
        (pixel_count < valid_pixels_reg);


logic pool_addr_latched;
assign odd_col = pixel_x[0];
assign odd_row = pixel_y[0];// assign max_or_avg_valid = pool_cnt[4];
logic [11:0] pool_col_idx;
assign pool_col_idx = pixel_x >> 1;

always_ff @( posedge clk_i ) begin 
    if (!rst_n_i) begin
        pool_addr_reg <= '0;   
        max_or_avg_valid<='0;
        pool_addr_latched  <= 1'b0;
    end 
    else begin 
        if (pool_cfg_valid_i) begin
            pool_addr_latched <= 1'b0;
        end
        if(max_or_avg_valid)
                pool_addr_reg <= pool_addr_reg +1'b1;  
        if(data_valid_i) begin
            // pool_type_reg <= pool_type_i;
            
            max_or_avg_valid<= odd_row && odd_col;
                
            if (!pool_addr_latched) begin
                    pool_addr_reg     <= output_addr_i;
                    pool_addr_latched <= 1'b1;
            end
        end
        else begin
            max_or_avg_valid<= '0;  
        end
    end
end
///Basically we use NHWC
//we have 8 channels
//in 64 bits i encode [ch0][ch1][ch2][ch3][ch4][ch5][ch6][ch7]


logic signed [DATA_WIDTH*ARRAY_SIZE-1:0] bypass_data_reg;
logic bypass_valid_reg;
logic [1:0] pool_type_delayed;
logic [BRAM_ADDR_WIDTH-1:0] bypass_addr_reg;
always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
        bypass_data_reg   <= '0;
        bypass_valid_reg  <= 1'b0;
        pool_type_delayed <= BYPASS;
        bypass_addr_reg   <= '0;
    end else begin
        bypass_data_reg   <= data_i;
        bypass_valid_reg  <= data_valid_i;
        pool_type_delayed <= pool_type_i; // Track the trailing state change
        bypass_addr_reg   <= output_addr_i;
    end
end

genvar ch;
generate
    for(ch = 0; ch < ARRAY_SIZE; ch++) begin: gen_pooling_lanes
        Pooling_Lane #(
            .ARRAY_SIZE(ARRAY_SIZE),
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) pool_lane (
            .clk_i(clk_i), 
            .rst_n_i(rst_n_i),
            .pool_type_i(pool_type_delayed),
            .data_valid_i(data_valid_i), 
            .pixel_x_i(pixel_x),
            .pixel_y_i(pixel_y),
            .pool_col_idx_i(pool_col_idx),
            .lane_data_i(data_i[ch*DATA_WIDTH+:DATA_WIDTH]), 
            .lane_data_o(lane_outputs[ch*DATA_WIDTH+:DATA_WIDTH]) 
        );
    end
endgenerate
assign output_addr_o = (pool_type_delayed==BYPASS)? bypass_addr_reg: pool_addr_reg;
always_comb begin : PoolingOutputMux
    case(pool_type_delayed)
        BYPASS: begin //00 is passthrough/bypass
            data_o = bypass_data_reg;
            data_valid_o = bypass_valid_reg;
        end
        MAX_POOL/*, AVG_POOL*/: begin //01 is max pooling
            data_o = lane_outputs;
            data_valid_o = max_or_avg_valid;
        end
        // GLOBAL_AVG_POOL: begin//11 is global average pooling
        //     data_o = '0;
        //     data_valid_o = 1'b0;
        // end
        default: begin
            data_o = bypass_data_reg;
            data_valid_o = bypass_valid_reg;
        end
    endcase
end
endmodule