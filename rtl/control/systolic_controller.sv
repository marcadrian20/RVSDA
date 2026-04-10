`timescale 1ns/1ps

module Systolic_Controller #(
    parameter ARRAY_SIZE = 8
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic dispatch_i,
    output logic act_data_feeder_en_o,
    output logic output_data_deskewer_en_o,
    output logic weight_mem_enb_o,
    output logic weight_load_en_o,
    output logic act_mem_enb_o,
    output logic [8:0] weight_addrb_o,
    output logic [8:0] act_addrb_o,
    output logic busy_o,
    output logic done_o

);

typedef enum logic[1:0] { IDLE = 2'b00, LOAD_WEIGHT = 2'b01, LOAD_ACT = 2'b10, DRAIN = 2'b11} state_t;
state_t current_state, next_state;
logic [3:0] counter;
// always_ff @(posedge clk_i)begin
//     if(!rst_n_i) begin
//         current_state<=IDLE;
//     end else begin
//         current_state<=next_state;
//     end
// end

// always_comb begin
//     next_state = IDLE;
//     weight_load_en_o = 1'b0;
//     case (current_state)
//         IDLE:
//             if(dispatch_i)
//                 next_state = LOAD_WEIGHT;
//         LOAD_WEIGHT:
//             weight_load_en_o = 1'b1;

//         LOAD_ACT:
//         DRAIN:
//         default: next_state=IDLE; 
//     endcase
// end

always_ff @( posedge clk_i ) begin : fsm_controller
    
    counter <= counter + 1'b1;
    case (current_state)
            IDLE: begin
                if(dispatch_i) begin
                    current_state <= LOAD_WEIGHT;
                    weight_load_en_o <= 1'b1;
                    busy_o <= 1'b1;
                    counter <='0;
                    done_o<= 1'b0;
                    weight_mem_enb_o <= 1'b1;
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
                end
            end
            LOAD_ACT: begin
                act_addrb_o <= act_addrb_o + 1'b1;
                if(counter == ARRAY_SIZE + ARRAY_SIZE - 1 ) begin
                    current_state <= DRAIN;
                    output_data_deskewer_en_o <= 1'b1;
                    act_addrb_o <= '0;
                    act_data_feeder_en_o <= 1'b0;
                    act_mem_enb_o <= 1'b0;
                    counter <='0;
                end
            end
            DRAIN: begin
                if(counter == ARRAY_SIZE - 1) begin
                    current_state <= IDLE;
                    output_data_deskewer_en_o <= 1'b0;
                    done_o <=1'b1;
                    busy_o <= 1'b0;
                    counter<='0;
                end
            end 
            default: current_state <= IDLE; 
    endcase
    if(!rst_n_i) begin
        current_state <= IDLE;
        counter <='0;
        {act_addrb_o, weight_addrb_o} <= '0;
        {done_o, busy_o, weight_load_en_o, act_data_feeder_en_o} <= '0;
        {output_data_deskewer_en_o, weight_mem_enb_o, act_mem_enb_o} <= '0;
    end
end
endmodule
