module Credit_Counter#(
    parameter MAX_CREDITS = 2,
    parameter INIT_COUNT = 0,
    parameter BIT_WIDTH = $clog2(MAX_CREDITS+1)
)(
    input logic clk_i,
    input logic rst_n_i,
    input logic inc_credit_i,
    input logic dec_credit_i,
    output logic credit_ready_o,
    output logic credit_full_o,
    output logic [BIT_WIDTH-1:0] count_o
);
    logic [BIT_WIDTH-1:0] count_reg;
    always_ff @( posedge clk_i ) begin
        if (!rst_n_i) begin
            count_reg <= BIT_WIDTH'(INIT_COUNT);
        end else begin
            case ({inc_credit_i, dec_credit_i})
                2'b10: begin
                    if(count_reg < MAX_CREDITS)
                        count_reg <= count_reg + 1'b1; 
                end
                2'b01: begin
                    if(count_reg > 0)
                        count_reg <= count_reg - 1'b1; 
                end 
                default: count_reg <= count_reg; 
            endcase
        end
    end

    assign credit_ready_o = !(count_reg == 0);
    assign credit_full_o = (count_reg == BIT_WIDTH'(MAX_CREDITS)); 
    assign count_o = count_reg;
endmodule