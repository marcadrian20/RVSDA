`timescale 1ns/1ps

module Skid_Buffer_tb;
localparam int DATA_WIDTH      = 8;
localparam int CIRCULAR_BUFFER = 0;
localparam int CLK_PERIOD      = 10;
  
logic                  clk_i;
logic                  rst_n_i;

logic                  input_valid_i;
logic                  input_ready_o;
logic [DATA_WIDTH-1:0] data_i;

logic                  output_valid_o;
logic                  output_ready_i;
logic [DATA_WIDTH-1:0] data_o;

  
// DUT instantiation
  
Skid_Buffer #(
    .DATA_WIDTH      (DATA_WIDTH),
    .CIRCULAR_BUFFER (CIRCULAR_BUFFER)
) dut (
    .clk_i          (clk_i),
    .rst_n_i        (rst_n_i),
    .input_valid_i  (input_valid_i),
    .input_ready_o  (input_ready_o),
    .data_i         (data_i),
    .output_valid_o (output_valid_o),
    .output_ready_i (output_ready_i),
    .data_o         (data_o)
);

  
  
initial clk_i = 0;
always #(CLK_PERIOD/2) clk_i = ~clk_i;

  
  

task wait_cycles(int n);
    repeat(n) @(posedge clk_i);
endtask

task send(input logic [DATA_WIDTH-1:0] data);
    input_valid_i = 1'b1;
    data_i        = data;
    @(posedge clk_i);
    while (!input_ready_o) @(posedge clk_i); 
    input_valid_i = 1'b0;
endtask

task recv(output logic [DATA_WIDTH-1:0] data);
    output_ready_i = 1'b1;
    @(posedge clk_i);
    while (!output_valid_o) @(posedge clk_i); 
    data           = data_o;
    output_ready_i = 1'b0;
endtask

task drain();
    output_ready_i = 1'b1;
    wait_cycles(4);  
    output_ready_i = 1'b0;
    wait_cycles(2);
endtask
  
  
logic [DATA_WIDTH-1:0] received;

initial begin
    rst_n_i        = 1'b0;
    input_valid_i  = 1'b0;
    output_ready_i = 1'b0;
    data_i         = '0;

    wait_cycles(4);
    rst_n_i = 1'b1;
    wait_cycles(2);

    
    $display("-- Test 1: single write then read --");
    send(8'hAA);
    recv(received);
    $display("Expected: 0xAA | Got: 0x%0h | %s", received, (received == 8'hAA) ? "PASS" : "FAIL");
    wait_cycles(2);


    $display("-- Test 2: fill then drain --");
    send(8'hBB);
    send(8'hCC);
    recv(received);
    $display("Expected: 0xBB | Got: 0x%0h | %s", received, (received == 8'hBB) ? "PASS" : "FAIL");
    recv(received);
    $display("Expected: 0xCC | Got: 0x%0h | %s", received, (received == 8'hCC) ? "PASS" : "FAIL");
    wait_cycles(2);

    
    $display("-- Test 3: simultaneous send and receive --");
    send(8'h11);          // load one item first
    input_valid_i  = 1'b1;
    output_ready_i = 1'b1;
    data_i         = 8'h22;
    wait_cycles(2);
    input_valid_i  = 1'b0;
    output_ready_i = 1'b0;
    wait_cycles(2);

   
    $display("Expected: 0x22 | Got: 0x%0h | %s", data_o, (data_o == 8'h22) ? "PASS" : "FAIL");
    $display("State should be BUSY (valid=1): %s", output_valid_o ? "PASS" : "FAIL");


    drain();
    
    $display("-- Test 4: output stalled, buffer goes FULL --");

   
    output_ready_i = 1'b0;

    input_valid_i = 1'b1;
    data_i        = 8'hDD;
    @(posedge clk_i);

    data_i        = 8'hEE;
    @(posedge clk_i);
    input_valid_i = 1'b0;
    @(posedge clk_i);

    $display("input_ready_o should be 0 (FULL): %s", !input_ready_o ? "PASS" : "FAIL");

    output_ready_i = 1'b1;
    @(posedge clk_i);
    $display("Expected: 0xDD | Got: 0x%0h | %s", data_o, (data_o == 8'hDD) ? "PASS" : "FAIL");
    @(posedge clk_i);
    $display("Expected: 0xEE | Got: 0x%0h | %s", data_o, (data_o == 8'hEE) ? "PASS" : "FAIL");
    output_ready_i = 1'b0;
    wait_cycles(2);

    $display("-- Done --");
    $finish;
end

  
  
initial begin
    #10000;
    $display("TIMEOUT");
    $finish;
end
 initial begin
        $dumpfile("skid_buffer_tb.vcd");
        $dumpvars(0, Skid_Buffer_tb);
    end
endmodule