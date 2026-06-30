`timescale 1ns/1ps

module tb_pooling_unit;

localparam ARRAY_SIZE = 8;
localparam DATA_WIDTH = 8;
localparam ACC_WIDTH  = 32;
localparam ADDR_WIDTH = 9;

logic clk;
logic rst_n;

logic [3:0] pool_shift_amount;
logic [1:0] pool_type;

logic pool_cfg_valid;
logic [11:0] feature_width;
logic [11:0] feature_height;
logic [23:0] valid_pixels;

logic data_valid_i;
logic data_valid_o;

logic [ADDR_WIDTH-1:0] output_addr_i;
logic [ADDR_WIDTH-1:0] output_addr_o;

logic signed [ARRAY_SIZE*DATA_WIDTH-1:0] data_i;
logic signed [ARRAY_SIZE*DATA_WIDTH-1:0] data_o;

Pooling_Unit #(
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .BRAM_ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .clk_i(clk),
    .rst_n_i(rst_n),

    .pool_shift_amount_i(pool_shift_amount),
    .pool_type_i(pool_type),

    .pool_cfg_valid_i(pool_cfg_valid),
    .feature_width_i(feature_width),
    .feature_height_i(feature_height),
    .valid_pixels_i(valid_pixels),

    .data_valid_i(data_valid_i),
    .data_valid_o(data_valid_o),

    .output_addr_i(output_addr_i),
    .output_addr_o(output_addr_o),

    .data_i(data_i),
    .data_o(data_o)
);

always #5 clk = ~clk;

integer x;
integer y;
integer pixel;
initial begin
    $dumpfile("pooling_unit_tb.vcd");
    $dumpvars(0, dut);
end
initial begin

    clk = 0;
    rst_n = 0;

    pool_shift_amount = 0;
    pool_type         = 2'b01; // MAX_POOL

    pool_cfg_valid = 0;
    feature_width  = 8;
    feature_height = 8;
    valid_pixels   = 64;

    data_valid_i = 0;
    output_addr_i = 0;
    data_i = 0;

    repeat(5) @(posedge clk);

    rst_n = 1;

    @(posedge clk);#1;
    pool_cfg_valid = 1;

    @(posedge clk);#1;
    pool_cfg_valid = 0;

    pixel = 0;

    for (y = 0; y < 8; y++) begin
        for (x = 0; x < 8; x++) begin

            @(posedge clk);#1;

            data_valid_i = 1;

            // Same value on all channels
            for (int ch = 0; ch < ARRAY_SIZE; ch++) begin
                data_i[ch*DATA_WIDTH +: DATA_WIDTH] = pixel + ch*64;
            end

            pixel = pixel + 1;
        end
    end

    @(posedge clk);#1;
    data_valid_i = 0;

    repeat(20) @(posedge clk);

    $finish;
end

// always @(posedge clk) begin
//     if (data_valid_o) begin
//         $display(
//             "time=%0t addr=%0d out_ch0=%0d",
//             $time,
//             output_addr_o,
//             $signed(data_o[7:0])
//         );
//     end
// end
always @(posedge clk) begin
    if(data_valid_o) begin
        $write("addr=%0d :", output_addr_o);

        for(int ch=0; ch<ARRAY_SIZE; ch++)
            $write("ch %0d %0h ; ",
                ch, $signed(data_o[ch*DATA_WIDTH +: DATA_WIDTH]));

        $write("\n");
    //     $display("x=%0d y=%0d pool_col=%0d avg=%0d",
    //      dut.pixel_x,
    //      dut.pixel_y,
    //      dut.pool_col_idx,
    //      $signed(data_o[7:0]));
    end
//     $display(
//     "x=%0d y=%0d odd_row=%0d odd_col=%0d valid=%0d avg=%0d",
//     dut.pixel_x,
//     dut.pixel_y,
//     dut.odd_row,
//     dut.odd_col,
//     data_valid_o,
//     $signed(data_o[7:0])
// );
end
endmodule