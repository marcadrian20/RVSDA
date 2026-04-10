`timescale 1ns/1ps

module NPU #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter C_S_AXI_DATA_WIDTH= 32,
    parameter C_S_AXI_ADDR_WIDTH=11
)
(   
    // input logic clk_i,
    // input logic rst_n_i,
    // input logic                                 dispatch_i,
    // input logic                                 weight_load_en_i,
    input logic act_mem_ena_i,//act_mem_enb_i,
    input logic [DATA_WIDTH*ARRAY_SIZE/8-1:0]act_mem_wea_i,
    input logic weight_mem_ena_i,//weight_mem_enb_i,
    input logic [DATA_WIDTH*ARRAY_SIZE/8-1:0]weight_mem_wea_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_data_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_data_i,
    output logic signed[ACC_WIDTH*ARRAY_SIZE-1:0] data_o,
    input logic [8:0]                           addra_i,//addrb_i

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

logic clk_i, rst_n_i;
always_comb begin
    clk_i=S_AXI_ACLK;
    rst_n_i=S_AXI_ARESETN;
end

localparam ADDRLSB = $clog2(C_S_AXI_DATA_WIDTH/8);
localparam VALID_ADDR_WIDTH = C_S_AXI_ADDR_WIDTH - ADDRLSB;


logic [C_S_AXI_DATA_WIDTH-1:0]   imem_wr_data_o;
logic [VALID_ADDR_WIDTH-1:0]   imem_wr_addr_o;
logic [C_S_AXI_DATA_WIDTH/8-1:0] imem_wr_strb_o;
logic                            imem_wr_en_o;
logic [31:0]                     ctrl_reg_o;
logic [31:0]                      status_reg;


Axil_Slave #(
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
) Axil_Slave_Interface(
    .imem_wr_data_o(imem_wr_data_o),
    .imem_wr_addr_o(imem_wr_addr_o),
    .imem_wr_strb_o(imem_wr_strb_o),
    .imem_wr_en_o(imem_wr_en_o),
    .ctrl_reg_o(ctrl_reg_o),
    .status_reg_i(status_reg),
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
    .S_AXI_ARPROT(S_AXI_ARPROT)
);
logic mem_valid;
logic imem_sel;
logic mem_ready;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [3:0] mem_wstrb;
logic  [31:0] mem_rdata;
logic  [31:0] imem_data_o;
logic  [31:0] mmio_datapath;
//unused
logic trap;
logic mem_instr;

/////////////////////////////
//MEMORY MAPPED REGISTER
logic dispatch_reg;
logic [VALID_ADDR_WIDTH-1:0] weight_mem_offset_reg;
logic [VALID_ADDR_WIDTH-1:0] act_mem_offset_reg;
logic [VALID_ADDR_WIDTH-1:0] output_mem_offset_reg;
localparam DISPATCH_REG_ADDR = 'h800;
localparam STATUS_REG_ADDR = 'h804;
localparam WEIGHT_MEM_OFFSET = 'h808;
localparam ACT_MEM_OFFSET = 'h80C;
// localparam WEIGHT_DDR_BASE_REG_ADDR = 'h204;
// localparam ACT_DDR_BASE_REG_ADDR = 'h208;
// localparam OUTPUT_DDR_BASE_REG_ADDR = 'h212;
logic mmio_write;
logic mmio_read;

assign mmio_read = mem_valid && ~|mem_wstrb && mem_addr[C_S_AXI_ADDR_WIDTH];
assign mmio_write = mem_valid && |mem_wstrb && mem_addr[C_S_AXI_ADDR_WIDTH];


always_ff @( posedge clk_i ) begin 
    if(!rst_n_i) begin
        dispatch_reg <= '0;
        act_mem_offset_reg <='0;
        weight_mem_offset_reg <='0;
        // status_reg <='0;
    end else begin
        dispatch_reg<= '0;
        if(mmio_write) begin
            case (mem_addr)
                DISPATCH_REG_ADDR:  dispatch_reg<=mem_wdata;
                // STATUS_REG_ADDR:  status_reg<=mem_wdata;
                WEIGHT_MEM_OFFSET: weight_mem_offset_reg <= mem_wdata;
                ACT_MEM_OFFSET: act_mem_offset_reg <= mem_wdata;
                    // output_mem_offset_reg;
                // WEIGHT_DDR_BASE_REG_ADDR: 
                // ACT_DDR_BASE_REG_ADDR:
                // OUTPUT_DDR_BASE_REG_ADDR:
            endcase
        end
    end
end
always_ff @( posedge clk_i ) begin
    if(!rst_n_i) begin
        mem_ready<= 1'b0;
    end else begin
        mem_ready<=mem_valid && !mem_ready;
    end
end
always_comb begin  
    mmio_datapath = '0;
        if(mmio_read) begin
            case (mem_addr)
                STATUS_REG_ADDR: mmio_datapath = status_reg;
                default: mmio_datapath = '0;
            endcase
        end
end

assign imem_sel = mem_valid && (mem_addr[C_S_AXI_ADDR_WIDTH]==0); 
assign mem_rdata = imem_sel? imem_data_o : mmio_datapath;
// assign mem_ready =
logic [C_S_AXI_DATA_WIDTH-1:0] imem_bank_a_unused_o;

Memory_Block_TDP #(
        .DATA_WIDTH(32)
) Instruction_Memory(
        .clk_i(clk_i), 
        .ena_i(imem_wr_en_o),
        .enb_i(imem_sel),
        .wea_i(imem_wr_strb_o),
        .web_i(mem_wstrb),
        .addra_i(imem_wr_addr_o),
        .addrb_i({mem_addr[C_S_AXI_ADDR_WIDTH-1:2]}),
        .data_a_i(imem_wr_data_o),
        .data_a_o(imem_bank_a_unused_o),
        .data_b_i(mem_wdata),
        .data_b_o(imem_data_o)
);

picorv32 #() Pico_Core(
    .clk(clk_i),
    .resetn(rst_n_i/*|~ctrl_reg_o[0]*/),
    .trap(trap),
    .mem_valid(mem_valid),
    .mem_instr(mem_instr),
    .mem_ready(mem_ready),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata)
);

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

Systolic_Controller #(
        .ARRAY_SIZE(ARRAY_SIZE)
) systolic_controller(
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .dispatch_i(dispatch_reg),
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
assign status_reg = {30'b0,{busy, done}};
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