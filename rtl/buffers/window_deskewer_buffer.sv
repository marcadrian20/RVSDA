`timescale 1ns/1ps

module Window_Unskew_Buffer #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic en_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0] data_i,
    output logic [DATA_WIDTH*ARRAY_SIZE-1:0] data_o
);

genvar i;

generate
    for (i = 0; i < ARRAY_SIZE; i++) begin : gen_buf
        
        // Channel 0 needs the longest delay chain (ARRAY_SIZE stages)
        // Channel 7 needs the shortest delay chain (1 stage)
        localparam int DELAY_STAGES = ARRAY_SIZE - i;        
        // Dynamically size the buffer array for this specific channel lane
        logic [DATA_WIDTH-1:0] buffer [0:DELAY_STAGES-1];   
        initial begin
            for (int j = 0; j < DELAY_STAGES; j++)
                buffer[j] = '0;
        end

        always_ff @(posedge clk_i) begin
            // if (!rst_n_i) begin
            //     for (int j = 0; j < DELAY_STAGES; j++) begin
            //         buffer[j] <= '0;
            //     end
            // end else 
            if (en_i) begin
                // Clean straight-through mapping: Channel i maps directly to Lane i
                buffer[0] <= data_i[i*DATA_WIDTH +: DATA_WIDTH];
                
                // Cascade down the pipeline registers
                for (int j = 1; j < DELAY_STAGES; j++) begin
                    buffer[j] <= buffer[j-1];
                end
            end
        end
        
        // Drive Output Lane i safely from the final register stage of its chain
        assign data_o[i*DATA_WIDTH +: DATA_WIDTH] = buffer[DELAY_STAGES-1];
    end
endgenerate

endmodule