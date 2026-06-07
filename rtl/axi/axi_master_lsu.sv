module Axi_Master_LSU #(
    parameter BRAM_ADDR_WIDTH = 9,
    parameter C_M_AXI_DATA_WIDTH=64,
    parameter C_M_AXI_ADDR_WIDTH=32,
    parameter C_M_AXI_ID_WIDTH=1,
    parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_READ_ID = 0,
	parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_WRITE_ID = 0,
    // parameter BRAM_WIDTH=9,
    localparam ADDRLSB = $clog2(C_M_AXI_DATA_WIDTH/8),
    localparam VALID_ADDR_WIDTH = C_M_AXI_ADDR_WIDTH - ADDRLSB
)
(
    output logic [C_M_AXI_DATA_WIDTH-1:0]   buffers_wr_data_o,
    output logic [BRAM_ADDR_WIDTH:0]   buffers_wr_addr_o,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0] buffers_wr_strb_o,

    input logic [C_M_AXI_DATA_WIDTH-1:0]   buffers_rd_data_i,
    output logic [BRAM_ADDR_WIDTH-1:0]   buffers_rd_addr_o,
    output logic buffers_rd_en_o,
    

    input logic [63:0] lsu_load_descriptor_fifo_wdata_i,
    input logic lsu_load_descriptor_fifo_we_i,
    input logic [63:0] lsu_store_descriptor_fifo_wdata_i,
    input logic lsu_store_descriptor_fifo_we_i,
    output logic [9:0] lsu_status_o,
    input logic lsu_store_en_i,
    input logic lsu_load_en_i,

    input logic act_buffer_full_i,
    input logic weight_buffer_full_i,
    input logic output_buffer_ready_i,

    output logic load_unit_push_token_o,
    output logic store_unit_push_token_o,
    // output logic                            imem_wr_en_o,
    // output logic [31:0]                     ctrl_reg_o,
    // input logic [31:0]                      status_reg_i,

    input logic                             M_AXI_ACLK,
    input logic                             M_AXI_ARESETN,
    
    output logic                             M_AXI_AWVALID,
    input logic                            M_AXI_AWREADY,
    output logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_AWID,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
    output logic [7:0]			            M_AXI_AWLEN,
    output logic [2:0]			            M_AXI_AWSIZE,
    output logic [1:0]			            M_AXI_AWBURST,
    output logic    			            M_AXI_AWLOCK,
    output logic [3:0]			            M_AXI_AWCACHE,
    output logic [2:0]			            M_AXI_AWPROT,
    output logic [3:0]			            M_AXI_AWQOS,
    
    output logic                             M_AXI_WVALID,
    input logic                            M_AXI_WREADY,
    output logic [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
    output logic                             M_AXI_WLAST,
    
    input logic                            M_AXI_BVALID,
    output logic                             M_AXI_BREADY,
    input logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_BID,
    input logic [1:0]                      M_AXI_BRESP,
    
    output logic                             M_AXI_ARVALID,
    input logic                            M_AXI_ARREADY,
    output logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_ARID,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_ARADDR,
    output logic [7:0]			            M_AXI_ARLEN,
    output logic [2:0]			            M_AXI_ARSIZE,
    output logic [1:0]			            M_AXI_ARBURST,
    output logic    			            M_AXI_ARLOCK,
    output logic [3:0]			            M_AXI_ARCACHE,
    output logic [2:0]			            M_AXI_ARPROT,
    output logic [3:0]			            M_AXI_ARQOS,
    
    input logic                            M_AXI_RVALID,
    output logic                             M_AXI_RREADY,
    input logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_RID,
    input logic [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_RDATA,
    input logic                             M_AXI_RLAST,
    input logic [1:0]                      M_AXI_RRESP

);

//Read side signaling
logic [63:0] lsu_load_descriptor_fifo_rdata;
logic [63:0] lsu_store_descriptor_fifo_rdata;
logic lsu_load_descriptor_fifo_re, lsu_load_descriptor_fifo_empty;
FIFO  #(.DATA_WIDTH(64),
        .FIFO_DEPTH(4),
        .FWFT(1)
    )lsu_load_descriptor_fifo(
            .clk_i(M_AXI_ACLK),
            .rst_n_i(M_AXI_ARESETN),
            .wdata_i(lsu_load_descriptor_fifo_wdata_i),
            .we_i(lsu_load_descriptor_fifo_we_i),
            .re_i(lsu_load_descriptor_fifo_re),
            .full_o(lsu_load_descriptor_fifo_full),
            .empty_o(lsu_load_descriptor_fifo_empty),
            .rdata_o(lsu_load_descriptor_fifo_rdata)    
        );
logic load_unit_busy, load_unit_done, load_unit_error;

Axi_Load_Unit #(
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH),
    .AXI_READ_ID(AXI_READ_ID)
) axi_load_unit(
    .buffers_wr_data_o(buffers_wr_data_o),
    .buffers_wr_addr_o(buffers_wr_addr_o),
    .buffers_wr_strb_o(buffers_wr_strb_o),
    .descriptor_i(lsu_load_descriptor_fifo_rdata),
    .descriptor_queue_empty_i(lsu_load_descriptor_fifo_empty),
    .descriptor_queue_pop_o(lsu_load_descriptor_fifo_re),
    .act_buffer_full_i(act_buffer_full_i),
    .weight_buffer_full_i(weight_buffer_full_i),
    .push_token_o(load_unit_push_token_o),
    .en_i(lsu_load_en_i),
    .busy_o(load_unit_busy),
    .done_o(load_unit_done),
    .error_o(load_unit_error),
    .M_AXI_ACLK(M_AXI_ACLK),
    .M_AXI_ARESETN(M_AXI_ARESETN),
    .M_AXI_ARVALID(M_AXI_ARVALID),
    .M_AXI_ARREADY(M_AXI_ARREADY),
    .M_AXI_ARID(M_AXI_ARID),
    .M_AXI_ARADDR(M_AXI_ARADDR),
    .M_AXI_ARLEN(M_AXI_ARLEN),
 	.M_AXI_ARSIZE(M_AXI_ARSIZE),
 	.M_AXI_ARBURST(M_AXI_ARBURST),
    .M_AXI_ARLOCK(M_AXI_ARLOCK),
    .M_AXI_ARCACHE(M_AXI_ARCACHE),
    .M_AXI_ARPROT(M_AXI_ARPROT),
    .M_AXI_ARQOS(M_AXI_ARQOS),
    .M_AXI_RVALID(M_AXI_RVALID),
    .M_AXI_RREADY(M_AXI_RREADY),
    .M_AXI_RID(M_AXI_RID),
    .M_AXI_RDATA(M_AXI_RDATA),
    .M_AXI_RLAST(M_AXI_RLAST),
    .M_AXI_RRESP(M_AXI_RRESP)
);


FIFO  #(.DATA_WIDTH(64),
        .FIFO_DEPTH(4),
        .FWFT(1)
    )lsu_store_descriptor_fifo(
            .clk_i(M_AXI_ACLK),
            .rst_n_i(M_AXI_ARESETN),
            .wdata_i(lsu_store_descriptor_fifo_wdata_i),
            .we_i(lsu_store_descriptor_fifo_we_i),
            .re_i(lsu_store_descriptor_fifo_re),
            .full_o(lsu_store_descriptor_fifo_full),
            .empty_o(lsu_store_descriptor_fifo_empty),
            .rdata_o(lsu_store_descriptor_fifo_rdata)    
    );
logic store_unit_busy, store_unit_done, store_unit_error;
Axi_Store_Unit #(
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH),
    .AXI_WRITE_ID(AXI_WRITE_ID)
)  axi_store_unit(
    .output_buffer_rd_data_i(buffers_rd_data_i),
    .output_buffer_rd_addr_o(buffers_rd_addr_o),
    .output_buffer_rd_en_o(buffers_rd_en_o),
    .descriptor_i(lsu_store_descriptor_fifo_rdata),
    .descriptor_queue_empty_i(lsu_store_descriptor_fifo_empty),
    .descriptor_queue_pop_o(lsu_store_descriptor_fifo_re),
    .output_buffer_ready_i(output_buffer_ready_i),
    .push_token_o(store_unit_push_token_o),
    .en_i(lsu_store_en_i),
    .busy_o(store_unit_busy),
    .done_o(store_unit_done),
    .error_o(store_unit_error),
    .M_AXI_ACLK(M_AXI_ACLK),
    .M_AXI_ARESETN(M_AXI_ARESETN),
    .M_AXI_AWVALID(M_AXI_AWVALID),
    .M_AXI_AWREADY(M_AXI_AWREADY),
    .M_AXI_AWID(M_AXI_AWID),
    .M_AXI_AWADDR(M_AXI_AWADDR),
    .M_AXI_AWLEN(M_AXI_AWLEN),
    .M_AXI_AWSIZE(M_AXI_AWSIZE),
    .M_AXI_AWBURST(M_AXI_AWBURST),
    .M_AXI_AWLOCK(M_AXI_AWLOCK),
    .M_AXI_AWCACHE(M_AXI_AWCACHE),
    .M_AXI_AWPROT(M_AXI_AWPROT),
    .M_AXI_AWQOS(M_AXI_AWQOS),
    .M_AXI_WVALID(M_AXI_WVALID),
    .M_AXI_WREADY(M_AXI_WREADY),
    .M_AXI_WDATA(M_AXI_WDATA),
    .M_AXI_WSTRB(M_AXI_WSTRB),
    .M_AXI_WLAST(M_AXI_WLAST),
    .M_AXI_BVALID(M_AXI_BVALID),
    .M_AXI_BREADY(M_AXI_BREADY),
    .M_AXI_BID(M_AXI_BID),
    .M_AXI_BRESP(M_AXI_BRESP)
);     
////////////////////////
//BIT|| signal          
// 0 ||load_unit_error
// 1 ||load_unit_done
// 2 ||load_unit_busy
// 3 ||lsu_load_descriptor_fifo_full
// 4 ||lsu_load_descriptor_fifo_empty
// 5 ||store_unit_error
// 6 ||store_unit_done
// 7 ||store_unit_busy
// 8 ||lsu_store_descriptor_fifo_full
// 9 ||lsu_store_descriptor_fifo_empty
/////////////
assign lsu_status_o[9:5] =  {lsu_store_descriptor_fifo_empty, lsu_store_descriptor_fifo_full, store_unit_busy, store_unit_done, store_unit_error};
assign lsu_status_o[4:0] =  {lsu_load_descriptor_fifo_empty, lsu_load_descriptor_fifo_full, load_unit_busy, load_unit_done, load_unit_error};

endmodule