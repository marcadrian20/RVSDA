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
logic [3:0] pool_cnt;
logic [BRAM_ADDR_WIDTH-1:0] pool_addr_reg;
logic [1:0] pool_type_reg;
// logic pooling_active;
// always_ff @( posedge clk_i ) begin
//     if (!rst_n_i) begin
//         max_pool_line_buffer <= '0;
//         pool_cnt <= '0;
//         pool_addr_reg <= '0;
//         for(int i=0; i < ARRAY_SIZE; i++)
//             avg_line_buffer[i] <= '0;
//     end else if(data_valid_i) begin
//         if(pool_type_i==MAX_POOL||pool_type_i == AVG_POOL) begin
//             pool_cnt <= pool_cnt + 1'b1;
//         end
//         max_or_avg_valid<=pool_cnt[1]&&pool_cnt[0];
//         if(!row_phase && !col_phase) begin
//             max_pool_line_buffer <= data_i;
//             pool_addr_reg <= output_addr_i;
//             for(int ch = 0; ch < ARRAY_SIZE; ch++) begin
//                     avg_line_buffer[ch] <= $signed(data_i[ch*DATA_WIDTH+:DATA_WIDTH]);
//             end
//         end
//         else begin    
//             case(pool_type_i)
//                 MAX_POOL: begin //01 is max pooling
//                     for(int ch = 0; ch < ARRAY_SIZE; ch++) begin
//                         max_pool_line_buffer[ch*DATA_WIDTH+:DATA_WIDTH] <= (max_pool_line_buffer[ch*DATA_WIDTH+:DATA_WIDTH] > data_i[ch*DATA_WIDTH+:DATA_WIDTH])?max_pool_line_buffer[ch*DATA_WIDTH+:DATA_WIDTH]:data_i[ch*DATA_WIDTH+:DATA_WIDTH];
//                     end
//                 end
//                 AVG_POOL: begin //10 is avg pooling
//                     for(int ch = 0; ch < ARRAY_SIZE; ch++) begin
//                         avg_line_buffer[ch] <= $signed(data_i[ch*DATA_WIDTH+:DATA_WIDTH]) + avg_line_buffer[ch];
//                     end
//                 end
//                 GLOBAL_AVG_POOL: begin//11 is global average pooling
//                    for(int ch = 0; ch < ARRAY_SIZE; ch++) begin
//                         avg_line_buffer[ch] <= $signed(data_i[ch*DATA_WIDTH+:DATA_WIDTH]) + avg_line_buffer[ch];
//                     end
//                 end
//                 default: ;
//             endcase        
//         end
//     end
// end
logic pool_addr_latched;
assign odd_col = pool_cnt[0];
assign odd_row = pool_cnt[3];// assign max_or_avg_valid = pool_cnt[4];
always_ff @( posedge clk_i ) begin 
    if (!rst_n_i) begin
        pool_cnt<='0;
        pool_addr_reg <= '0;   
        max_or_avg_valid<='0;
        pool_addr_latched  <= 1'b0;
    end 
    else if(data_valid_i) begin
        // pool_type_reg <= pool_type_i;
        if(pool_type_i==MAX_POOL||pool_type_i == AVG_POOL)
            pool_cnt <= pool_cnt + 1'b1;
        else pool_cnt<='0;
        
        max_or_avg_valid<= odd_row && odd_col;
            
        if (!pool_addr_latched) begin
                pool_addr_reg     <= output_addr_i;
                pool_addr_latched <= 1'b1;
        end
        else if(max_or_avg_valid)
            pool_addr_reg <= pool_addr_reg +1'b1; 
    end else begin
        max_or_avg_valid<= '0;
        if (pool_cnt == '0) begin
            pool_addr_latched <= 1'b0;
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
            .pool_cnt_i(pool_cnt),
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
        MAX_POOL, AVG_POOL: begin //01 is max pooling
            data_o = lane_outputs;
            data_valid_o = max_or_avg_valid;
        end
        GLOBAL_AVG_POOL: begin//11 is global average pooling
            data_o = '0;
            data_valid_o = 1'b0;
        end
        default: begin
            data_o = bypass_data_reg;
            data_valid_o = bypass_valid_reg;
        end
    endcase
end
endmodule