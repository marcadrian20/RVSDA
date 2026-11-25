`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Execution_Controller (step 3: decoupled decode / weight loader / activation streamer)
//
//   decode  : pops descriptors.  SA descriptors start the weight loader; QUANT and POOL
//             descriptors are barriers (wait until no tile is in flight).
//   loader  : N weight-BRAM reads, one per cycle.  The word stream is skewed per column
//             outside, and a single wl_src_o pulse starts the diagonal capture wave inside
//             the array (see Systolic_Array).  Runs one tile ahead of the streamer.
//   streamer: N tagged activation-row reads, one per cycle.  The first row's issue cycle
//             is the swap strobe for the array.  Tiles can be issued every N cycles.
//
// Schedule (c = decode cycle):
//   c+1      weight read of word 0 presented (tau0)        c+3  wl_src_o pulse (x = tau0+2)
//   c+3      earliest first activation row issue (t = x)   t+N  next tile's first row
// Hazard rules enforced here:
//   * x <= t           : streamer start is held until dec_q2 (2 cycles after decode).
//   * next x >= t + 1  : the loader accepts a new tile only after the streamer consumed the
//                        staged job (sj_valid == 0), i.e. after t of the previous tile.
// Credits: act/weight "ready" is checked at decode, but the SCU counter only drops when the
// consumed_* pulse arrives, so a second tile that pops the same token class is held until the
// first one's pulse has been seen and CREDIT_SETTLE cycles have passed.  Reserving the credit
// at decode inside sync_unit would remove this stall.
// -----------------------------------------------------------------------------
module Execution_Controller #(
    parameter ARRAY_SIZE      = 8,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter ROW_W           = $clog2(ARRAY_SIZE),
    parameter CREDIT_SETTLE   = 2,
    parameter INFLIGHT_W      = 8
)(
    input  logic clk_i,
    input  logic rst_n_i,
    input  logic cmd_fifo_empty_i,
    output logic cmd_fifo_pop_o,
    input  logic [63:0] cmd_fifo_data_i,

    output logic [4:0]  quant_shift_amount_o,
    output logic signed [31:0] quant_mult_o,
    output logic [1:0]  pool_type_o,
    output logic [11:0] pool_feature_width_o,
    output logic [11:0] pool_feature_height_o,
    output logic [23:0] pool_valid_pixels_o,
    output logic        pool_cfg_valid_o,

    output logic weight_mem_enb_o,
    output logic [BRAM_ADDR_WIDTH-1:0] weight_addrb_o,
    output logic wl_src_o,                       // weight capture wave source (cycle x)
    (* MAX_FANOUT = 50 *) output logic act_mem_enb_o,
    output logic [BRAM_ADDR_WIDTH-1:0] act_addrb_o,

    // ---- tag issue port (same cycle as act_mem_enb_o / act_addrb_o) ----
    output logic issue_valid_o,
    output logic issue_first_o,
    output logic issue_last_o,
    output logic [ROW_W-1:0] issue_row_o,
    output logic [BRAM_ADDR_WIDTH-1:0] issue_out_addr_o,
    output logic issue_accum_rd_o,
    output logic issue_accum_wr_o,
    output logic issue_relu_o,
    output logic issue_push_o,
    input  logic tile_done_i,
    input  logic tile_push_i,

    output logic consumed_act_o,
    output logic consumed_weight_o,
    output logic produced_out_o,
    input  logic act_ready_i,
    input  logic weight_ready_i,

    output logic busy_o,
    output logic done_o
);
typedef enum logic[1:0] { DESC_POOL = 2'b01, DESC_SA = 2'b10, DESC_QUANT = 2'b11} desc_type_t;

desc_type_t desc_type;
assign desc_type = desc_type_t'(cmd_fifo_data_i[63:62]);
logic cmd_req_act, cmd_req_weight;
assign cmd_req_act    = cmd_fifo_data_i[58];
assign cmd_req_weight = cmd_fifo_data_i[57];

// ---- state ----
logic [INFLIGHT_W-1:0] inflight;

// loader
logic ld_active, ld_pop_w;
logic [ROW_W:0] ld_cnt;

// staged streamer job (written at decode, consumed at streamer start)
logic sj_valid, sj_armed, dec_q, dec_q2;
logic [BRAM_ADDR_WIDTH-1:0] sj_act_addr, sj_out_base;
logic sj_relu, sj_acc_in, sj_acc_out, sj_push, sj_pop_a;
logic [1:0] sj_pool;

// streamer
logic s_active, s_pop_a;

// credit bookkeeping
logic a_tok_out, w_tok_out;
logic [3:0] a_settle, w_settle;

// ---- decode conditions ----
logic dec_ok, ld_can_accept, a_ok, w_ok, sa_go, cfg_go, s_go;
assign dec_ok        = !cmd_fifo_empty_i && !cmd_fifo_pop_o;   // pop still in flight => head is stale
assign ld_can_accept = (!ld_active || ld_cnt == ARRAY_SIZE-1) && !sj_valid;
assign a_ok          = !cmd_req_act    || (act_ready_i    && !a_tok_out && a_settle == 0);
assign w_ok          = !cmd_req_weight || (weight_ready_i && !w_tok_out && w_settle == 0);
assign sa_go         = dec_ok && desc_type == DESC_SA && ld_can_accept && a_ok && w_ok;
assign cfg_go        = dec_ok && (desc_type == DESC_QUANT || desc_type == DESC_POOL) && inflight == '0;
assign s_go          = sj_armed && (!s_active || issue_last_o);

assign act_mem_enb_o = issue_valid_o;

// Power-up values: the tag shift register has no reset, so its valid/last bits must not see X
// from these registers before the first reset edge (FPGA init values / simulation).
initial begin
    issue_valid_o = 1'b0; issue_last_o = 1'b0; issue_first_o = 1'b0;
end

logic [INFLIGHT_W-1:0] inflight_next;
assign inflight_next = inflight + (sa_go ? 1 : 0) - (tile_done_i ? 1 : 0);

always_ff @(posedge clk_i) begin : ctrl
    cmd_fifo_pop_o    <= 1'b0;
    consumed_act_o    <= 1'b0;
    consumed_weight_o <= 1'b0;
    produced_out_o    <= tile_done_i & tile_push_i;
    pool_cfg_valid_o  <= 1'b0;

    inflight <= inflight_next;
    busy_o   <= (inflight_next != '0);
    if (sa_go) done_o <= 1'b0;
    else if (tile_done_i && inflight == 1) done_o <= 1'b1;

    // ---------------- weight loader ----------------
    if (ld_active) begin
        weight_addrb_o <= weight_addrb_o + 1'b1;
        ld_cnt         <= ld_cnt + 1'b1;
        if (ld_cnt == ARRAY_SIZE-1) begin
            ld_active         <= 1'b0;
            weight_mem_enb_o  <= 1'b0;
            consumed_weight_o <= ld_pop_w;
        end
    end

    // wave source: 3 cycles after decode (tau0 = c+1, x = tau0+2)
    dec_q    <= sa_go;
    dec_q2   <= dec_q;
    wl_src_o <= dec_q2;
    if (dec_q) sj_armed <= 1'b1;

    // ---------------- decode ----------------
    if (sa_go) begin
        cmd_fifo_pop_o   <= 1'b1;
        ld_active        <= 1'b1;
        ld_cnt           <= '0;
        weight_mem_enb_o <= 1'b1;
        weight_addrb_o   <= cmd_fifo_data_i[15 +: BRAM_ADDR_WIDTH];
        ld_pop_w         <= cmd_fifo_data_i[57];
        sj_valid         <= 1'b1;
        sj_act_addr      <= cmd_fifo_data_i[0  +: BRAM_ADDR_WIDTH];
        sj_out_base      <= cmd_fifo_data_i[30 +: BRAM_ADDR_WIDTH];
        sj_relu          <= cmd_fifo_data_i[51];
        sj_acc_in        <= cmd_fifo_data_i[52];
        sj_acc_out       <= cmd_fifo_data_i[53];
        sj_pool          <= cmd_fifo_data_i[55:54];
        sj_push          <= cmd_fifo_data_i[56];
        sj_pop_a         <= cmd_fifo_data_i[58];
    end else if (cfg_go) begin
        cmd_fifo_pop_o <= 1'b1;
        if (desc_type == DESC_QUANT) begin
            quant_shift_amount_o <= cmd_fifo_data_i[61:57];
            quant_mult_o         <= cmd_fifo_data_i[31:0];
        end else begin
            pool_feature_width_o  <= cmd_fifo_data_i[61:50];
            pool_feature_height_o <= cmd_fifo_data_i[49:38];
            pool_valid_pixels_o   <= cmd_fifo_data_i[37:14];
            pool_cfg_valid_o      <= 1'b1;
        end
    end

    // ---------------- activation streamer ----------------
    if (s_active) begin
        // advance within the tile
        act_addrb_o      <= act_addrb_o + 1'b1;
        issue_row_o      <= issue_row_o + 1'b1;
        issue_out_addr_o <= issue_out_addr_o + 1'b1;
        issue_first_o    <= 1'b0;
        issue_last_o     <= (issue_row_o == ARRAY_SIZE-2);
        if (issue_last_o) begin
            s_active       <= 1'b0;
            issue_valid_o  <= 1'b0;
            issue_last_o   <= 1'b0;
            consumed_act_o <= s_pop_a;
        end
    end
    if (s_go) begin
        s_active         <= 1'b1;
        issue_valid_o    <= 1'b1;
        issue_first_o    <= 1'b1;
        issue_last_o     <= 1'b0;
        issue_row_o      <= '0;
        act_addrb_o      <= sj_act_addr;
        issue_out_addr_o <= sj_out_base;
        issue_relu_o     <= sj_relu;
        issue_accum_wr_o <= sj_acc_in;
        issue_accum_rd_o <= sj_acc_out;
        pool_type_o      <= sj_pool;
        issue_push_o     <= sj_push;
        s_pop_a          <= sj_pop_a;
        sj_valid         <= 1'b0;
        sj_armed         <= 1'b0;
    end

    // ---------------- credit settle tracking ----------------
    if (consumed_act_o)         begin a_tok_out <= 1'b0; a_settle <= CREDIT_SETTLE; end
    else if (a_settle != 4'd0)  a_settle <= a_settle - 1'b1;
    if (consumed_weight_o)      begin w_tok_out <= 1'b0; w_settle <= CREDIT_SETTLE; end
    else if (w_settle != 4'd0)  w_settle <= w_settle - 1'b1;
    // a new tile that pops a token class re-arms it (overrides the clear above only if both
    // happen together, which a_ok/w_ok prevent)
    if (sa_go && cmd_req_act)    a_tok_out <= 1'b1;
    if (sa_go && cmd_req_weight) w_tok_out <= 1'b1;

    if (!rst_n_i) begin
        cmd_fifo_pop_o <= 1'b0;
        inflight <= '0;
        {busy_o, done_o} <= '0;
        {consumed_act_o, consumed_weight_o, produced_out_o} <= '0;
        {ld_active, ld_pop_w, ld_cnt} <= '0;
        {sj_valid, sj_armed, dec_q, dec_q2, wl_src_o} <= '0;
        {sj_act_addr, sj_out_base, sj_relu, sj_acc_in, sj_acc_out, sj_push, sj_pop_a, sj_pool} <= '0;
        {s_active, s_pop_a} <= '0;
        {a_tok_out, w_tok_out, a_settle, w_settle} <= '0;
        quant_mult_o <= 32'sh7FFFFFFF;
        quant_shift_amount_o <= '0;
        {pool_feature_width_o, pool_feature_height_o, pool_valid_pixels_o, pool_cfg_valid_o} <= '0;
        {weight_mem_enb_o, weight_addrb_o, act_addrb_o} <= '0;
        {issue_valid_o, issue_first_o, issue_last_o, issue_row_o, issue_out_addr_o} <= '0;
        {issue_accum_rd_o, issue_accum_wr_o, issue_relu_o, issue_push_o, pool_type_o} <= '0;
    end
end
endmodule
