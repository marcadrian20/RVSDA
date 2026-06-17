`timescale 1ns/1ps

module Window_Shift_Buffer #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic en_i,
    input logic [DATA_WIDTH*ARRAY_SIZE-1:0]data_i,
    output logic [DATA_WIDTH*ARRAY_SIZE-1:0]data_o
);
//#TODO maybe some higher fmax can be achieved here by registering the first stage too.
//there will be one more clock of delay but will break the combinational path
//from the memory to the sys array 
generate
    genvar i,j;
    for (i = 0; i<ARRAY_SIZE; i++ ) begin: gen_buf
        if(i == 0) begin
            assign data_o[DATA_WIDTH-1:0]=data_i[DATA_WIDTH-1:0];
        end else begin
            logic signed [DATA_WIDTH-1:0] buffer[0:i-1];
            always_ff @(posedge clk_i) begin
                if(!rst_n_i) begin
                    for(int j=0; j<i; j++) 
                        buffer[j]<='0;
                end else begin
                    if(en_i) begin
                        buffer[0] <= data_i[i*DATA_WIDTH +: DATA_WIDTH];
                        for(int j=1; j<i; j++) 
                            buffer[j]<=buffer[j-1];
                    end                
                end
            end
            assign data_o[i*DATA_WIDTH+:DATA_WIDTH]=buffer[i-1];
        end
    end    
endgenerate


endmodule