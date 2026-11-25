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
//assign ctrl_read_clear = mmio_read && (dBus_cmd_payload_address == NPU_CTRL_REG_ADDR);
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
//============================================================
// VexRiscv Harvard bus interface (replaces PicoRV32 unified mem_* bus)
//============================================================
// iBus: instruction fetch, read-only, mapped to Instruction_Memory Port A
logic         iBus_cmd_valid;
logic         iBus_cmd_ready;
logic [31:0]  iBus_cmd_payload_pc;
logic         iBus_rsp_valid;
logic         iBus_rsp_payload_error;
logic [31:0]  iBus_rsp_payload_inst;

// dBus: data read/write (Instruction_Memory Port A's data region + MMIO), mapped to Port B
logic         dBus_cmd_valid;
logic         dBus_cmd_ready;
logic         dBus_cmd_payload_wr;
logic [3:0]   dBus_cmd_payload_mask;
logic [31:0]  dBus_cmd_payload_address;
logic [31:0]  dBus_cmd_payload_data;
logic [1:0]   dBus_cmd_payload_size;
logic         dBus_rsp_ready;
logic         dBus_rsp_error;
logic [31:0]  dBus_rsp_data;

logic         reqCpuReset;   // debug-triggered reset request from the core, unused here
logic         vex_reset;     // active-high reset for VexRiscv

logic         imem_sel;         // dBus address targets Instruction_Memory (vs MMIO)
logic         imem_sel_d1;      // imem_sel delayed 1 cycle, aligned with BRAM's registered read data
logic [31:0]  imem_portB_rdata; // Port B read data (data-side accesses into Instruction_Memory)
logic [31:0]  mmio_datapath;
logic [31:0]  mmio_datapath_reg;
//logic [3:0]   dBus_wstrb;

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
assign mmio_read = dBus_cmd_valid && !dBus_cmd_payload_wr && dBus_cmd_payload_address[C_S_AXI_ADDR_WIDTH];
assign mmio_write = dBus_cmd_valid && dBus_cmd_payload_wr && dBus_cmd_payload_address[C_S_AXI_ADDR_WIDTH];

// Registered copy of the dBus MMIO write. The adder/stall logic ends at these flops.
logic        mw_v_q, mr_v_q;
logic [31:0] mw_addr_q, mw_data_q;
always_ff @(posedge clk_i) begin
    if (!rst_n_i) begin 
        mw_v_q <= 1'b0; mr_v_q <= 1'b0; 
        end
    else begin         
        mw_v_q <= mmio_write; mr_v_q <= mmio_read; 
    end
    mw_addr_q <= dBus_cmd_payload_address;
    mw_data_q <= dBus_cmd_payload_data;
end
assign ctrl_read_clear = mr_v_q && (mw_addr_q == NPU_CTRL_REG_ADDR);

logic lsu_load_desc_we;
logic lsu_store_desc_we;
assign lsu_load_desc_we  = mw_v_q && (mw_addr_q == LSU_LOAD_DESC_HI);
assign lsu_store_desc_we = mw_v_q && (mw_addr_q == LSU_STORE_DESC_HI);
always_ff @( posedge clk_i ) begin 
    if(!rst_n_i) begin
        // dispatch_reg <= '0;
        sa_cmd_desc_lo <= '0;
        {lsu_load_desc_lo,lsu_store_desc_lo,lsu_ctrl_reg}<= '0;
        status_reg <='0;
    end else begin
        // dispatch_reg<= '0;
        if (mw_v_q) begin
            case (mw_addr_q)
                SA_CMD_DESC_LO:      sa_cmd_desc_lo   <= mw_data_q;
                LSU_CTRL_REG_ADDR:   lsu_ctrl_reg     <= mw_data_q;
                LSU_LOAD_DESC_LO:    lsu_load_desc_lo <= mw_data_q;
                LSU_STORE_DESC_LO:   lsu_store_desc_lo<= mw_data_q;
                NPU_STATUS_REG_ADDR: status_reg       <= mw_data_q;
            endcase
        end
    end
end

//============================================================
// dBus response timing: VexRiscv expects read data + rsp_ready exactly
// 1 cycle after cmd_valid (no same-cycle/combinational response like
// PicoRV32's mem_ready). Writes need no response pulse at all.
//============================================================
always_ff @( posedge clk_i ) begin
    if(!rst_n_i) begin
        imem_sel_d1     <= 1'b0;
        dBus_rsp_ready  <= 1'b0;
    end else begin
        imem_sel_d1     <= imem_sel;
        //dBus_rsp_ready  <= dBus_cmd_valid && !dBus_cmd_payload_wr;
        dBus_rsp_ready <= (imem_sel && !dBus_cmd_payload_wr) || mr_v_q;
    end
end

always_comb begin  
    mmio_datapath = '0;
        if(mr_v_q) begin
            case (mw_addr_q)
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

// mmio_datapath is combinational off this cycle's address; register it so
// it lines up with dBus_rsp_ready, which pulses one cycle later.
always_ff @(posedge clk_i) begin
    mmio_datapath_reg <= mmio_datapath;
end

assign imem_sel  = dBus_cmd_valid && (dBus_cmd_payload_address[C_S_AXI_ADDR_WIDTH] == 1'b0);
// Port B (BRAM) already has 1 cycle of registered read latency on its own,
// so imem_portB_rdata is naturally aligned with dBus_rsp_ready. The MMIO
// path needed an explicit register above to match that same timing.
assign dBus_rsp_data  = imem_sel_d1 ? imem_portB_rdata : mmio_datapath_reg;
assign dBus_rsp_error = 1'b0;
assign dBus_cmd_ready = 1'b1;
assign iBus_cmd_ready = 1'b1;

// assign dBus_wstrb = (dBus_cmd_payload_size == 2'd0) ? (4'b0001 << dBus_cmd_payload_address[1:0]) :
//                      (dBus_cmd_payload_size == 2'd1) ? (4'b0011 << dBus_cmd_payload_address[1:0]) :
//                                                         4'b1111;

always_ff @(posedge clk_i) begin
    if(!rst_n_i)
        iBus_rsp_valid <= 1'b0;
    else
        iBus_rsp_valid <= iBus_cmd_valid;
end
assign iBus_rsp_payload_error = 1'b0;

assign vex_reset = !rst_n_i | !ctrl_reg[0];

logic cpu_running;
logic imem_ena;
logic [IMEM_ADDR_WIDTH-1:0] imem_addra;
logic [3:0] imem_wea;

assign cpu_running = ctrl_reg[0]; 
assign imem_ena = cpu_running | imem_wr_en_o;
assign imem_wea = (!cpu_running & imem_wr_en_o)? imem_wr_strb_o: 4'b0000;
assign imem_addra = cpu_running? iBus_cmd_payload_pc[C_S_AXI_ADDR_WIDTH-1:2]:imem_wr_addr_o;

// Port A: dedicated instruction fetch (iBus), written by the axi slave whenever the firmware is loaded.
// Port B: data access (dBus) -- serves both this BRAM's data region and,
// combined with mmio_datapath above, the MMIO register space.
Memory_Block_TDP #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(IMEM_ADDR_WIDTH)

) Instruction_Memory(
        .clk_i(clk_i), 
        .ena_i(imem_ena),
        .enb_i(imem_sel),
        .wea_i(imem_wea),
        .web_i(imem_sel && dBus_cmd_payload_wr? dBus_cmd_payload_mask : 4'b0000),
        .addra_i(imem_addra),
        .addrb_i(dBus_cmd_payload_address[C_S_AXI_ADDR_WIDTH-1:2]),
        .data_a_i(imem_wr_data_o),
        .data_a_o(iBus_rsp_payload_inst),
        .data_b_i(dBus_cmd_payload_data),
        .data_b_o(imem_portB_rdata)
);

/*VexRiscvWithDebug u_vex (
    .clk                        (clk_i),
    .reset                      (vex_reset),

    .io_iBus_cmd_valid          (iBus_cmd_valid),
    .io_iBus_cmd_ready          (iBus_cmd_ready),
    .io_iBus_cmd_payload_pc     (iBus_cmd_payload_pc),

    .io_iBus_rsp_valid          (iBus_rsp_valid),
    .io_iBus_rsp_payload_error  (iBus_rsp_payload_error),
    .io_iBus_rsp_payload_inst   (iBus_rsp_payload_inst),

    .io_dBus_cmd_valid          (dBus_cmd_valid),
    .io_dBus_cmd_ready          (dBus_cmd_ready),
    .io_dBus_cmd_payload_wr     (dBus_cmd_payload_wr),
    .io_dBus_cmd_payload_address(dBus_cmd_payload_address),
    .io_dBus_cmd_payload_data   (dBus_cmd_payload_data),
    .io_dBus_cmd_payload_size   (dBus_cmd_payload_size),

    .io_dBus_rsp_ready          (dBus_rsp_ready),
    .io_dBus_rsp_error          (dBus_rsp_error),
    .io_dBus_rsp_data           (dBus_rsp_data),

    .io_timerInterrupt          (1'b0),
    .io_externalInterrupt       (1'b0),

    .io_reqCpuReset             (reqCpuReset),

    .io_jtag_tck                (1'b0),
    .io_jtag_tms                (1'b1),
    .io_jtag_tdi                (1'b1),
    .io_jtag_tdo                ()
);*/

VexRiscv u_vex (
    .clk                        (clk_i),
    .reset                      (vex_reset),

    .iBus_cmd_valid          (iBus_cmd_valid),
    .iBus_cmd_ready          (iBus_cmd_ready),
    .iBus_cmd_payload_pc     (iBus_cmd_payload_pc),

    .iBus_rsp_valid          (iBus_rsp_valid),
    .iBus_rsp_payload_error  (iBus_rsp_payload_error),
    .iBus_rsp_payload_inst   (iBus_rsp_payload_inst),

    .dBus_cmd_valid          (dBus_cmd_valid),
    .dBus_cmd_ready          (dBus_cmd_ready),
    .dBus_cmd_payload_wr     (dBus_cmd_payload_wr),
    .dBus_cmd_payload_mask   (dBus_cmd_payload_mask),
    .dBus_cmd_payload_address(dBus_cmd_payload_address),
    .dBus_cmd_payload_data   (dBus_cmd_payload_data),
    .dBus_cmd_payload_size   (dBus_cmd_payload_size),

    .dBus_rsp_ready          (dBus_rsp_ready),
    .dBus_rsp_error          (dBus_rsp_error),
    .dBus_rsp_data           (dBus_rsp_data),

    .timerInterrupt          (1'b0),
    .externalInterrupt       (1'b0),
    .softwareInterrupt       (1'b0)
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
    .lsu_load_descriptor_fifo_wdata_i({mw_data_q, lsu_load_desc_lo}),
        .lsu_load_descriptor_fifo_we_i(lsu_load_desc_we),
    .lsu_store_descriptor_fifo_wdata_i({mw_data_q, lsu_store_desc_lo}),
        .lsu_store_descriptor_fifo_we_i(lsu_store_desc_we),
    .lsu_status_o(lsu_status_reg),
    .lsu_store_en_i(lsu_ctrl_reg[0]),
    .lsu_load_en_i(lsu_ctrl_reg[1]),
    .act_buffer_full_i(act_buffer_full),
    .weight_buffer_full_i(weight_buffer_full),
    .output_buffer_ready_i(scu_out_ready),
    // .output_buffer_ready_i(1'b1),
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
assign systolic_cmd_fifo_fifo_we = mw_v_q && (mw_addr_q == SA_CMD_DESC_HI);

Computation_Unit #(
    .ARRAY_SIZE(ARRAY_SIZE), 
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
) Comp_Unit(
    .clk_i(clk_i), 
    .rst_n_i(rst_n_i), 
    .systolic_cmd_fifo_wdata_i({mw_data_q, sa_cmd_desc_lo}),
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