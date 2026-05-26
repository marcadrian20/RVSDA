// module Axi_Store_Unit #(
//     parameter C_M_AXI_DATA_WIDTH=64,
//     parameter C_M_AXI_ADDR_WIDTH=32,
//     parameter C_M_AXI_ID_WIDTH=1,
// 	parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_WRITE_ID = 0,
//     // parameter BRAM_WIDTH=9,
//     localparam ADDRLSB = $clog2(C_M_AXI_DATA_WIDTH/8),
//     localparam BYTE_SIZE_LOG = ADDRLSB,
//     localparam VALID_ADDR_WIDTH = C_M_AXI_ADDR_WIDTH - ADDRLSB
// )
// (

//     input logic [C_M_AXI_DATA_WIDTH-1:0]   output_buffer_rd_data_i,
//     output logic [VALID_ADDR_WIDTH-1:0]   output_buffer_rd_addr_o,
//     output logic output_buffer_rd_en_o,
    
//     input logic [63:0] descriptor_i,
//     input logic descriptor_queue_empty_i,
  
//     output logic descriptor_queue_pop_o,

//     input logic en_i,
//     // input logic load_unit_en_i,
//     output logic done_o,
//     output logic busy_o,
//     output logic error_o,
//     input logic                             M_AXI_ACLK,
//     input logic                             M_AXI_ARESETN,
    
//     output logic                             M_AXI_AWVALID,
//     input logic                            M_AXI_AWREADY,
//     output logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_AWID,
//     output logic [C_M_AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
//     output logic [7:0]			            M_AXI_AWLEN,
//     output logic [2:0]			            M_AXI_AWSIZE,
//     output logic [1:0]			            M_AXI_AWBURST,
//     output logic    			            M_AXI_AWLOCK,
//     output logic [3:0]			            M_AXI_AWCACHE,
//     output logic [2:0]			            M_AXI_AWPROT,
//     output logic [3:0]			            M_AXI_AWQOS,
    
//     output logic                             M_AXI_WVALID,
//     input logic                            M_AXI_WREADY,
//     output logic [C_M_AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
//     output logic [C_M_AXI_DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
//     output logic                             M_AXI_WLAST,
    
//     input logic                            M_AXI_BVALID,
//     output logic                             M_AXI_BREADY,
//     input logic [C_M_AXI_ID_WIDTH-1:0]	    M_AXI_BID,
//     input logic [1:0]                      M_AXI_BRESP

// );


// localparam INCR_MODE = 2'b01;
// localparam OKAY_RESPONSE = 2'b00;
// localparam BURST_SIZE = $clog2(C_M_AXI_DATA_WIDTH/8);//3'b011; // 8 bytes per transfer/packet, 64 bit wide bus
// localparam MAX_BURST_BEATS = 256;
// localparam LOG_MAX_BURST_BEATS = $clog2(MAX_BURST_BEATS); //log_2 of 256 which is 8 for 256 max beats

// logic [18:0] internal_buff_src_addr_reg;
// logic [31:0] axi_mem_dst_addr_reg;
// logic [12:0] transfer_len_reg;//number of beats for the transfer
// logic [7:0] burst_len;
// logic [12:0] outstanding_writes_counter;
// logic outstanding_writes_flag;
// logic descriptor_load_flag;
// logic start_transaction_flag;
// logic unit_ready;
// logic busy, done, error;
// logic transfer_finished;
// logic zero_transfer_len_flag;
// //////////////DESCRIPTOR FORMAT ON STORES///////////
// //[63         51 50             32 31          0]//
// //[TRANSFER LEN][INTERNAL SRC ADDR][AXI DST ADDR]//
// ///////////////////////////////////////////////////

// //static AXI signals on the write side
// always_comb begin 
//     M_AXI_AWID = AXI_WRITE_ID;
//     M_AXI_AWSIZE = ADDRLSB[2:0];
//     M_AXI_AWBURST = INCR_MODE;
//     M_AXI_AWLOCK = 1'b0;
//     M_AXI_AWCACHE = 4'b0011; // no write/read allocate, but its cacheable and bufferable
//     M_AXI_AWPROT = 3'b0;
//     M_AXI_AWQOS = 4'b0;
//     M_AXI_BREADY = 1'b1;
//     M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH/8){1'b1}}; //#TODO make fix for unaligned writes, for now
//                                                                                // this works all bytes, only aligned reads from axi

// end

// assign done_o = done;
// assign busy_o = busy;
// assign error_o = error;
// assign unit_ready = !busy && en_i;


// //Generate signaling for the master;s state
// always_ff @(posedge M_AXI_ACLK) begin : MASTER_CTRL_STATE_SIG_GEN
//     if(!M_AXI_ARESETN) begin
//         {busy, done, error, start_transaction_flag}<='0;
//     end else begin
//         done <= transfer_finished;

//         // if(error) begin
//         //     done <= 1'b1;    
//         // end
//         start_transaction_flag <= unit_ready && descriptor_load_flag && !zero_transfer_len_flag;
//         if(start_transaction_flag) begin
//             busy <= 1'b1;
//             error <= 1'b0;
//         end 
//         else if(transfer_finished) begin
//             busy <= 1'b0;
//         end

//         if(M_AXI_BVALID && M_AXI_BRESP[1])
//             error <= 1'b1;

//     end
// end

// ///FETCH LOAD DESCRIPTOR FROM FIFO
// typedef enum logic [1:0] { IDLE = 2'b00, DESCRIPTOR_LOAD = 2'b01, DESCRIPTOR_LATCH = 2'b10 } state_t;
// state_t current_state;
// always_ff @( posedge M_AXI_ACLK ) begin : DESCRIPTOR_FSM
//     if(!M_AXI_ARESETN) begin
//         current_state <= IDLE;
//         descriptor_queue_pop_o <= 1'b0;
//         descriptor_load_flag <= 1'b0;
//     end else begin
    
//         descriptor_queue_pop_o <= 1'b0;
//         descriptor_load_flag <= 1'b0;

//         case(current_state)
//             IDLE: begin  
//                     if(unit_ready && !descriptor_queue_empty_i) begin
//                         current_state <= DESCRIPTOR_LOAD;
//                         descriptor_queue_pop_o <= 1'b1;
//                     end
//             end
//             DESCRIPTOR_LOAD: begin 
//                 current_state <= DESCRIPTOR_LATCH; //waiting for the data from the FIFO to drop since its not FWFT
//                 descriptor_load_flag<= 1'b1;
//             end
//             DESCRIPTOR_LATCH:begin
//                 if(busy||zero_transfer_len_flag)
//                     current_state <= IDLE;
//             end
//             //in the next cycle the descriptor is latched.
//         endcase
//     end
// end
// logic [12:0] next_transfer_len;
// ///AW CHANNEL SIGNALING GENERATION
// always_ff @(posedge M_AXI_ACLK) begin : AXI_AWVALID_GEN
//     if (!M_AXI_ARESETN)
//         M_AXI_AWVALID <= 1'b0;
//     else if (start_transaction_flag)
//         M_AXI_AWVALID <= 1'b1;  // first burst on transaction start
//     else if (M_AXI_AWVALID && M_AXI_AWREADY)
//         // Re-arm only if more bursts remain
//         M_AXI_AWVALID <= (next_transfer_len != 0);
// end

// //GENERATE AXI DST ADDRESS TO WRITE TO
// assign M_AXI_AWADDR = axi_mem_dst_addr_reg;
// always_ff @( posedge M_AXI_ACLK ) begin : AXI_ADDR_GEN
//     if(!M_AXI_ARESETN) begin
//         {axi_mem_dst_addr_reg}<= '0; 
//     end else 
//     begin
//         if(descriptor_load_flag) begin
//             axi_mem_dst_addr_reg <= descriptor_i[31:0];
//         end
//         else if(M_AXI_AWVALID && M_AXI_AWREADY) begin
//             axi_mem_dst_addr_reg <= axi_mem_dst_addr_reg + ((burst_len+1)<<BYTE_SIZE_LOG); //!TODO figure out address incrementation and generation 
//         end
//     end
// end

// //Generate the Burst Len for AWLEN
// assign M_AXI_AWLEN = burst_len;
// assign next_transfer_len = transfer_len_reg - (burst_len+1);
// assign zero_transfer_len_flag =(descriptor_i[63:51] == 0);
// always_ff @( posedge M_AXI_ACLK ) begin : AXI_BURSTLEN_GEN
//     if(!M_AXI_ARESETN) begin
//         {transfer_len_reg, burst_len}<= '0; 
//     end else 
//     begin
//         if(descriptor_load_flag) begin
//             transfer_len_reg <= descriptor_i[63:51] >> BYTE_SIZE_LOG; //we presume an aligned transfer size
//                                                                     //And we convert it into total transfer length by dividing by the Datawidth in bytes (64 bits->8bytes)
//                                                                     //That is because we have 8 bytes per beat, so the transfer size per transaction is 8 bytes * MAX_BURST_BEATS 
//             burst_len <= ((descriptor_i[63:51] >> BYTE_SIZE_LOG)>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : (descriptor_i[63:51] >> BYTE_SIZE_LOG)-1;

//         end
//         else if(M_AXI_AWVALID && M_AXI_AWREADY) begin
//             transfer_len_reg <= next_transfer_len;
//             burst_len <= (next_transfer_len>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : next_transfer_len-1;
//         end
//     end
// end
// //Outstanding writes tracking
// assign outstanding_writes_flag = (outstanding_writes_counter>0);
// always_ff @( posedge M_AXI_ACLK ) begin : OUTSTANDING_WRITE_TRACKING
//     if(!M_AXI_ARESETN) begin
//         outstanding_writes_counter<= '0;
//     end else begin
//     case ({M_AXI_AWVALID & M_AXI_AWREADY, M_AXI_BVALID & M_AXI_BREADY})
//         2'b10: outstanding_writes_counter <= outstanding_writes_counter + 1'b1;
//         2'b01: outstanding_writes_counter <= outstanding_writes_counter - 1'b1;
//     endcase 
        
//     end  
// end
// assign transfer_finished = busy && (transfer_len_reg == 0) && (outstanding_writes_counter == 0);
// logic [8:0] beat_counter;
// logic [7:0] burst_len_tracking_fifo_rdata;
// logic burst_len_tracking_fifo_empty;
// logic burst_len_tracking_fifo_full;
// logic burst_len_tracking_fifo_pop;
// assign burst_len_tracking_fifo_pop = M_AXI_WVALID && M_AXI_WREADY && (beat_counter == 0);
// FIFO  #(.DATA_WIDTH(8),
//         .FIFO_DEPTH(4)
// )burst_len_tracking_fifo(
//             .clk_i(M_AXI_ACLK),
//             .rst_n_i(M_AXI_ARESETN),
//             .wdata_i(burst_len),
//             .we_i(M_AXI_AWVALID && M_AXI_AWREADY),
//             .re_i(burst_len_tracking_fifo_pop),
//             .full_o(burst_len_tracking_fifo_full),
//             .empty_o(burst_len_tracking_fifo_empty),
//             .rdata_o(burst_len_tracking_fifo_rdata)    
//         );
// //Write data channel handling
// assign M_AXI_WLAST = beat_counter[8];
// always_ff @( posedge M_AXI_ACLK ) begin : BEAT_COUNTER
//     if (!M_AXI_ARESETN)
//         beat_counter <= '0;
//     else begin
//         // if(descriptor_load_flag) begin
//         //     beat_counter <= ((descriptor_i[63:51] >> BYTE_SIZE_LOG)>MAX_BURST_BEATS)? MAX_BURST_BEATS-2 : (descriptor_i[63:51] >> BYTE_SIZE_LOG)-2;
//         // // -2 from the burst len so that we can underflow the beat counter to drive WLAST
//         if(!burst_len_tracking_fifo_empty && !M_AXI_WVALID) begin
//             beat_counter <= {1'b0, burst_len_tracking_fifo_rdata-1'b1};
//         end
//         else if (M_AXI_WVALID && M_AXI_WREADY) begin
//             beat_counter <= beat_counter - 1'b1;
//             if(M_AXI_WLAST)
//                 beat_counter <= {1'b0, burst_len_tracking_fifo_rdata-1'b1};
//         end
//     end
// end


// always_ff @( posedge M_AXI_ACLK ) begin : AXI_WVALID_GEN
//     if (!M_AXI_ARESETN)
//         M_AXI_WVALID <= '0;
//     else begin  
//         if (!burst_len_tracking_fifo_empty && !M_AXI_WVALID)
//             M_AXI_WVALID <= 1'b1;  // first burst on transaction start
//         else if (M_AXI_WVALID && M_AXI_WREADY && M_AXI_WLAST)
//             M_AXI_WVALID<= !burst_len_tracking_fifo_empty;
//             // M_AXI_WVALID <= !M_AXI_WLAST;// Re-arm only if more bursts remain
//     end
// end

// //Internal buffer address generation
// logic internal_buff_read_en;
// always_ff @( posedge M_AXI_ACLK ) begin : INTERNAL_SCRATCH_ADDR_GEN
//     if(!M_AXI_ARESETN) begin
//         {internal_buff_src_addr_reg, internal_buff_read_en}<= '0;
//     end else 
//     begin
//         if(descriptor_load_flag) begin
//             internal_buff_src_addr_reg <= descriptor_i[50:32];
//             internal_buff_read_en <= 1'b1;    
//         end
//          else if(M_AXI_WVALID && M_AXI_WREADY) begin
//             internal_buff_src_addr_reg <= internal_buff_src_addr_reg + 1'b1; //increment the address for the dst buffer    
//             internal_buff_read_en <= !M_AXI_WLAST;    
//         end
//     end  
// end


// //Internal buffer to external port mapping
// always_comb begin : ScratchpadMapping
//     M_AXI_WDATA = output_buffer_rd_data_i;
//     output_buffer_rd_addr_o = internal_buff_src_addr_reg;
//     output_buffer_rd_en_o = internal_buff_read_en;
//     end
// endmodule


module Axi_Store_Unit #(
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
    output logic [VALID_ADDR_WIDTH-1:0]   output_buffer_rd_addr_o,
    output logic output_buffer_rd_en_o,
    
    input logic [63:0] descriptor_i,
    input logic descriptor_queue_empty_i,
  
    output logic descriptor_queue_pop_o,

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

logic [18:0] internal_buff_src_addr_reg;
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
assign unit_ready = !busy && en_i;

always_ff @(posedge M_AXI_ACLK) begin : MASTER_CTRL_STATE_SIG_GEN
    if(!M_AXI_ARESETN) begin
        {busy, done, error, start_transaction_flag} <= '0;
    end else begin
        done <= transfer_finished;
        start_transaction_flag <= unit_ready && descriptor_load_flag && !zero_transfer_len_flag;
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
    end else begin
        descriptor_queue_pop_o <= 1'b0;
        descriptor_load_flag <= 1'b0;
        case(current_state)
            IDLE: begin  
                if(unit_ready && !descriptor_queue_empty_i) begin
                    current_state <= DESCRIPTOR_LOAD;
                    descriptor_queue_pop_o <= 1'b1;
                end
            end
            DESCRIPTOR_LOAD: begin 
                current_state <= DESCRIPTOR_LATCH; 
                descriptor_load_flag <= 1'b1;
            end
            DESCRIPTOR_LATCH: begin
                if(busy || zero_transfer_len_flag)
                    current_state <= IDLE;
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
assign M_AXI_WLAST  = skid_out_payload[C_M_AXI_DATA_WIDTH];

logic burst_active;

// Handshaking flow control: Keep read window un-gated during counter lifetime
assign output_buffer_rd_en_o = (burst_active || !burst_len_tracking_fifo_empty) && (!internal_wvalid || internal_wready);
assign burst_len_tracking_fifo_pop = output_buffer_rd_en_o && (burst_active ? (beat_counter == 0) : (burst_len_tracking_fifo_rdata == 0));

// Beat Tracking FSM / Counter Logic
always_ff @(posedge M_AXI_ACLK) begin : BEAT_COUNTER
    if (!M_AXI_ARESETN) begin
        beat_counter <= '0;
        burst_active <= 1'b0;
    end else begin
        if (output_buffer_rd_en_o) begin
            if (!burst_active) begin
                if (burst_len_tracking_fifo_rdata == 0) begin
                    burst_active <= 1'b0; 
                end else begin
                    beat_counter <= {1'b0, burst_len_tracking_fifo_rdata} - 1'b1;
                    burst_active <= 1'b1;
                end
            end else begin
                if (beat_counter == 0) begin
                    burst_active <= 1'b0; 
                end else begin
                    beat_counter <= beat_counter - 1'b1;
                end
            end
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
            internal_buff_src_addr_reg <= descriptor_i[50:32];
        end else if(output_buffer_rd_en_o && !last_read_address_reached) begin
            internal_buff_src_addr_reg <= internal_buff_src_addr_reg + 1'b1;
        end
    end  
end

assign output_buffer_rd_addr_o = internal_buff_src_addr_reg;

endmodule