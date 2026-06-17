module Sync_Unit #()(
    input logic clk_i,
    input logic rst_n_i,

    input logic lsu_act_load_done_i,
    input logic lsu_weight_load_done_i,
    output logic act_buffer_full_o,
    output logic weight_buffer_full_o,

    input logic scu_consumed_act_i,
    input logic scu_consumed_weight_i,
    input logic scu_produced_out_i,
    output logic scu_act_ready_o,
    output logic scu_weight_ready_o, 

    input logic scu_store_done_i,
    output logic scu_out_ready_o,
    output logic output_buffer_full_o

);

    Credit_Counter #(.MAX_CREDITS(128)) act_side_counter (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .inc_credit_i(lsu_act_load_done_i),
        .dec_credit_i(scu_consumed_act_i),
        .credit_ready_o(scu_act_ready_o),
        .credit_full_o(act_buffer_full_o),
        .count_o()
    );

    Credit_Counter #(.MAX_CREDITS(128)) weight_side_counter (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .inc_credit_i(lsu_weight_load_done_i),
        .dec_credit_i(scu_consumed_weight_i),
        .credit_ready_o(scu_weight_ready_o),
        .credit_full_o(weight_buffer_full_o),
        .count_o()
    );

    Credit_Counter #(.MAX_CREDITS(128)) output_side_counter (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .inc_credit_i(scu_produced_out_i),
        .dec_credit_i(scu_store_done_i),
        .credit_ready_o(scu_out_ready_o),
        .credit_full_o(output_buffer_full_o),
        .count_o()
    );

endmodule