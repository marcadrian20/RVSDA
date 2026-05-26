`timescale 1ns/1ps

module FIFO#(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 4,
    parameter ALMOST_FULL_THRESHOLD = FIFO_DEPTH-1,
    parameter FWFT = 0,
    parameter ALMOST_EMPTY_THRESHOLD = 1
)
(
    input logic clk_i,
    input logic rst_n_i,
    input logic [DATA_WIDTH-1:0] wdata_i,
    input logic we_i,
    input logic re_i,
    output logic full_o,
    // output logic almost_full_o,
    output logic empty_o,
    // output logic almost_empty_o,
    output logic [DATA_WIDTH-1:0] rdata_o    
);

localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
logic [ADDR_WIDTH : 0] read_ptr, write_ptr;//,usage_counter;
logic [DATA_WIDTH-1 : 0]ram[0 : FIFO_DEPTH-1];
logic full, empty;//,almost_empty,almost_full;
always_comb begin
    full = (read_ptr[ADDR_WIDTH] != write_ptr[ADDR_WIDTH]) && (read_ptr[ADDR_WIDTH-1 : 0] == write_ptr[ADDR_WIDTH-1 : 0]);
    empty = (read_ptr == write_ptr);
    // usage_counter = write_ptr-read_ptr;
    // almost_empty = (usage_counter<=ALMOST_EMPTY_THRESHOLD);
    // almost_full = (usage_counter>=ALMOST_FULL_THRESHOLD);
end
always_ff @( posedge clk_i ) begin
    if(!rst_n_i) begin
        {full_o,empty_o}<=2'b01;
    end else begin
        full_o<=full;
        empty_o<=empty;
    end
end
always_ff @(posedge clk_i) begin
    if(!rst_n_i) begin
        write_ptr<= '0;
    end else begin
        if(we_i && !full) begin
            ram[write_ptr[ADDR_WIDTH-1:0]]<= wdata_i;
            write_ptr <= write_ptr + 1'b1;
        end
    end
end
generate
    if(FWFT) begin : gen_fwft
        assign rdata_o =empty? '0: ram[read_ptr[ADDR_WIDTH-1:0]];
        always_ff @(posedge clk_i) begin
            if(!rst_n_i) begin
                read_ptr<= '0;
            end else begin
                if(re_i && !empty) begin
                    read_ptr <= read_ptr + 1'b1;
                end
            end
        end
    end else begin        
        always_ff @(posedge clk_i) begin
            if(!rst_n_i) begin
                read_ptr<= '0;
                rdata_o <= '0;
            end else begin
                if(re_i && !empty) begin
                    rdata_o <= ram[read_ptr[ADDR_WIDTH-1:0]];
                    read_ptr <= read_ptr + 1'b1;
                end
            end
        end
    end
endgenerate
endmodule