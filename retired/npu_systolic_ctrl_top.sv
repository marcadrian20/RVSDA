`timescale 1ns/1ps

module NPU_SYS_CTRL_TEST #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter C_S_AXI_DATA_WIDTH= 32,
    parameter C_S_AXI_ADDR_WIDTH=4
)
(   
    input logic clk_i,
    input logic rst_n_i,
    input logic                                 dispatch_i,
    // input logic                                 weight_load_en_i,
    input logic act_mem_ena_i,//act_mem_enb_i,
    input logic [DATA_WIDTH*ARRAY_SIZE/8-1:0]act_mem_wea_i,
    input logic weight_mem_ena_i,//weight_mem_enb_i,
    input logic [DATA_WIDTH*ARRAY_SIZE/8-1:0]weight_mem_wea_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_data_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_data_i,
    output logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] data_o,
    input logic [8:0]                           addra_i//,addrb_i

    /*input logic                             S_AXI_ACLK,
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
    input logic [2:0]                       S_AXI_ARPROT */
);

// logic clk_i, rst_n_i;
// always_comb begin
//     clk_i=S_AXI_ACLK;
//     rst_n_i=S_AXI_ARESETN;
// end
logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_stream;
logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_mem_o;
logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] weight_mem_o;
logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] systolic_o;
logic done, busy;
logic act_data_feeder_en, output_data_deskewer_en;
logic weight_mem_enb, weight_load_en, act_mem_enb;
logic [8:0] weight_addrb, act_addrb;

Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE)
) Weight_Memory(
        .clk_i(clk_i), 
        .ena_i(weight_mem_ena_i),
        .enb_i(weight_mem_enb),
        .wea_i(weight_mem_wea_i),
        .addra_i(addra_i),
        .addrb_i(weight_addrb),
        .data_a_i(weight_data_i),
        .data_b_o(weight_mem_o)
);

Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE)
) Activation_Memory(
        .clk_i(clk_i), 
        .ena_i(act_mem_ena_i),
        .enb_i(act_mem_enb),
        .wea_i(act_mem_wea_i),
        .addra_i(addra_i),
        .addrb_i(act_addrb),
        .data_a_i(activation_data_i),
        .data_b_o(activation_mem_o)
);
Window_Shift_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(DATA_WIDTH)
) Activation_Feeder (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(act_data_feeder_en),
        .data_i(activation_mem_o), 
        .data_o(activation_stream)
    );

 Execution_Controller #(
        .ARRAY_SIZE(ARRAY_SIZE)
)  Execution_Controller(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .dispatch_i(dispatch_i),
        .act_data_feeder_en_o(act_data_feeder_en),
        .output_data_deskewer_en_o(output_data_deskewer_en),
        .weight_mem_enb_o(weight_mem_enb),
        .weight_load_en_o(weight_load_en),
        .act_mem_enb_o(act_mem_enb),
        .weight_addrb_o(weight_addrb),
        .act_addrb_o(act_addrb),
        .busy_o(busy),
        .done_o(done)
);

Systolic_Array #(
                .ARRAY_SIZE(ARRAY_SIZE),
                .DATA_WIDTH(DATA_WIDTH))
    systolic_array(
                .clk_i(clk_i),
                .rst_n_i(rst_n_i),
                .dispatch_i(1'b0/*dispatch_reg*/),
                .weight_load_en_i(weight_load_en),
                // .done_o(done_o),
                .activation_i(activation_stream),
                .weight_i(weight_mem_o),
                .result_o(systolic_o)
    );

Window_Unskew_Buffer #(
        .ARRAY_SIZE(ARRAY_SIZE), 
        .DATA_WIDTH(ACC_WIDTH)
) Output_Deskewer (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i), 
        .en_i(output_data_deskewer_en),
        .data_i(systolic_o), 
        .data_o(data_o)
    );


endmodule