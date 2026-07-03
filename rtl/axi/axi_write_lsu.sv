

module Axi_Store_Unit #(
    parameter BRAM_ADDR_WIDTH = 9,
    parameter C_M_AXI_DATA_WIDTH=64,
    parameter C_M_AXI_ADDR_WIDTH=32,
    parameter C_M_AXI_ID_WIDTH=1,
    parameter   [C_M_AXI_ID_WIDTH-1:0]  AXI_WRITE_ID = 0,
    localparam ADDRLSB = $clog2(C_M_AXI_DATA_WIDTH/8),
    localparam BYTE_SIZE_LOG = ADDRLSB,
    localparam VALID_ADDR_WIDTH = C_M_AXI_ADDR_WIDTH - ADDRLSB
)
(
    input logic [C_M_AXI_DATA_WIDTH-1:0]   output_buffer_rd_data_i,
    output logic [BRAM_ADDR_WIDTH-1:0]   output_buffer_rd_addr_o,
    output logic output_buffer_rd_en_o,
    
    input logic [63:0] descriptor_i,
    input logic descriptor_queue_empty_i,
  
    output logic descriptor_queue_pop_o,
    output logic push_token_o,
    input logic output_buffer_ready_i,
    input logic en_i,
    output logic done_o,
    output logic busy_o,
    output logic error_o,
    input logic                              M_AXI_ACLK,
    input logic                              M_AXI_ARESETN,
    
    output logic                             M_AXI_AWVALID,
    input logic                            M_AXI_AWREADY,
    output logic [C_M_AXI_ID_WIDTH-1:0]     M_AXI_AWID,
    output logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
    output logic [7:0]                      M_AXI_AWLEN,
    output logic [2:0]                      M_AXI_AWSIZE,
    output logic [1:0]                      M_AXI_AWBURST,
    output logic                            M_AXI_AWLOCK,
    output logic [3:0]                      M_AXI_AWCACHE,
    output logic [2:0]                      M_AXI_AWPROT,
    output logic [3:0]                      M_AXI_AWQOS,
    
    output logic                             M_AXI_WVALID,
    input logic                            M_AXI_WREADY,
    output logic [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
    output logic                             M_AXI_WLAST,
    
    input logic                            M_AXI_BVALID,
    output logic                             M_AXI_BREADY,
    input logic [C_M_AXI_ID_WIDTH-1:0]      M_AXI_BID,
    input logic [1:0]                      M_AXI_BRESP
);

localparam INCR_MODE = 2'b01;
localparam OKAY_RESPONSE = 2'b00;
localparam MAX_BURST_BEATS = 256;

logic [BRAM_ADDR_WIDTH-1:0] internal_buff_src_addr_reg;
logic [31:0] axi_mem_dst_addr_reg;
logic [12:0] transfer_len_reg;
logic [7:0] burst_len;
logic [12:0] outstanding_writes_counter;
logic descriptor_load_flag;
logic start_transaction_flag;
logic unit_ready;
logic busy, done, error;
logic transfer_finished;
logic zero_transfer_len_flag;
logic buffer_stall;

assign buffer_stall = !output_buffer_ready_i;
// Static AXI mappings
always_comb begin 
    M_AXI_AWID = AXI_WRITE_ID;
    M_AXI_AWSIZE = ADDRLSB[2:0];
    M_AXI_AWBURST = INCR_MODE;
    M_AXI_AWLOCK = 1'b0;
    M_AXI_AWCACHE = 4'b0011; 
    M_AXI_AWPROT = 3'b0;
    M_AXI_AWQOS = 4'b0;
    M_AXI_BREADY = 1'b1;
    M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH/8){1'b1}};
end

assign done_o = done;
assign busy_o = busy;
assign error_o = error;
assign unit_ready = !busy && en_i && (current_state == IDLE);
//assign start_transaction_flag = unit_ready && descriptor_load_flag && !zero_transfer_len_flag;
always_ff @(posedge M_AXI_ACLK) begin : MASTER_CTRL_STATE_SIG_GEN
    if(!M_AXI_ARESETN) begin
        {busy, done, error/*, start_transaction_flag*/} <= '0;
    end else begin
        done <= transfer_finished;
        // start_transaction_flag <= unit_ready && descriptor_load_flag && !zero_transfer_len_flag;
        if(start_transaction_flag) begin
            busy <= 1'b1;
            error <= 1'b0;
        end 
        else if(transfer_finished) begin
            busy <= 1'b0;
        end
        if(M_AXI_BVALID && M_AXI_BRESP[1])
            error <= 1'b1;
    end
end

typedef enum logic [1:0] { IDLE = 2'b00, DESCRIPTOR_LOAD = 2'b01, DESCRIPTOR_LATCH = 2'b10 } state_t;
state_t current_state;
always_ff @( posedge M_AXI_ACLK ) begin : DESCRIPTOR_FSM
    if(!M_AXI_ARESETN) begin
        current_state <= IDLE;
        descriptor_queue_pop_o <= 1'b0;
        descriptor_load_flag <= 1'b0;
        start_transaction_flag  <= 1'b0;
    end else begin
        descriptor_queue_pop_o <= 1'b0;
        descriptor_load_flag <= 1'b0;
        start_transaction_flag  <= 1'b0;
        case(current_state)
            IDLE: begin  
                if(unit_ready && !descriptor_queue_empty_i && !buffer_stall /*&& !done_o*/) begin
                    current_state <= DESCRIPTOR_LATCH;
                    descriptor_queue_pop_o <= 1'b1;
                    descriptor_load_flag<= 1'b1;

                end
            end
            // DESCRIPTOR_LOAD: begin 
            //     current_state <= DESCRIPTOR_LATCH; 
            //     descriptor_load_flag <= 1'b1;
            // end
            DESCRIPTOR_LATCH: begin
                if (descriptor_load_flag && !zero_transfer_len_flag) begin
                    start_transaction_flag <= 1'b1;
                end
                if(transfer_finished || zero_transfer_len_flag) begin
                    current_state <= IDLE;
                end
            end
        endcase
    end
end

logic [12:0] next_transfer_len;
always_ff @(posedge M_AXI_ACLK) begin : AXI_AWVALID_GEN
    if (!M_AXI_ARESETN)
        M_AXI_AWVALID <= 1'b0;
    else if (start_transaction_flag)
        M_AXI_AWVALID <= 1'b1;  
    else if (M_AXI_AWVALID && M_AXI_AWREADY)
        M_AXI_AWVALID <= (next_transfer_len != 0);
end

assign M_AXI_AWADDR = axi_mem_dst_addr_reg;
always_ff @( posedge M_AXI_ACLK ) begin : AXI_ADDR_GEN
    if(!M_AXI_ARESETN) begin
        axi_mem_dst_addr_reg <= '0; 
    end else begin
        if(descriptor_load_flag) begin
            axi_mem_dst_addr_reg <= descriptor_i[31:0];
        end
        else if(M_AXI_AWVALID && M_AXI_AWREADY) begin
            axi_mem_dst_addr_reg <= axi_mem_dst_addr_reg + ((burst_len+1)<<BYTE_SIZE_LOG); 
        end
    end
end

assign M_AXI_AWLEN = burst_len;
assign next_transfer_len = transfer_len_reg - (burst_len+1);
assign zero_transfer_len_flag = (descriptor_i[63:51] == 0);
always_ff @( posedge M_AXI_ACLK ) begin : AXI_BURSTLEN_GEN
    if(!M_AXI_ARESETN) begin
        {transfer_len_reg, burst_len} <= '0; 
    end else begin
        if(descriptor_load_flag) begin
            transfer_len_reg <= descriptor_i[63:51] >> BYTE_SIZE_LOG; 
            burst_len <= ((descriptor_i[63:51] >> BYTE_SIZE_LOG)>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : (descriptor_i[63:51] >> BYTE_SIZE_LOG)-1;
        end
        else if(M_AXI_AWVALID && M_AXI_AWREADY) begin
            transfer_len_reg <= next_transfer_len;
            burst_len <= (next_transfer_len>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : next_transfer_len-1;
        end
    end
end

always_ff @( posedge M_AXI_ACLK ) begin : OUTSTANDING_WRITE_TRACKING
    if(!M_AXI_ARESETN) begin
        outstanding_writes_counter <= '0;
    end else begin
        case ({M_AXI_AWVALID & M_AXI_AWREADY, M_AXI_BVALID & M_AXI_BREADY})
            2'b10: outstanding_writes_counter <= outstanding_writes_counter + 1'b1;
            2'b01: outstanding_writes_counter <= outstanding_writes_counter - 1'b1;
        endcase 
    end  
end
assign transfer_finished = busy && (transfer_len_reg == 0) && (outstanding_writes_counter == 0);

logic [8:0] beat_counter;
logic [7:0] burst_len_tracking_fifo_rdata;
logic burst_len_tracking_fifo_full;
logic burst_len_tracking_fifo_empty;
logic burst_len_tracking_fifo_pop;

// Burst Tracking FIFO Instance
FIFO  #(.DATA_WIDTH(8), .FIFO_DEPTH(4), .FWFT(1)) burst_len_tracking_fifo (
    .clk_i(M_AXI_ACLK),
    .rst_n_i(M_AXI_ARESETN),
    .wdata_i(burst_len),
    .we_i(M_AXI_AWVALID && M_AXI_AWREADY),
    .re_i(burst_len_tracking_fifo_pop),
    .full_o(burst_len_tracking_fifo_full),
    .empty_o(burst_len_tracking_fifo_empty),
    .rdata_o(burst_len_tracking_fifo_rdata)    
);

// Skid Buffer Connections & Instantiation
logic                        internal_wvalid;
logic                        internal_wready;
logic [C_M_AXI_DATA_WIDTH:0] internal_wpayload; 
logic                        skid_out_valid;
logic [C_M_AXI_DATA_WIDTH:0] skid_out_payload;

Skid_Buffer #(.DATA_WIDTH(C_M_AXI_DATA_WIDTH + 1), .CIRCULAR_BUFFER(0)) w_channel_skid_buf (
    .clk_i         (M_AXI_ACLK),
    .rst_n_i       (M_AXI_ARESETN),
    .input_valid_i (internal_wvalid),
    .input_ready_o (internal_wready),
    .data_i        (internal_wpayload),
    .output_valid_o(skid_out_valid),
    .output_ready_i(M_AXI_WREADY),
    .data_o        (skid_out_payload)
);

assign M_AXI_WVALID = skid_out_valid;
assign M_AXI_WDATA  = skid_out_payload[C_M_AXI_DATA_WIDTH-1:0];
assign M_AXI_WLAST  = skid_out_payload[C_M_AXI_DATA_WIDTH] && M_AXI_WVALID;

logic burst_active;

// Handshaking flow control: Keep read window un-gated during counter lifetime
// assign output_buffer_rd_en_o = (burst_active || !burst_len_tracking_fifo_empty) && (!internal_wvalid || internal_wready);
logic start_next_burst;

assign start_next_burst =
    !burst_active &&
    !burst_len_tracking_fifo_empty &&
    !internal_wvalid &&
    !bram_data_valid;
assign output_buffer_rd_en_o =
    (burst_active || start_next_burst) &&
    (!internal_wvalid || internal_wready);
assign burst_len_tracking_fifo_pop = output_buffer_rd_en_o && (burst_active ? (beat_counter == 0) : (burst_len_tracking_fifo_rdata == 0));

// Beat Tracking FSM / Counter Logic
always_ff @(posedge M_AXI_ACLK) begin
    if (!M_AXI_ARESETN) begin
        burst_active <= 0;
        beat_counter <= 0;
    end
    else begin

        if (!burst_active &&
            !burst_len_tracking_fifo_empty &&
            !internal_wvalid &&
            !bram_data_valid)
        begin
            burst_active <= 1'b1;
            beat_counter <= {1'b0,burst_len_tracking_fifo_rdata} - 1'b1;
        end
        else if (output_buffer_rd_en_o && burst_active) begin
            if (beat_counter == 0)
                burst_active <= 1'b0;
            else
                beat_counter <= beat_counter - 1'b1;
        end
    end
end

// Look-ahead tracking for WLAST
logic internal_wlast_lookahead;
always_comb begin
    if (!burst_active) begin
        internal_wlast_lookahead = (burst_len_tracking_fifo_rdata == 0);
    end else begin
        internal_wlast_lookahead = (beat_counter == 0);
    end
end

// =========================================================================
// SYNCHRONOUS DELAY RETIMING ENGINE
// =========================================================================
logic internal_wlast_reg;
logic [C_M_AXI_DATA_WIDTH-1:0] internal_wdata_reg;
logic bram_data_valid;
logic last_beat_pipelined;

// 1. Trace the raw latency valid handshake out of the BRAM block
always_ff @(posedge M_AXI_ACLK) begin : BRAM_VALID_DELAY
    if (!M_AXI_ARESETN) begin
        bram_data_valid <= 1'b0;
    end else if (!internal_wvalid || internal_wready) begin
        bram_data_valid <= output_buffer_rd_en_o;
    end
end

// 2. Delay the lookahead last-beat flag to match memory output timing
always_ff @(posedge M_AXI_ACLK) begin : BRAM_LAST_DELAY
    if (!M_AXI_ARESETN) begin
        last_beat_pipelined <= 1'b0;
    end else if (!internal_wvalid || internal_wready) begin
        last_beat_pipelined <= output_buffer_rd_en_o && internal_wlast_lookahead;
    end
end

// 3. Staging buffer execution
always_ff @(posedge M_AXI_ACLK) begin : BRAM_PIPELINE_DELAY
    if (!M_AXI_ARESETN) begin
        internal_wvalid    <= 1'b0;
        internal_wlast_reg <= 1'b0;
        internal_wdata_reg <= '0;
    end else begin
        if (!internal_wvalid || internal_wready) begin
            internal_wvalid    <= bram_data_valid;
            internal_wlast_reg <= last_beat_pipelined;
            internal_wdata_reg <= output_buffer_rd_data_i; 
        end
    end
end

assign internal_wpayload = {internal_wlast_reg, internal_wdata_reg};

// Guard lookahead check so address index 255 is held stable on the latency cycle
logic last_read_address_reached;
assign last_read_address_reached = (burst_active && (beat_counter == 0)) || (!burst_active && !burst_len_tracking_fifo_empty && (burst_len_tracking_fifo_rdata == 0));

// Internal Scratch Address Generator
always_ff @(posedge M_AXI_ACLK) begin : INTERNAL_SCRATCH_ADDR_GEN
    if(!M_AXI_ARESETN) begin
        internal_buff_src_addr_reg <= '0;
    end else begin
        if(descriptor_load_flag) begin
            internal_buff_src_addr_reg <= descriptor_i[49:32];
        end else if(output_buffer_rd_en_o && !last_read_address_reached) begin
            internal_buff_src_addr_reg <= internal_buff_src_addr_reg + 1'b1;
        end
    end  
end

assign output_buffer_rd_addr_o = internal_buff_src_addr_reg;


logic push_token_reg;

always_ff @(posedge M_AXI_ACLK) begin
    if (!M_AXI_ARESETN) begin
        push_token_reg <= 1'b0;
    end else if (descriptor_load_flag) begin
        push_token_reg <= descriptor_i[50];
    end
end

assign push_token_o = push_token_reg;

endmodule