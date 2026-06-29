`timescale 1ns/1ps

module NPU #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter C_S_AXI_DATA_WIDTH= 32,
    parameter IMEM_ADDR_WIDTH = 11,
    parameter C_M_AXI_DATA_WIDTH=64,
    parameter C_M_AXI_ADDR_WIDTH=32,
    parameter C_M_AXI_ID_WIDTH=1,
    parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_READ_ID = 0,
	parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_WRITE_ID = 0,
    parameter  C_S_AXI_ADDR_WIDTH = $clog2(C_S_AXI_DATA_WIDTH/8) + IMEM_ADDR_WIDTH
)
(   
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
    

    input logic [2:0]                       S_AXI_AWPROT,
    input logic [2:0]                       S_AXI_ARPROT,

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

logic clk_i, rst_n_i;
always_comb begin
    clk_i=S_AXI_ACLK;
    rst_n_i=S_AXI_ARESETN;
end

// localparam IMEM_ADDR_WIDTH = C_S_AXI_ADDR_WIDTH - ADDRLSB;


logic [C_S_AXI_DATA_WIDTH-1:0]   imem_wr_data_o;
logic [IMEM_ADDR_WIDTH-1:0]   imem_wr_addr_o;
logic [C_S_AXI_DATA_WIDTH/8-1:0] imem_wr_strb_o;
logic                            imem_wr_en_o;
logic [31:0]                     ctrl_reg;
logic [31:0]                      status_reg;
logic [31:0]                    axi_ddr_base_reg;
logic ctrl_read_clear;
assign ctrl_read_clear = mmio_read && (mem_addr == NPU_CTRL_REG_ADDR);
Axil_Slave #(
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
) Axil_Slave_Interface(
    .imem_wr_data_o(imem_wr_data_o),
    .imem_wr_addr_o(imem_wr_addr_o),
    .imem_wr_strb_o(imem_wr_strb_o),
    .imem_wr_en_o(imem_wr_en_o),
    .ctrl_reg_o(ctrl_reg),
    .status_reg_i(status_reg),
    .ddr_base_reg_o(axi_ddr_base_reg),
    .ctrl_read_clear_i(ctrl_read_clear),
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
logic imem_ready_reg;
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
//MMIO CSRs
logic [31:0] sa_cmd_desc_lo;
logic [31:0] lsu_load_desc_lo, lsu_store_desc_lo;
logic [31:0] lsu_ctrl_reg;
logic [9:0] lsu_status_reg;
logic [31:0] exec_status_reg;
localparam MMIO_BASE= 1 << C_S_AXI_ADDR_WIDTH;
localparam SA_CTRL_REG_ADDR = MMIO_BASE + 'h000;
localparam SA_STATUS_REG_ADDR = MMIO_BASE + 'h004;
localparam SA_CMD_DESC_LO = MMIO_BASE + 'h008;
localparam SA_CMD_DESC_HI = MMIO_BASE + 'h00C;
localparam LSU_CTRL_REG_ADDR = MMIO_BASE + 'h010;
localparam LSU_STATUS_REG_ADDR = MMIO_BASE + 'h014; 
localparam LSU_LOAD_DESC_LO = MMIO_BASE + 'h018;
localparam LSU_LOAD_DESC_HI = MMIO_BASE + 'h01C;
localparam LSU_STORE_DESC_LO = MMIO_BASE + 'h020;
localparam LSU_STORE_DESC_HI = MMIO_BASE + 'h024;
localparam NPU_CTRL_REG_ADDR = MMIO_BASE + 'h028;
localparam NPU_STATUS_REG_ADDR = MMIO_BASE + 'h02C;
localparam NPU_DDR_BASE_REG_ADDR = MMIO_BASE + 'h030;
// localparam WEIGHT_DDR_BASE_REG_ADDR = 'h204;
// localparam ACT_DDR_BASE_REG_ADDR = 'h208;
// localparam OUTPUT_DDR_BASE_REG_ADDR = 'h212;
logic mmio_write;
logic mmio_read;
assign mmio_read = mem_valid && ~|mem_wstrb && mem_addr[C_S_AXI_ADDR_WIDTH];
assign mmio_write = mem_valid && |mem_wstrb && mem_addr[C_S_AXI_ADDR_WIDTH];
logic lsu_load_desc_we;
logic lsu_store_desc_we;
assign lsu_load_desc_we = mmio_write && (mem_addr == LSU_LOAD_DESC_HI);
assign lsu_store_desc_we = mmio_write && (mem_addr == LSU_STORE_DESC_HI);
always_ff @( posedge clk_i ) begin 
    if(!rst_n_i) begin
        // dispatch_reg <= '0;
        sa_cmd_desc_lo <= '0;
        {lsu_load_desc_lo,lsu_store_desc_lo,lsu_ctrl_reg}<= '0;
        status_reg <='0;
    end else begin
        // dispatch_reg<= '0;
        if(mmio_write) begin
            case (mem_addr)
                SA_CMD_DESC_LO: sa_cmd_desc_lo <= mem_wdata;
                LSU_CTRL_REG_ADDR: lsu_ctrl_reg <= mem_wdata;
                LSU_LOAD_DESC_LO: lsu_load_desc_lo <= mem_wdata;
                LSU_STORE_DESC_LO: lsu_store_desc_lo <= mem_wdata;
                NPU_STATUS_REG_ADDR: status_reg <= mem_wdata;
            endcase
        end
    end
end
always_ff @( posedge clk_i ) begin
    if(!rst_n_i) begin
        imem_ready_reg<= 1'b0;
    end else begin
        imem_ready_reg<=imem_sel && !imem_ready_reg;
    end
end
assign mem_ready = (imem_sel)? imem_ready_reg : mem_valid;
always_comb begin  
    mmio_datapath = '0;
        if(mmio_read) begin
            case (mem_addr)
                SA_STATUS_REG_ADDR: mmio_datapath = exec_status_reg;
                LSU_STATUS_REG_ADDR: mmio_datapath = lsu_status_reg;
                LSU_CTRL_REG_ADDR: mmio_datapath = lsu_ctrl_reg;
                NPU_DDR_BASE_REG_ADDR: mmio_datapath = axi_ddr_base_reg;
                NPU_STATUS_REG_ADDR: mmio_datapath = status_reg;
                NPU_CTRL_REG_ADDR: mmio_datapath = ctrl_reg;
                default: mmio_datapath = '0;
            endcase
        end
end

assign imem_sel = mem_valid && (mem_addr[C_S_AXI_ADDR_WIDTH]==0); 
assign mem_rdata = imem_sel? imem_data_o : mmio_datapath;
// assign mem_ready =
logic [C_S_AXI_DATA_WIDTH-1:0] imem_bank_a_unused_o;

Memory_Block_TDP #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(IMEM_ADDR_WIDTH)

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

picorv32 #(
    .ENABLE_DIV(1),
    .ENABLE_MUL(1),
    .BARREL_SHIFTER(1)
) Pico_Core(
    .clk(clk_i),
    .resetn(rst_n_i & ctrl_reg[0]),
    .trap(trap),
    .mem_valid(mem_valid),
    .mem_instr(mem_instr),
    .mem_ready(mem_ready),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata)
);


logic [BRAM_ADDR_WIDTH:0] buffers_wr_addr;
logic [BRAM_ADDR_WIDTH-1:0] output_buffer_rd_addr;
 logic output_buffer_rd_en;
logic [63:0] buffers_wr_data;
 logic [63:0] output_buffer_rd_data;
logic [7:0] buffers_wr_strb;
logic lsu_load_done,lsu_load_descriptor_fifo_full,lsu_store_descriptor_fifo_full;
 logic lsu_store_done; 
logic lsu_transfer_is_weight_reg;
logic lsu_act_load_done;
logic lsu_weight_load_done;
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
always_comb begin : lsu_status_signals
    lsu_load_done = lsu_status_reg[1];
    lsu_load_descriptor_fifo_full = lsu_status_reg[3];
    lsu_store_done = lsu_status_reg[6];
    lsu_store_descriptor_fifo_full = lsu_status_reg[8];
end

always_ff @(posedge clk_i) begin
    if(!rst_n_i) begin
        lsu_transfer_is_weight_reg <= 1'b0;
    end else if(|buffers_wr_strb) begin
        lsu_transfer_is_weight_reg <= buffers_wr_addr[BRAM_ADDR_WIDTH];
    end
end
logic store_unit_push_token;
logic load_unit_push_token;
assign lsu_act_load_done = lsu_load_done &&load_unit_push_token&& !lsu_transfer_is_weight_reg;
assign lsu_weight_load_done = lsu_load_done &&load_unit_push_token&& lsu_transfer_is_weight_reg; 
assign lsu_store_done_token = lsu_store_done && store_unit_push_token;

logic act_buffer_full, weight_buffer_full, output_buffer_full;
 logic scu_act_ready, scu_weight_ready, scu_out_ready;
 logic scu_consume_act, scu_consume_weight, scu_produce_out;
Axi_Master_LSU #(
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
    .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH),
    .AXI_READ_ID(AXI_READ_ID),
    .AXI_WRITE_ID(AXI_WRITE_ID)
) axi_master_lsu(
    .buffers_wr_data_o(buffers_wr_data),
    .buffers_wr_addr_o(buffers_wr_addr),
    .buffers_wr_strb_o(buffers_wr_strb),
    .buffers_rd_data_i(output_buffer_rd_data),
    .buffers_rd_addr_o(output_buffer_rd_addr),
    .buffers_rd_en_o(output_buffer_rd_en),
    .load_unit_push_token_o(load_unit_push_token),
    .store_unit_push_token_o(store_unit_push_token),
    .lsu_load_descriptor_fifo_wdata_i({mem_wdata, lsu_load_desc_lo}),
    .lsu_load_descriptor_fifo_we_i(lsu_load_desc_we),
    .lsu_store_descriptor_fifo_wdata_i({mem_wdata, lsu_store_desc_lo}),
    .lsu_store_descriptor_fifo_we_i(lsu_store_desc_we),
    .lsu_status_o(lsu_status_reg),
    .lsu_store_en_i(lsu_ctrl_reg[0]),
    .lsu_load_en_i(lsu_ctrl_reg[1]),
    .act_buffer_full_i(act_buffer_full),
    .weight_buffer_full_i(weight_buffer_full),
    .output_buffer_ready_i(scu_out_ready),
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
logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] activation_mem;
logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] weight_mem;
 logic signed[DATA_WIDTH*ARRAY_SIZE-1:0] output_mem;
logic sa_done, sa_busy;
logic weight_mem_enb, weight_load_en, act_mem_enb;
logic output_mem_we;
logic [BRAM_ADDR_WIDTH-1:0] weight_addrb, act_addrb; 
 logic [BRAM_ADDR_WIDTH-1:0] output_addra;

Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE),
        .ADDR_WIDTH(BRAM_ADDR_WIDTH)
) Weight_Memory(
        .clk_i(clk_i), 
        .ena_i(buffers_wr_addr[BRAM_ADDR_WIDTH]),
        .enb_i(weight_mem_enb),
        .wea_i(buffers_wr_strb),
        .addra_i(buffers_wr_addr),
        .addrb_i(weight_addrb),
        .data_a_i(buffers_wr_data),
        .data_b_o(weight_mem)
);

Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE),
        .ADDR_WIDTH(BRAM_ADDR_WIDTH)
) Activation_Memory(
        .clk_i(clk_i), 
        .ena_i(!buffers_wr_addr[BRAM_ADDR_WIDTH]),
        .enb_i(act_mem_enb),
        .wea_i(buffers_wr_strb),
        .addra_i(buffers_wr_addr),
        .addrb_i(act_addrb),
        .data_a_i(buffers_wr_data),
        .data_b_o(activation_mem)
);
Memory_Block #(
        .DATA_WIDTH(DATA_WIDTH*ARRAY_SIZE),
        .ADDR_WIDTH(BRAM_ADDR_WIDTH)
) Output_Memory(
        .clk_i(clk_i), 
        .ena_i(output_mem_we),
        .enb_i(output_buffer_rd_en),
        .wea_i({8{output_mem_we}}),
        .addra_i(output_addra),
        .addrb_i(output_buffer_rd_addr),
        .data_a_i(output_mem),
        .data_b_o(output_buffer_rd_data)
);

logic systolic_cmd_fifo_full,systolic_cmd_fifo_empty;
logic systolic_cmd_fifo_fifo_we;
assign systolic_cmd_fifo_fifo_we = mmio_write && (mem_addr == SA_CMD_DESC_HI);


Computation_Unit #(
    .ARRAY_SIZE(ARRAY_SIZE), 
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
) Comp_Unit(
    .clk_i(clk_i), 
    .rst_n_i(rst_n_i), 
    .systolic_cmd_fifo_wdata_i({mem_wdata, sa_cmd_desc_lo}),
    .systolic_cmd_fifo_fifo_we_i(systolic_cmd_fifo_fifo_we),
    .systolic_cmd_fifo_full_o(systolic_cmd_fifo_full),
    .systolic_cmd_fifo_empty_o(systolic_cmd_fifo_empty),
    .weight_mem_enb_o(weight_mem_enb),
    .weight_addrb_o(weight_addrb),
    .act_mem_enb_o(act_mem_enb),
    .act_addrb_o(act_addrb),
    .activation_mem_i(activation_mem),
    .output_addra_o(output_addra),
    .output_mem_we_o(output_mem_we),
    .weight_mem_i(weight_mem),
    .output_mem_o(output_mem),
    .scu_act_ready_i(scu_act_ready),
    .scu_weight_ready_i(scu_weight_ready),
    .scu_consumed_act_o(scu_consume_act),
    .scu_consumed_weight_o(scu_consume_weight),
    .scu_produced_out_o(scu_produce_out),
    .sa_done_o(sa_done),
    .sa_busy_o(sa_busy)
);

Sync_Unit sync_unit(
    .clk_i(clk_i), 
    .rst_n_i(rst_n_i),
    .lsu_act_load_done_i(lsu_act_load_done),
    .lsu_weight_load_done_i(lsu_weight_load_done),
    .act_buffer_full_o(act_buffer_full),
    .weight_buffer_full_o(weight_buffer_full),
    .scu_consumed_act_i(scu_consume_act),
    .scu_consumed_weight_i(scu_consume_weight),
    .scu_produced_out_i(scu_produce_out),
    .scu_act_ready_o(scu_act_ready),
    .scu_weight_ready_o(scu_weight_ready),
    .scu_store_done_i(lsu_store_done_token),
    .scu_out_ready_o(scu_out_ready),
    .output_buffer_full_o(output_buffer_full)
);


assign exec_status_reg = {28'b0,{systolic_cmd_fifo_full,systolic_cmd_fifo_empty,sa_busy, sa_done}};



endmodule