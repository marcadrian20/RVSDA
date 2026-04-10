// module Axil_Master #(
//     parameter C_M_AXI_DATA_WIDTH=32,
//     parameter C_M_AXI_ADDR_WIDTH=11,
//     // parameter BRAM_WIDTH=9,
//     localparam ADDRLSB = $clog2(C_M_AXI_DATA_WIDTH/8),
//     localparam VALID_ADDR_WIDTH = C_M_AXI_ADDR_WIDTH - ADDRLSB
// )
// (
//     // output logic [C_M_AXI_DATA_WIDTH-1:0]   imem_wr_data_o,
//     // output logic [VALID_ADDR_WIDTH-1:0]   imem_wr_addr_o,
//     // output logic [C_M_AXI_DATA_WIDTH/8-1:0] imem_wr_strb_o,
//     // output logic                            imem_wr_en_o,
//     // output logic [31:0]                     ctrl_reg_o,
//     // input logic [31:0]                      status_reg_i,


//     input logic                             M_AXI_ACLK,
//     input logic                             M_AXI_ARESETN,
    
//     input logic                             M_AXI_AWVALID,
//     output logic                            M_AXI_AWREADY,
//     input logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
    
//     input logic                             M_AXI_WVALID,
//     output logic                            M_AXI_WREADY,
//     input logic [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
//     input logic [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
    
//     output logic                            M_AXI_BVALID,
//     input logic                             M_AXI_BREADY,
//     output logic [1:0]                      M_AXI_BRESP,
    
//     input logic                             M_AXI_ARVALID,
//     output logic                            M_AXI_ARREADY,
//     input logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_ARADDR,
    
//     output logic                            M_AXI_RVALID,
//     input logic                             M_AXI_RREADY,
//     output logic [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_RDATA,
//     output logic [1:0]                      M_AXI_RRESP,
    

//     ////unused
//     input logic [2:0]                       M_AXI_AWPROT,
//     input logic [2:0]                       M_AXI_ARPROT

// );

// endmodule