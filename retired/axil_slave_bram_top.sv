module Axil_Slave_Bram_top#(
    parameter C_S00_AXI_DATA_WIDTH=32,
    parameter C_S00_AXI_ADDR_WIDTH=11
)
(
        input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready

);
localparam ADDRLSB = $clog2(C_S00_AXI_DATA_WIDTH/8);
localparam VALID_ADDR_WIDTH = C_S00_AXI_ADDR_WIDTH - ADDRLSB;
logic [C_S00_AXI_DATA_WIDTH-1:0]imem_wr_data_o;
logic [VALID_ADDR_WIDTH-1:0]imem_wr_addr_o;
logic [C_S00_AXI_DATA_WIDTH/8-1:0]imem_wr_strb_o;
logic imem_wr_en_o;
logic [C_S00_AXI_DATA_WIDTH-1:0]status_reg_i='hDEADBEEF;
logic [C_S00_AXI_DATA_WIDTH-1:0]ctrl_reg;

    Axil_Slave#(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) AXI_LITE_INTERFACE(
        .imem_wr_data_o(imem_wr_data_o),
        .imem_wr_addr_o(imem_wr_addr_o),
        .imem_wr_strb_o(imem_wr_strb_o),
        .imem_wr_en_o(imem_wr_en_o),
        .ctrl_reg_o(ctrl_reg),
        .status_reg_i(status_reg_i),
        .S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_ARPROT(s00_axi_arprot)
    );

logic [C_S00_AXI_DATA_WIDTH-1:0]out_unused;
Memory_Block #(
    .DATA_WIDTH(32),
    .COL_WIDTH(8),      
    .NUM_COL(4),       
    .ADDR_WIDTH(VALID_ADDR_WIDTH)
) IMEM_Memory(
        .clk_i(s00_axi_aclk), 
        .ena_i(imem_wr_en_o),
        .enb_i(1'b0),
        .wea_i(imem_wr_strb_o),
        .addra_i(imem_wr_addr_o),
        .addrb_i('0),
        .data_a_i(imem_wr_data_o),
        .data_b_o(out_unused)
);

endmodule