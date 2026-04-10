`timescale 1ns/1ps

//pipelined skid buffer, basically 2 entry FIFO
module Skid_Buffer #(
    parameter DATA_WIDTH = 8,
    parameter CIRCULAR_BUFFER = 0
)
(
    input logic clk_i,
    input logic rst_n_i,

    input logic input_valid_i,
    output logic input_ready_o,
    input logic [DATA_WIDTH-1:0] data_i,

    output logic output_valid_o,
    input logic output_ready_i,
    output logic [DATA_WIDTH-1:0] data_o    
);

typedef enum logic[2:0] { EMPTY = 3'b001, BUSY = 3'b010, FULL = 3'b100 } state_t;
state_t current_state, next_state;

logic [DATA_WIDTH-1:0] data_buffer_reg;
logic [DATA_WIDTH-1:0] data_mux_o;

logic use_buffered_data;
logic data_buffer_we;
logic data_o_we;

assign data_mux_o=(use_buffered_data == 1'b1)? data_buffer_reg : data_i;



logic insert, remove;
assign insert = input_valid_i&&input_ready_o;
assign remove = output_valid_o&&output_ready_i;

// ---------------------------------------------------------------------------
// Named datapath transitions (directly mirrors the state diagram)
//
//                /--\ +- flow
//                |  |
//         load   |  v   fill
//  -------  +   ------   +   ------         (CBM)
// |       |---> |      |---> |      | ---\ +  dump
// | Empty |     | Busy |     | Full |    |    or
// |       |<--- |      |<--- |      | <--/ +- pass
//  -------   -   ------   -   ------
//          unload        flush
// ---------------------------------------------------------------------------

logic load; // Empty datapath inserts data into output register.
logic flow; // New inserted data into output register as the old data is removed.
logic fill; // New inserted data into buffer register. Data not removed from output register.
logic flush; // Move data from buffer register into output register. Remove old data. No new data inserted.
logic unload; // Remove data from output register, leaving the datapath empty.
logic dump; // New inserted data into buffer register. Move data from buffer register into output register. Discard old output data. (CBM)
logic pass; // New inserted data into buffer register. Move data from buffer register into output register. Remove old output data.  (CBM)

always_comb begin
    load    = (current_state == EMPTY) && (insert == 1'b1) && (remove == 1'b0);
    flow    = (current_state == BUSY)  && (insert == 1'b1) && (remove == 1'b1);
    fill    = (current_state == BUSY)  && (insert == 1'b1) && (remove == 1'b0);
    unload  = (current_state == BUSY)  && (insert == 1'b0) && (remove == 1'b1);
    flush   = (current_state == FULL)  && (insert == 1'b0) && (remove == 1'b1);
    dump    = (current_state == FULL)  && (insert == 1'b1) && (remove == 1'b0) && (CIRCULAR_BUFFER != 0);
    pass    = (current_state == FULL)  && (insert == 1'b1) && (remove == 1'b1) && (CIRCULAR_BUFFER != 0);
end

always_comb begin
    next_state = current_state;
    if (load)   next_state = BUSY;
    if (flow)   next_state = BUSY;
    if (fill)   next_state = FULL;
    if (unload) next_state = EMPTY;
    if (flush)  next_state = BUSY;
    if (dump)   next_state = FULL;
    if (pass)   next_state = FULL;
end

always_ff @( posedge clk_i ) begin : state_register_ff
    if(!rst_n_i) begin
        current_state<=EMPTY;
        input_ready_o<=1'b1;
        output_valid_o<=1'b0;
    end else begin 
        current_state<=next_state;
        input_ready_o<=(next_state != FULL) || (CIRCULAR_BUFFER != 0);
        output_valid_o<=(next_state!=EMPTY);
    end
end

always_comb begin
        data_o_we     = (load  == 1'b1) || (flow == 1'b1) || (flush == 1'b1) || (dump == 1'b1) || (pass == 1'b1);
        data_buffer_we  = (fill  == 1'b1)                                      || (dump == 1'b1) || (pass == 1'b1);
        use_buffered_data = (flush == 1'b1)                                      || (dump == 1'b1) || (pass == 1'b1);
end

always_ff @( posedge clk_i ) begin 
    if(!rst_n_i)
        {data_buffer_reg, data_o}<='0;
    else begin 
        if(data_buffer_we)
            data_buffer_reg<=data_i;
        if(data_o_we)
            data_o<=data_mux_o;

    
    end
end
endmodule