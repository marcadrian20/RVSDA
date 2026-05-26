`timescale 1ns/1ps

module Axil_Slave #(
    parameter C_S_AXI_DATA_WIDTH=32,
    parameter C_S_AXI_ADDR_WIDTH=11,
    // parameter BRAM_WIDTH=9,
    localparam ADDRLSB = $clog2(C_S_AXI_DATA_WIDTH/8),
    localparam VALID_ADDR_WIDTH = C_S_AXI_ADDR_WIDTH - ADDRLSB
)
(
    output logic [C_S_AXI_DATA_WIDTH-1:0]   imem_wr_data_o,
    output logic [VALID_ADDR_WIDTH-1:0]   imem_wr_addr_o,
    output logic [C_S_AXI_DATA_WIDTH/8-1:0] imem_wr_strb_o,
    output logic                            imem_wr_en_o,
    output logic [31:0]                     ctrl_reg_o,
    input logic [31:0]                      status_reg_i,


    input logic                             S_AXI_ACLK,
    input logic                             S_AXI_ARESETN,
    
    input logic                             S_AXI_AWVALID,
    output logic                            S_AXI_AWREADY,
    input logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    
    input logic                             S_AXI_WVALID,
    output logic                            S_AXI_WREADY,
    input logic [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
    input logic [C_S_AXI_DATA_WIDTH/8-1:0]  S_AXI_WSTRB,
    
    output logic                            S_AXI_BVALID,
    input logic                             S_AXI_BREADY,
    output logic [1:0]                      S_AXI_BRESP,
    
    input logic                             S_AXI_ARVALID,
    output logic                            S_AXI_ARREADY,
    input logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    
    output logic                            S_AXI_RVALID,
    input logic                             S_AXI_RREADY,
    output logic [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
    output logic [1:0]                      S_AXI_RRESP,
    

    ////unused
    input logic [2:0]                       S_AXI_AWPROT,
    input logic [2:0]                       S_AXI_ARPROT

);
///REGISTER ADDRESSES
localparam CTRL_REG_ADDR = 'h0;
localparam STATUS_REG_ADDR = 'h1;
// localparam IMEM_BASE_ADDR = 'h8;
//presume Byte width is always 8
// localparam ADDRLSB = $clog2(C_S_AXI_DATA_WIDTH/8);
// localparam VALID_ADDR_WIDTH = C_S_AXI_ADDR_WIDTH-ADDRLSB

logic [31:0] ctrl_reg;
logic [31:0] status_reg;
assign ctrl_reg_o=ctrl_reg;
// assign status_reg=status_reg_i;

logic axil_write_ready;
logic axi_bvalid;
logic [VALID_ADDR_WIDTH-1:0] awaddr_skdbuff;
logic [C_S_AXI_DATA_WIDTH-1:0] wdata_skdbuff;
logic [C_S_AXI_DATA_WIDTH/8-1:0] wstrb_skdbuff; 

logic aw_skdbuff_valid;
logic w_skdbuff_valid;

///WRITE TRANSACTION CONTROL AND DATA PATH///
Skid_Buffer#(
    .DATA_WIDTH(C_S_AXI_DATA_WIDTH+C_S_AXI_DATA_WIDTH/8)
)AXIL_W_Skid_Buffer(
    .clk_i(S_AXI_ACLK),
    .rst_n_i(S_AXI_ARESETN),
    .input_valid_i(S_AXI_WVALID),
    .input_ready_o(S_AXI_WREADY),
    .data_i({S_AXI_WDATA, S_AXI_WSTRB}),
    .output_valid_o(w_skdbuff_valid),
    .output_ready_i(axil_write_ready),
    .data_o({wdata_skdbuff, wstrb_skdbuff})
);

Skid_Buffer#(
    .DATA_WIDTH(VALID_ADDR_WIDTH)
)AXIL_AW_Skid_Buffer(
    .clk_i(S_AXI_ACLK),
    .rst_n_i(S_AXI_ARESETN),
    .input_valid_i(S_AXI_AWVALID),
    .input_ready_o(S_AXI_AWREADY),
    .data_i(S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH-1:ADDRLSB]),
    .output_valid_o(aw_skdbuff_valid),
    .output_ready_i(axil_write_ready),
    .data_o(awaddr_skdbuff)
);

assign axil_write_ready = aw_skdbuff_valid && w_skdbuff_valid && (!S_AXI_BVALID || S_AXI_BREADY);

always_ff @( posedge S_AXI_ACLK ) begin : WR_RESP
    if(!S_AXI_ARESETN)
        axi_bvalid<=0;
    else if(axil_write_ready)
        axi_bvalid<=1'b1;
    else if(S_AXI_BREADY)
        axi_bvalid<=0;
end
always_comb begin : WR_RESP_COMB_SIG
    S_AXI_BRESP='0;
    S_AXI_BVALID=axi_bvalid;
end

logic [C_S_AXI_DATA_WIDTH-1:0]w_skdbuff_ctrl_reg;
// logic w_skdbuff_status_reg;
always_comb begin
    w_skdbuff_ctrl_reg=apply_wstrb(ctrl_reg, wdata_skdbuff, wstrb_skdbuff);
    // w_skdbuff_status_reg=apply_wstrb(status_reg, wdata_skdbuff, wstrb_skdbuff);
end

always_ff @( posedge S_AXI_ACLK ) begin : WRITE_DATA
    if(!S_AXI_ARESETN)
        ctrl_reg<='0;
    else if(axil_write_ready) begin
        case (awaddr_skdbuff)
           CTRL_REG_ADDR : ctrl_reg<= w_skdbuff_ctrl_reg;
        endcase
    end
end

logic imem_region;
assign imem_wr_addr_o=awaddr_skdbuff-2;
assign imem_wr_data_o = wdata_skdbuff;
assign imem_wr_strb_o = wstrb_skdbuff;
assign imem_region = (awaddr_skdbuff>=2);
assign imem_wr_en_o = axil_write_ready && imem_region;

///READ TRANSACTION///
logic axil_read_ready;
logic axil_read_valid;
logic [VALID_ADDR_WIDTH-1:0] araddr_skdbuff;
logic [C_S_AXI_DATA_WIDTH-1:0] axil_read_data; 

logic ar_skdbuff_valid;

Skid_Buffer#(
    .DATA_WIDTH(VALID_ADDR_WIDTH)
)AXIL_AR_Skid_Buffer(
    .clk_i(S_AXI_ACLK),
    .rst_n_i(S_AXI_ARESETN),
    .input_valid_i(S_AXI_ARVALID),
    .input_ready_o(S_AXI_ARREADY),
    .data_i(S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDRLSB]),
    .output_valid_o(ar_skdbuff_valid),
    .output_ready_i(axil_read_ready),
    .data_o(araddr_skdbuff)
);
assign axil_read_ready = ar_skdbuff_valid && (!axil_read_valid||S_AXI_RREADY);

always_ff @( posedge S_AXI_ACLK ) begin
    if(!S_AXI_ARESETN)
        axil_read_valid<=0;
    else if(axil_read_ready)
        axil_read_valid<=1'b1;
    else if(S_AXI_RREADY)
        axil_read_valid<=0;
end

always_comb begin : R_RESPONSE
    S_AXI_RVALID=axil_read_valid;
    S_AXI_RDATA=axil_read_data;
    S_AXI_RRESP='0;
end

always_ff @( posedge S_AXI_ACLK ) begin : READ_DATA
    if(!S_AXI_ARESETN)
        axil_read_data<='0;
    else if(!S_AXI_RVALID || S_AXI_RREADY) begin
        case (araddr_skdbuff)
           STATUS_REG_ADDR : axil_read_data<= status_reg_i;
           default : axil_read_data<= 0;
        endcase
    end
end
//WRITE STROBE FUNC//
function [C_S_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_S_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_S_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_S_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_S_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction

endmodule