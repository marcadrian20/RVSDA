`timescale 1ns/1ps
module Memory_Block #(
    parameter DATA_WIDTH = 8,
    parameter COL_WIDTH = 8,
    parameter NUM_COL = DATA_WIDTH/COL_WIDTH,
    parameter ADDR_WIDTH = 9

)(
    input logic clk_i,ena_i,enb_i,
    input logic [NUM_COL-1:0]wea_i,
    input logic [ADDR_WIDTH-1:0] addra_i,addrb_i,
    input logic [DATA_WIDTH-1:0]data_a_i,
    output logic [DATA_WIDTH-1:0]data_b_o
);

logic [DATA_WIDTH-1:0]ram[2**ADDR_WIDTH-1:0];
// logic [DATA_WIDTH-1:0]doa;
initial begin
    for(int i = 0; i < 2**ADDR_WIDTH; i++)
        ram[i] = '0;
    data_b_o='0;
end
integer i;
always @(posedge clk_i) begin
    if (ena_i) begin
        for(i=0;i<NUM_COL;i=i+1)
            if (wea_i[i])
                ram[addra_i][i*COL_WIDTH +: COL_WIDTH] <= data_a_i[i*COL_WIDTH +: COL_WIDTH];
    end
end

always @(posedge clk_i) begin
    if (enb_i)
        data_b_o <= ram[addrb_i];
end

endmodule