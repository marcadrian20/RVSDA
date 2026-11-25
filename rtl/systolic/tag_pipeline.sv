`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Tag_Pipeline
//
// A fixed-latency shift register that carries the control information ("tag")
// of every activation row alongside the data as it flows through
//   act BRAM -> skew -> systolic array -> deskew -> accumulation buffer
//            -> quantizer -> pooling -> output BRAM.
//
// The tag is presented in the SAME cycle as the activation BRAM address/enable
// of the row it describes (the "issue cycle", t).  Stage s of the shift
// register is therefore the tag as seen at cycle t+s, and each consumer simply
// taps the stage whose delay matches where that row's data is at that moment.
//
// All latencies are derived from ARRAY_SIZE, so no counter constants are
// scattered through the controller any more:
//
//   t+1              BRAM data valid (registered read in Memory_Block)
//   t+N+2+j          array bottom, column j
//   t+2N+2  (tD)     deskewed data at the accumulation buffer input
//   tD-1             accumulation buffer read issue (re / addrb)
//   tD               accumulate_en (gates stored partial sum into the adder)
//   tD+1             accumulation buffer write (we / addra), data_o valid
//   tD+5             quantizer clamp/relu stage (per-tile relu tag is applied here)
//   tD+6             quantizer output == pooling data_valid_i / output_addr_i
//   tD+7             output BRAM write (pooling output register)
//   tD+7  (T_DONE)   last row's write has landed -> tile complete
//
// There is no reset on the shift register on purpose: without one it maps to
// SRLs on Xilinx devices.  The valid bits are cleared by the initial block.
// -----------------------------------------------------------------------------
module Tag_Pipeline #(
    parameter ARRAY_SIZE      = 8,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter QUANT_LATENCY   = 5,   // register stages inside Quantization_Unit
    parameter ROW_W           = $clog2(ARRAY_SIZE)
)(
    input  logic                       clk_i,

    // ---- issue port: aligned with act_mem_enb_o / act_addrb_o ----
    input  logic                       issue_valid_i,
    input  logic                       issue_last_i,       // last row of the tile
    input  logic [ROW_W-1:0]           issue_row_i,        // row index inside the tile
    input  logic [BRAM_ADDR_WIDTH-1:0] issue_out_addr_i,   // output BRAM address for this row
    input  logic                       issue_accum_rd_i,   // add previously stored partial sum
    input  logic                       issue_accum_wr_i,   // store result in accumulation buffer
    input  logic [1:0]                 issue_pool_type_i,
    input  logic                       issue_relu_i,       // per-tile ReLU, applied at the quantizer output stage
    input  logic                       issue_push_i,       // tile pushes an output token when it completes

    // ---- accumulation buffer controls ----
    output logic                       acc_rd_en_o,
    output logic [ROW_W-1:0]           acc_rd_addr_o,
    output logic                       acc_en_o,
    output logic                       acc_wr_en_o,
    output logic [ROW_W-1:0]           acc_wr_addr_o,

    // ---- pooling / output write controls (aligned with quantizer output) ----
    output logic                       pool_valid_o,
    output logic [BRAM_ADDR_WIDTH-1:0] pool_addr_o,
    output logic [1:0]                 pool_type_o,
    output logic                       relu_o,             // aligned with the quantizer's clamp/relu stage (tD+5)

    // ---- completion ----
    output logic                       tile_done_o,        // last row written to output BRAM
    output logic                       tile_push_o         // that tile carries an output token
);

    localparam int T_DESKEW = 2*ARRAY_SIZE + 2;
    localparam int T_ACC_RD = T_DESKEW - 1;
    localparam int T_ACC_EN = T_DESKEW;
    localparam int T_ACC_WR = T_DESKEW + 1;
    localparam int T_POOL   = T_DESKEW + 1 + QUANT_LATENCY;
    localparam int T_RELU   = T_POOL - 1;   // relu_en is sampled combinationally on scaled_data_reg
    localparam int T_DONE   = T_POOL + 1;

    typedef struct packed {
        logic                       valid;
        logic                       last;
        logic                       accum_rd;
        logic                       accum_wr;
        logic [1:0]                 pool_type;
        logic                       relu;
        logic                       push;
        logic [ROW_W-1:0]           row;
        logic [BRAM_ADDR_WIDTH-1:0] out_addr;
    } tag_t;

    localparam int TAG_W = $bits(tag_t);

    // Stages 1..T_DONE as one flat shift register (stage s lives in
    // sr[(s-1)*TAG_W +: TAG_W]); stage 0 is the issue tag itself.
    logic [T_DONE*TAG_W-1:0] sr;

    initial sr = '0;

    tag_t issue_tag;
    always_comb begin
        issue_tag.valid     = issue_valid_i;
        issue_tag.last      = issue_last_i;
        issue_tag.accum_rd  = issue_accum_rd_i;
        issue_tag.accum_wr  = issue_accum_wr_i;
        issue_tag.pool_type = issue_pool_type_i;
        issue_tag.relu      = issue_relu_i;
        issue_tag.push      = issue_push_i;
        issue_tag.row       = issue_row_i;
        issue_tag.out_addr  = issue_out_addr_i;
    end

    always_ff @(posedge clk_i)
        sr <= {sr[(T_DONE-1)*TAG_W-1:0], issue_tag};

    // ---------------- taps ----------------
    tag_t tap_acc_rd, tap_acc_en, tap_acc_wr, tap_pool, tap_relu, tap_done;
    assign tap_acc_rd = sr[(T_ACC_RD-1)*TAG_W +: TAG_W];
    assign tap_acc_en = sr[(T_ACC_EN-1)*TAG_W +: TAG_W];
    assign tap_acc_wr = sr[(T_ACC_WR-1)*TAG_W +: TAG_W];
    assign tap_pool   = sr[(T_POOL  -1)*TAG_W +: TAG_W];
    assign tap_relu   = sr[(T_RELU  -1)*TAG_W +: TAG_W];
    assign tap_done   = sr[(T_DONE  -1)*TAG_W +: TAG_W];

    assign acc_rd_en_o   = tap_acc_rd.valid & tap_acc_rd.accum_rd;
    assign acc_rd_addr_o = tap_acc_rd.row;

    assign acc_en_o      = tap_acc_en.valid & tap_acc_en.accum_rd;

    assign acc_wr_en_o   = tap_acc_wr.valid & tap_acc_wr.accum_wr;
    assign acc_wr_addr_o = tap_acc_wr.row;

    // A row reaches the output BRAM unless it was only stored for accumulation.
    assign pool_valid_o  = tap_pool.valid & ~tap_pool.accum_wr;
    assign pool_addr_o   = tap_pool.out_addr;
    assign pool_type_o   = tap_pool.valid ? tap_pool.pool_type : 2'b00;

    assign relu_o        = tap_relu.valid & tap_relu.relu;

    assign tile_done_o   = tap_done.valid & tap_done.last;
    assign tile_push_o   = tap_done.push;

endmodule
