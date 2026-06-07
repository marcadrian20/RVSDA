`timescale 1ns/1ps

module Systolic_Controller #(
    parameter ARRAY_SIZE = 8,
    parameter BRAM_ADDR_WIDTH = 9
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic cmd_fifo_empty_i,
    output logic cmd_fifo_pop_o,
    input logic [63:0] cmd_fifo_data_i,
    output logic quant_en_o,
    output logic relu_en_o,
    output logic [4:0] quant_shift_amount_o,
    output logic [1:0] pool_type_o,
    output logic act_data_feeder_en_o,
    output logic output_data_deskewer_en_o,
    output logic accumulate_en_o,
    output logic accumulate_rd_en_o,
    output logic accumulate_wr_en_o,
    output logic [$clog2(ARRAY_SIZE)-1:0] accumulate_rd_addr_o,
    output logic [$clog2(ARRAY_SIZE)-1:0] accumulate_wr_addr_o,
    output logic weight_mem_enb_o,
    output logic weight_load_en_o,
    output logic act_mem_enb_o,
    output logic output_mem_we_o,
    output logic [BRAM_ADDR_WIDTH-1:0] weight_addrb_o,
    output logic [BRAM_ADDR_WIDTH-1:0] act_addrb_o,
    output logic [BRAM_ADDR_WIDTH-1:0] output_addra_o,
    
    output logic consumed_act_o,
    output logic consumed_weight_o,
    output logic produced_out_o,
    input logic act_ready_i,
    input logic weight_ready_i,

    output logic push_out_token_o,    
    output logic pop_weight_token_o,
    output logic pop_act_token_o,    
    output logic busy_o,
    output logic done_o

);

typedef enum logic[1:0] { IDLE = 2'b00, LOAD_WEIGHT = 2'b01, LOAD_ACT = 2'b10, DRAIN = 2'b11} state_t;
state_t current_state;
logic [4:0] counter;
logic accum_out;
logic accum_in;

logic cmd_req_act;
logic cmd_req_weight;
assign cmd_req_act = cmd_fifo_data_i[58]; 
assign cmd_req_weight = cmd_fifo_data_i[57];

always_ff @( posedge clk_i ) begin : fsm_controller
    
    counter <= counter + 1'b1;
    cmd_fifo_pop_o <= 1'b0;

    consumed_act_o <= 1'b0;
    consumed_weight_o <= 1'b0;
    produced_out_o <= 1'b0;

    case (current_state)
            IDLE: begin
                if(!cmd_fifo_empty_i) begin
                    if((!cmd_req_act || act_ready_i) && (!cmd_req_weight || weight_ready_i)) begin
                        
                        current_state <= LOAD_WEIGHT;
                        weight_load_en_o <= 1'b1;
                        busy_o <= 1'b1;
                        counter <='0;
                        done_o<= 1'b0;
                        weight_mem_enb_o <= 1'b1;
                        cmd_fifo_pop_o <= 1'b1;

                        act_addrb_o <= cmd_fifo_data_i[14:0];
                        weight_addrb_o <= cmd_fifo_data_i[29:15];
                        output_addra_o <= cmd_fifo_data_i[44:30];
                        quant_shift_amount_o <= cmd_fifo_data_i[49:45];
                        quant_en_o <=  cmd_fifo_data_i[50];
                        relu_en_o <=   cmd_fifo_data_i[51];
                        accum_in <= cmd_fifo_data_i[52];
                        accum_out <= cmd_fifo_data_i[53];
                        pool_type_o <= cmd_fifo_data_i[55:54];

                        push_out_token_o <= cmd_fifo_data_i[56];
                        pop_weight_token_o <= cmd_fifo_data_i[57];
                        pop_act_token_o <= cmd_fifo_data_i[58];
                    end
                end
            end 
            LOAD_WEIGHT: begin
                weight_addrb_o <= weight_addrb_o + 1'b1;
                if(counter == ARRAY_SIZE) begin
                    current_state <= LOAD_ACT;
                    weight_addrb_o <= '0;
                    weight_mem_enb_o <= 1'b0;
                    weight_load_en_o <= 1'b0;
                    counter <='0;
                    act_data_feeder_en_o <= 1'b1;
                    act_mem_enb_o <= 1'b1;
                    consumed_weight_o <= pop_weight_token_o;
                end
            end
            LOAD_ACT: begin
                act_addrb_o <= act_addrb_o + 1'b1;
                if(counter == ARRAY_SIZE) //accounting for the quantization unit
                    output_data_deskewer_en_o <= 1'b1;
                if(counter == ARRAY_SIZE + ARRAY_SIZE - 1 ) begin
                    current_state <= DRAIN;
                    consumed_act_o <= pop_act_token_o;
                    act_addrb_o <= '0;
                    act_data_feeder_en_o <= 1'b0;
                    act_mem_enb_o <= 1'b0;
                    counter <='0;
                    accumulate_wr_addr_o <= '0;
                    accumulate_rd_addr_o <= '0;
                    accumulate_rd_en_o <= accum_out;
                    accumulate_en_o <= accum_out;
                    accumulate_wr_en_o <= accum_in;

                end
            end
            DRAIN: begin
                if(counter == 2) begin//account for that quantization pipeline
                    output_mem_we_o <= !accum_in;                
                end
                if(counter >= 1) begin//account for the bram we latency
                    accumulate_wr_addr_o <= accumulate_wr_addr_o + 1'b1; 
                end
                if(counter >= 3) begin//account for the bram we latency
                    if(!accum_in) begin
                        output_addra_o <= output_addra_o + 1'b1;
                    end 
                end
                if(accum_out) begin
                    if(counter < ARRAY_SIZE - 1)
                        accumulate_rd_addr_o <= accumulate_rd_addr_o +1'b1;
                    else
                        accumulate_rd_en_o <= 1'b0;
                end
                if(counter == ARRAY_SIZE) begin
                    accumulate_wr_en_o <= 1'b0; 
                end
                if(counter == ARRAY_SIZE+2) begin //account now for the output deskewers pipeline
                    current_state <= IDLE;
                    output_data_deskewer_en_o <= 1'b0;
                    output_mem_we_o <= 1'b0;
                    accumulate_wr_en_o <= 1'b0;
                    accumulate_rd_en_o <= 1'b0;
                    accumulate_en_o <= 1'b0;
                    pool_type_o <= '0;
                    done_o <=1'b1;
                    busy_o <= 1'b0;
                    counter<='0;

                    produced_out_o <= push_out_token_o;
                end
            end 
            default: current_state <= IDLE; 
    endcase
    if(!rst_n_i) begin
        current_state <= IDLE;
        counter <='0;
        cmd_fifo_pop_o <= 1'b0;
        pool_type_o <= '0;
        {push_out_token_o, pop_weight_token_o, pop_act_token_o} <= '0;

        {consumed_act_o, consumed_weight_o, produced_out_o} <= '0;
        {accum_in, accum_out, accumulate_en_o} <='0;
        {accumulate_rd_en_o, accumulate_wr_en_o}<='0;
        {accumulate_rd_addr_o,accumulate_wr_addr_o} <= '0;
        {quant_shift_amount_o, quant_en_o, relu_en_o, output_mem_we_o} <='0;
        {act_addrb_o, weight_addrb_o, output_addra_o} <= '0;
        {done_o, busy_o, weight_load_en_o, act_data_feeder_en_o} <= '0;
        {output_data_deskewer_en_o, weight_mem_enb_o, act_mem_enb_o} <= '0;
    end
end
endmodule
