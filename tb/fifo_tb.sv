`timescale 1ns/1ps

module fifo_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 4;
    parameter CLK_PERIOD = 10;

    // DUT signals
    logic                       clk_i;
    logic                       rst_n_i;
    logic [DATA_WIDTH-1:0]      wdata_i;
    logic                       we_i;
    logic                       re_i;
    logic                       full_o;
    logic                       empty_o;
    logic [DATA_WIDTH-1:0]      rdata_o;

    // DUT instantiation
    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk_i      (clk_i),
        .rst_n_i    (rst_n_i),
        .wdata_i    (wdata_i),
        .we_i       (we_i),
        .re_i       (re_i),
        .full_o     (full_o),
        .empty_o    (empty_o),
        .rdata_o    (rdata_o)
    );

    // Clock generation
    initial clk_i = 0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // Main test sequence
    initial begin
        // Init signals
        rst_n_i = 0;
        we_i    = 0;
        re_i    = 0;
        wdata_i = 0;

        // Apply reset
        repeat(2) @(posedge clk_i);#1;
        rst_n_i = 1;
        @(posedge clk_i);#1;

         
        // TEST 1: Fill FIFO to full
         
        $display("TEST 1: Writing until full");
        repeat(FIFO_DEPTH) begin
            @(posedge clk_i);#1;
            we_i    = 1;
            wdata_i = $urandom();
            $display("  Write: wdata=0x%0h | full=%0b empty=%0b", wdata_i, full_o, empty_o);
        end
        @(posedge clk_i);#1;
        we_i = 0;
        $display("  After fill: full=%0b empty=%0b", full_o, empty_o);

         
        // TEST 2: Write when full (should be ignored)
         
        $display("TEST 2: Write when full (should be ignored)");
        @(posedge clk_i);#1;
        we_i    = 1;
        wdata_i = 32'hDEADBEEF;
        @(posedge clk_i);#1;
        we_i = 0;
        $display("  full=%0b (expect 1)", full_o);

         
        // TEST 3: Drain FIFO to empty
         
        $display("TEST 3: Reading until empty");
        repeat(FIFO_DEPTH) begin
            @(posedge clk_i); #1;
            re_i = 1;
            @(posedge clk_i); #1;  // extra cycle for BRAM read latency
            re_i = 0;
            $display("  Read: rdata=0x%0h | full=%0b empty=%0b", rdata_o, full_o, empty_o);
        end
        $display("  After drain: empty=%0b (expect 1)", empty_o);
         
        // TEST 4: Read when empty (should be ignored)
         
        $display("TEST 4: Read when empty (should be ignored)");
        @(posedge clk_i);#1;
        re_i = 1;
        @(posedge clk_i);#1;
        re_i = 0;
        $display("  empty=%0b (expect 1)", empty_o);

         
        // TEST 5: Simultaneous read and write
         
        $display("TEST 5: Simultaneous read & write");
        // Pre-load one entry
        @(posedge clk_i);#1;
        we_i = 1; wdata_i = 32'hA5A5A5A5;
        @(posedge clk_i);#1;
        we_i = 0;
        // Now do simultaneous R/W
        @(posedge clk_i);#1;
        we_i = 1; re_i = 1; wdata_i = 32'hCAFEBABE;
        @(negedge clk_i);#1;
        $display("  Simultaneous: rdata=0x%0h | full=%0b empty=%0b", rdata_o, full_o, empty_o);
        @(posedge clk_i);#1;
        we_i = 0; re_i = 0;

        $display("All tests done.");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("TIMEOUT");
        $finish;
    end
    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end
endmodule

