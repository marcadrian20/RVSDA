module Axi_Load_Unit #(
    parameter BRAM_ADDR_WIDTH = 9,
    parameter C_M_AXI_DATA_WIDTH=64,
    parameter C_M_AXI_ADDR_WIDTH=32,
    parameter C_M_AXI_ID_WIDTH=1,
    parameter	[C_M_AXI_ID_WIDTH-1:0]	AXI_READ_ID = 0,
    // parameter BRAM_WIDTH=9,
    localparam ADDRLSB = $clog2(C_M_AXI_DATA_WIDTH/8),
    localparam BYTE_SIZE_LOG = ADDRLSB,
    localparam VALID_ADDR_WIDTH = C_M_AXI_ADDR_WIDTH - ADDRLSB
)
(
    output logic [C_M_AXI_DATA_WIDTH-1:0]   buffers_wr_data_o,
    output logic [BRAM_ADDR_WIDTH:0]   buffers_wr_addr_o,
    output logic [C_M_AXI_DATA_WIDTH/8-1:0] buffers_wr_strb_o,

    input logic [63:0] descriptor_i,
    input logic descriptor_queue_empty_i,
    // input logic descriptor_queue_full_i,
    output logic descriptor_queue_pop_o,
    input logic act_buffer_full_i,
    input logic weight_buffer_full_i,
    output logic push_token_o,
    input logic en_i,
    // input logic load_unit_en_i,
    output logic done_o,
    output logic busy_o,
    output logic error_o,

    input logic                             M_AXI_ACLK,
    input logic                             M_AXI_ARESETN,
    
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

localparam INCR_MODE = 2'b01;
localparam OKAY_RESPONSE = 2'b00;
localparam BURST_SIZE = $clog2(C_M_AXI_DATA_WIDTH/8);//3'b011; // 8 bytes per transfer/packet, 64 bit wide bus
localparam MAX_BURST_BEATS = 256;
localparam LOG_MAX_BURST_BEATS = $clog2(MAX_BURST_BEATS); //log_2 of 256 which is 8 for 256 max beats

logic [BRAM_ADDR_WIDTH:0] internal_buff_dst_addr_reg;
logic [31:0] axi_mem_src_addr_reg;
logic [12:0] transfer_len_reg;//number of beats for the transfer
logic [7:0] burst_len;
logic [12:0] outstanding_reads_counter;
logic outstanding_reads_flag;
logic descriptor_load_flag;
logic start_transaction_flag;
logic unit_ready;
logic busy, done, error;
logic transfer_finished;
logic zero_transfer_len_flag;
logic is_weight_route;
logic buffer_stall;
//////////////DESCRIPTOR FORMAT ON LOADS///////////
//[63         51 50             32 31          0]//
//[TRANSFER LEN][INTERNAL DST ADDR][AXI SRC ADDR]//
///////////////////////////////////////////////////

assign is_weight_route = descriptor_i[32 + BRAM_ADDR_WIDTH];
assign buffer_stall = (is_weight_route && weight_buffer_full_i) ||
                      (!is_weight_route && act_buffer_full_i);
// assign descriptor_load_flag = unit_ready && !descriptor_queue_empty_i && !buffer_stall && (current_state == IDLE);
//static AXI signals on the read side
always_comb begin
    M_AXI_ARID = AXI_READ_ID;
    M_AXI_ARSIZE = BURST_SIZE;
    M_AXI_ARBURST = INCR_MODE;
    M_AXI_ARLOCK = 1'b0;
    M_AXI_ARCACHE = 4'b0011; // no write/read allocate, but its cacheable and bufferable
    M_AXI_ARPROT = 3'b0;
    M_AXI_ARQOS = 4'b0;
    M_AXI_RREADY = outstanding_reads_flag;
end

assign done_o = done;
assign busy_o = busy;
assign error_o = error;
assign unit_ready = !busy && en_i;

//Generate signaling for the master;s state
always_ff @(posedge M_AXI_ACLK) begin : MASTER_CTRL_STATE_SIG_GEN
    if(!M_AXI_ARESETN) begin
        {busy, done, error, start_transaction_flag}<='0;
    end else begin
        done <= transfer_finished;

        // if(error) begin
        //     done <= 1'b1;    
        // end
        start_transaction_flag <= unit_ready && descriptor_load_flag && !zero_transfer_len_flag;
        if(start_transaction_flag) begin
            busy <= 1'b1;
            error <= 1'b0;
        end 
        else if(transfer_finished) begin
            busy <= 1'b0;
        end

        if(M_AXI_RVALID && M_AXI_RRESP[1])
            error <= 1'b1;

    end
end

///FETCH LOAD DESCRIPTOR FROM FIFO
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
                    if(unit_ready && !descriptor_queue_empty_i && !buffer_stall) begin
                        current_state <= DESCRIPTOR_LATCH;
                        descriptor_queue_pop_o <= 1'b1;
                        descriptor_load_flag<= 1'b1;

                    end
            end
            // DESCRIPTOR_LOAD: begin 
            //     current_state <= DESCRIPTOR_LATCH; //waiting for the data from the FIFO to drop since its not FWFT
            //     descriptor_load_flag<= 1'b1;
            // end
            DESCRIPTOR_LATCH:begin
                if(busy||zero_transfer_len_flag)
                    current_state <= IDLE;
            end
            //in the next cycle the descriptor is latched.
        endcase
    end
end
logic [12:0] next_transfer_len;

///AR CHANNEL SIGNALING GENERATION
always_ff @(posedge M_AXI_ACLK) begin : AXI_ARVALID_GEN
    if (!M_AXI_ARESETN)
        M_AXI_ARVALID <= 1'b0;
    else if (start_transaction_flag)
        M_AXI_ARVALID <= 1'b1;  // first burst on transaction start
    else if (M_AXI_ARVALID && M_AXI_ARREADY)
        // Re-arm only if more bursts remain
        M_AXI_ARVALID <= (next_transfer_len != 0);
end

//GENERATE AXI SRC ADDRESS TO READ FROM
assign M_AXI_ARADDR = axi_mem_src_addr_reg;
always_ff @( posedge M_AXI_ACLK ) begin : AXI_ADDR_GEN
    if(!M_AXI_ARESETN) begin
        {axi_mem_src_addr_reg}<= '0; 
    end else 
    begin
        if(descriptor_load_flag) begin
            axi_mem_src_addr_reg <= descriptor_i[31:0];
            // transfer_size_reg <= descriptor_i[63:51];
        end
        else if(M_AXI_ARVALID && M_AXI_ARREADY) begin
            axi_mem_src_addr_reg <= axi_mem_src_addr_reg + ((burst_len+1)<<BYTE_SIZE_LOG); //!TODO figure out address incrementation and generation 
        end
    end
end

//Generate the Burst Len for ARLEN
assign M_AXI_ARLEN = burst_len;
assign next_transfer_len = transfer_len_reg - (burst_len+1);
assign zero_transfer_len_flag =(descriptor_i[63:51] == 0);
always_ff @( posedge M_AXI_ACLK ) begin : AXI_BURSTLEN_GEN
    if(!M_AXI_ARESETN) begin
        {transfer_len_reg, burst_len}<= '0; 
    end else 
    begin
        if(descriptor_load_flag) begin
            transfer_len_reg <= descriptor_i[63:51] >> BYTE_SIZE_LOG; //we presume an aligned transfer size
                                                                    //And we convert it into total transfer length by dividing by the Datawidth in bytes (64 bits->8bytes)
                                                                    //That is because we have 8 bytes per beat, so the transfer size per transaction is 8 bytes * MAX_BURST_BEATS 
            burst_len <= ((descriptor_i[63:51] >> BYTE_SIZE_LOG)>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : (descriptor_i[63:51] >> BYTE_SIZE_LOG)-1;
        end
        else if(M_AXI_ARVALID && M_AXI_ARREADY) begin
            transfer_len_reg <= next_transfer_len;
            burst_len <= (next_transfer_len>MAX_BURST_BEATS)? MAX_BURST_BEATS-1 : next_transfer_len-1;
        end
    end
end
//Outstanding reads tracking
assign outstanding_reads_flag = (outstanding_reads_counter>0);
always_ff @( posedge M_AXI_ACLK ) begin : OUTSTANDING_READ_TRACKING
    if(!M_AXI_ARESETN) begin
        outstanding_reads_counter<= '0;
    end else begin
    case ({M_AXI_ARVALID & M_AXI_ARREADY, M_AXI_RVALID & M_AXI_RREADY & M_AXI_RLAST})
        2'b10: outstanding_reads_counter <= outstanding_reads_counter + 1'b1;
        2'b01: outstanding_reads_counter <= outstanding_reads_counter - 1'b1;
    endcase 
        
    end  
end

assign transfer_finished = busy && (transfer_len_reg == 0) && (outstanding_reads_counter == 0);
//Internal buffer address generation
always_ff @( posedge M_AXI_ACLK ) begin : INTERNAL_SCRATCH_ADDR_GEN
    if(!M_AXI_ARESETN) begin
        internal_buff_dst_addr_reg<= '0;
    end else 
    begin
        if(descriptor_load_flag) begin
            internal_buff_dst_addr_reg <= descriptor_i[49:32];    
        end
        else if(M_AXI_RVALID && M_AXI_RREADY) begin
            internal_buff_dst_addr_reg <= internal_buff_dst_addr_reg + 1'b1; //increment the address for the dst buffer    
        end
    end  
end

//Internal buffer port mapping
always_comb begin : ScratchpadMapping
    buffers_wr_data_o = M_AXI_RDATA;
    buffers_wr_addr_o = internal_buff_dst_addr_reg;
    buffers_wr_strb_o = {(C_M_AXI_DATA_WIDTH/8){M_AXI_RVALID & M_AXI_RREADY}}; //#TODO make fix for unaligned writes, for now
                                                                               // this works all bytes, only aligned reads from axi
end


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