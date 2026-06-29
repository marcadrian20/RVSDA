`timescale 1ns/1ps
module Accumulation_Buffer #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic [$clog2(ARRAY_SIZE)-1:0] addra_i,
    input logic [$clog2(ARRAY_SIZE)-1:0] addrb_i,
    input logic we_i,
    input logic re_i,
    input logic accumulate_en_i,
    input logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] data_i,
    output logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] data_o
);

logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] mem_out;
logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] mux_out;
logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] accumulate_out;

logic accumulate_en_reg;

always_ff @( posedge clk_i ) begin
    if(!rst_n_i)
        accumulate_en_reg <='0;
    else
        accumulate_en_reg <= accumulate_en_i;
end

always_comb begin : Parallel_Adder_Lanes
    for(int i = 0; i<ARRAY_SIZE;i++) begin
        mux_out[i*DATA_WIDTH +: DATA_WIDTH] = accumulate_en_i? mem_out[i*DATA_WIDTH +: DATA_WIDTH] : '0;
        accumulate_out[i*DATA_WIDTH +: DATA_WIDTH] = data_i[i*DATA_WIDTH +: DATA_WIDTH] + mux_out[i*DATA_WIDTH +: DATA_WIDTH];
    end
end

logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] out_data;
logic [(ARRAY_SIZE*DATA_WIDTH)-1:0] intermediary_data;
initial begin
    out_data = '0;
    intermediary_data = '0;
end

Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE),
        .ADDR_WIDTH($clog2(ARRAY_SIZE))
) accumulation_mem(
        .clk_i(clk_i), 
        .ena_i(we_i),
        .enb_i(re_i),
        .wea_i({DATA_WIDTH*ARRAY_SIZE/8{we_i}}),
        .addra_i(addra_i),
        .addrb_i(addrb_i),
        .data_a_i(intermediary_data),
        .data_b_o(mem_out)
);


always_ff @( posedge clk_i ) begin : blockName
    // if(!rst_n_i)
    //     data_o <='0;
    // else
    intermediary_data <= accumulate_out;
    // out_data <= intermediary_data;

end
assign data_o = intermediary_data;
endmodule