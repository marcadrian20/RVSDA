`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/25/2026 02:44:30 PM
// Design Name: 
// Module Name: NPU_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module NPU_wrapper #(
    parameter BRAM_ADDR_WIDTH = 9,
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter C_S_AXI_DATA_WIDTH= 32,
    parameter C_S_AXI_ADDR_WIDTH=11,
    parameter C_M_AXI_DATA_WIDTH=64,
    parameter C_M_AXI_ADDR_WIDTH=32,
    parameter C_M_AXI_ID_WIDTH=1,
    parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_READ_ID = 0,
	parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_WRITE_ID = 0
)
(   
    input wire                             S_AXI_ACLK,
    input wire                             S_AXI_ARESETN,
    
    input wire                             S_AXI_AWVALID,
    output wire                            S_AXI_AWREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    
    input wire                             S_AXI_WVALID,
    output wire                            S_AXI_WREADY,
    input wire [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
    input wire [C_S_AXI_DATA_WIDTH/8-1:0]  S_AXI_WSTRB,
    
    output wire                            S_AXI_BVALID,
    input wire                             S_AXI_BREADY,
    output wire [1:0]                      S_AXI_BRESP,
    
    input wire                             S_AXI_ARVALID,
    output wire                            S_AXI_ARREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    
    output wire                            S_AXI_RVALID,
    input wire                             S_AXI_RREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
    output wire [1:0]                      S_AXI_RRESP,
    

    input wire [2:0]                       S_AXI_AWPROT,
    input wire [2:0]                       S_AXI_ARPROT,

    input wire                             M_AXI_ACLK,
    input wire                             M_AXI_ARESETN,
    
    output wire                             M_AXI_AWVALID,
    input wire                            M_AXI_AWREADY,
    output wire [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_AWID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
    output wire [7:0]			            M_AXI_AWLEN,
    output wire [2:0]			            M_AXI_AWSIZE,
    output wire [1:0]			            M_AXI_AWBURST,
    output wire    			            M_AXI_AWLOCK,
    output wire [3:0]			            M_AXI_AWCACHE,
    output wire [2:0]			            M_AXI_AWPROT,
    output wire [3:0]			            M_AXI_AWQOS,
    
    output wire                             M_AXI_WVALID,
    input wire                            M_AXI_WREADY,
    output wire [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
    output wire                             M_AXI_WLAST,
    
    input wire                            M_AXI_BVALID,
    output wire                             M_AXI_BREADY,
    input wire [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_BID,
    input wire [1:0]                      M_AXI_BRESP,
    
    output wire                             M_AXI_ARVALID,
    input wire                            M_AXI_ARREADY,
    output wire [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_ARID,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_ARADDR,
    output wire [7:0]			            M_AXI_ARLEN,
    output wire [2:0]			            M_AXI_ARSIZE,
    output wire [1:0]			            M_AXI_ARBURST,
    output wire    			            M_AXI_ARLOCK,
    output wire [3:0]			            M_AXI_ARCACHE,
    output wire [2:0]			            M_AXI_ARPROT,
    output wire [3:0]			            M_AXI_ARQOS,
    
    input wire                            M_AXI_RVALID,
    output wire                             M_AXI_RREADY,
    input wire [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_RID,
    input wire [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_RDATA,
    input wire                             M_AXI_RLAST,
    input wire [1:0]                      M_AXI_RRESP
);

NPU#( 
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH),
    .AXI_READ_ID(AXI_READ_ID),
    .AXI_WRITE_ID(AXI_WRITE_ID),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    )
npu(
    .S_AXI_ACLK(S_AXI_ACLK),
    .S_AXI_ARESETN(S_AXI_ARESETN),
    .S_AXI_AWVALID(S_AXI_AWVALID),
    .S_AXI_AWREADY(S_AXI_AWREADY),
    .S_AXI_AWADDR(S_AXI_AWADDR),
    .S_AXI_WVALID(S_AXI_WVALID),
    .S_AXI_WREADY(S_AXI_WREADY),
    .S_AXI_WDATA(S_AXI_WDATA),
    .S_AXI_WSTRB(S_AXI_WSTRB),
    .S_AXI_BVALID(S_AXI_BVALID),
    .S_AXI_BREADY(S_AXI_BREADY),
    .S_AXI_BRESP(S_AXI_BRESP),
    .S_AXI_ARVALID(S_AXI_ARVALID),
    .S_AXI_ARREADY(S_AXI_ARREADY),
    .S_AXI_ARADDR(S_AXI_ARADDR),
    .S_AXI_RVALID(S_AXI_RVALID),
    .S_AXI_RREADY(S_AXI_RREADY),
    .S_AXI_RDATA(S_AXI_RDATA),
    .S_AXI_RRESP(S_AXI_RRESP),
    .S_AXI_AWPROT(S_AXI_AWPROT),
    .S_AXI_ARPROT(S_AXI_ARPROT),
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
    .M_AXI_BRESP(M_AXI_BRESP),
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
endmodule
