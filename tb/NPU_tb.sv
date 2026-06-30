`timescale 1ns/1ps

module NPU_tb;
    parameter ARRAY_SIZE = 8;
    parameter DATA_WIDTH = 8;
    parameter CLK_I_PERIOD = 10;
    parameter ACC_WIDTH = 32;
    parameter MEM_DEPTH = 512;
    parameter ADDR_WIDTH = 9;
    parameter C_S_AXI_DATA_WIDTH= 32;
    parameter C_S_AXI_ADDR_WIDTH=11;
    
    logic clk_i;
    logic rst_n_i;
    logic dispatch_i;
    logic act_mem_ena_i;
    logic [DATA_WIDTH*ARRAY_SIZE/8-1:0] act_mem_wea_i;
    logic weight_mem_ena_i;
    logic [DATA_WIDTH*ARRAY_SIZE/8-1:0] weight_mem_wea_i;
    logic [ADDR_WIDTH-1:0] addra_i;
    
    logic [DATA_WIDTH*ARRAY_SIZE-1:0] activation_input;
    logic [DATA_WIDTH*ARRAY_SIZE-1:0] weight_input;
    logic signed [ACC_WIDTH*ARRAY_SIZE-1:0] result_output;

    logic                             S_AXI_ACLK;
    logic                             S_AXI_ARESETN;
    logic                             S_AXI_AWVALID;
    logic                            S_AXI_AWREADY;
    logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR;
    logic                             S_AXI_WVALID;
    logic                            S_AXI_WREADY;
    logic [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA;
    logic [C_S_AXI_DATA_WIDTH/8-1:0]  S_AXI_WSTRB;
    logic                            S_AXI_BVALID;
    logic                             S_AXI_BREADY;
    logic [1:0]                      S_AXI_BRESP;
    logic                             S_AXI_ARVALID;
    logic                            S_AXI_ARREADY;
    logic [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR;
    logic                            S_AXI_RVALID;
    logic                             S_AXI_RREADY;
    logic [C_S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA;
    logic [1:0]                      S_AXI_RRESP;
    logic [2:0]                       S_AXI_AWPROT;
    logic [2:0]                       S_AXI_ARPROT;

    NPU #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) NPU_DUT (
        .S_AXI_ACLK(clk_i),
        .S_AXI_ARESETN(rst_n_i),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .act_mem_ena_i(act_mem_ena_i),
        .act_mem_wea_i(act_mem_wea_i),
        .weight_mem_ena_i(weight_mem_ena_i),
        .weight_mem_wea_i(weight_mem_wea_i),
        .activation_data_i(activation_input),
        .weight_data_i(weight_input),
        .addra_i(addra_i),
        .data_o(result_output)
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #(CLK_I_PERIOD/2) clk_i = ~clk_i;
    end

    // Test matrices
    logic signed [DATA_WIDTH-1:0] matrix_a [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] matrix_b [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [31:0] expected_result [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]; 

      
    // calculate_expected
      
    task calculate_expected();
        begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                for (int j = 0; j < ARRAY_SIZE; j++) begin
                    expected_result[i][j] = 0;
                    for (int k = 0; k < ARRAY_SIZE; k++) begin
                        expected_result[i][j] += matrix_a[i][k] * matrix_b[k][j];
                    end
                    $display("Expected[%0d][%0d] = %0d", i, j, expected_result[i][j]);
                end
            end
        end
    endtask

      
    // load_weight_memory
      
    task load_weight_memory();
        begin
            integer row, col;
            $display("\n=== Starting Weight Memory Load ===");
            
            @(posedge clk_i); #1;
            weight_mem_wea_i = 'hFF;
            weight_mem_ena_i = 1'b1;
            
            for (row = 0; row < ARRAY_SIZE; row++) begin
                addra_i = row;
                weight_input = '0;
                for (col = 0; col < ARRAY_SIZE; col++) begin
                    weight_input[(col * DATA_WIDTH) +: DATA_WIDTH] = matrix_b[row][col];
                end
                $display("Loading weight row %0d: %h", row, weight_input);
                @(posedge clk_i); #1;
            end
            
            // Extra cycle for last write to commit
            weight_mem_wea_i = '0;
            weight_mem_ena_i = 1'b0;
            weight_input = '0;
            addra_i = '0;
            
            $display("=== Weight Memory Load Complete ===\n");
        end
    endtask

      
    // load_activation_memory
      
    task load_activation_memory();
        begin
            integer row, col;
            $display("\n=== Starting Activation Memory Load ===");
            
            @(posedge clk_i); #1;
            act_mem_wea_i = 'hFF;
            act_mem_ena_i = 1'b1;

            for (row = 0; row < ARRAY_SIZE; row++) begin
                addra_i = row;
                activation_input = '0;
                for (col = 0; col < ARRAY_SIZE; col++) begin
                    activation_input[(col * DATA_WIDTH) +: DATA_WIDTH] = matrix_a[row][col];
                end
                $display("Loading activation row %0d: %h", row, activation_input);
                @(posedge clk_i); #1;
            end

            // Extra cycle for last write to commit
            act_mem_wea_i = '0;
            act_mem_ena_i = 1'b0;
            activation_input = '0;
            addra_i = '0;

            $display("=== Activation Memory Load Complete ===\n");
        end
    endtask

      
    // read_and_process
      
    // task read_and_process();
    //     begin
    //         integer row;
    //         $display("\n=== Starting Read and Process ===");
            
    //         // --- Weight loading phase ---
    //         @(posedge clk_i); #1;
    //         weight_mem_enb_i = 1'b1;
    //         weight_load_en_i = 1'b1;  // FIX: set once before loop, not inside it
    //         // addrb_i = '0;

    //         for (row = 0; row < ARRAY_SIZE; row++) begin
    //             addrb_i = row;
    //             $display("Reading weight row %0d", row);
    //             @(posedge clk_i); #1;
    //         end

     
    //         @(posedge clk_i); #1;
    //         weight_mem_enb_i = 1'b0;
    //         weight_load_en_i = 1'b0;
    //         addrb_i = '0;

    //         // --- Activation dispatch phase ---
    //         act_mem_enb_i = 1'b1;
    //         addrb_i = '0;
    //         @(posedge clk_i); #1;
    //         addrb_i = 1;
    //         dispatch_i = 1'b1;        

    //         for (row = 2; row < ARRAY_SIZE; row++) begin
    //             @(posedge clk_i); #1;
    //             addrb_i = row;
    //             $display("Reading activation row %0d", row);
    //         end

    //        @(posedge clk_i); #1;
    //         act_mem_enb_i = 1'b0;
    //         repeat(ARRAY_SIZE - 1) @(posedge clk_i);
    //         dispatch_i = 1'b0;
    //         addrb_i = '0;

    //         $display("=== Read and Process Complete ===\n");
    //     end
    // endtask

    task reset_memories();
        begin
            integer addr;
            $display("\n=== Starting Memory Reset ===");
            
            @(posedge clk_i); #1;
            weight_mem_wea_i = 'hFF;
            weight_mem_ena_i = 1'b1;
            // weight_mem_enb_i = 1'b0;
            
            for (addr = 0; addr < MEM_DEPTH; addr++) begin
                @(posedge clk_i); #1;
                addra_i = addr;
                weight_input = '0;
            end
            
            @(posedge clk_i); #1;
            weight_mem_wea_i = '0;
            weight_mem_ena_i = 1'b0;

            @(posedge clk_i); #1;
            act_mem_wea_i = 'hFF;
            act_mem_ena_i = 1'b1;
            // act_mem_enb_i = 1'b0;
            
            for (addr = 0; addr < MEM_DEPTH; addr++) begin
                @(posedge clk_i); #1;
                addra_i = addr;
                activation_input = '0;
            end
            
            @(posedge clk_i); #1;
            act_mem_wea_i = '0;
            act_mem_ena_i = 1'b0;
            activation_input = '0;
            weight_input = '0;
            addra_i = '0;
            
            $display("=== Memory Reset Complete ===\n");
        end
    endtask

      
    // Dump
      
    initial begin
        $dumpfile("NPU_tb.vcd");
        $dumpvars(0, NPU_tb);
    end

      
    // Main stimulus
      
    initial begin
        integer row;
        
        // Initialize all signals
        {rst_n_i, dispatch_i} = '0;
        {act_mem_ena_i, act_mem_wea_i} = '0;
        {weight_mem_ena_i, weight_mem_wea_i} = '0;
        {activation_input, weight_input} = '0;
        {S_AXI_AWPROT, S_AXI_ARPROT, S_AXI_BREADY} = '0;
        {S_AXI_ARVALID, S_AXI_ARADDR, S_AXI_AWADDR} = '0;
        {S_AXI_RREADY, S_AXI_WVALID,S_AXI_AWVALID} = '0;
        {S_AXI_WDATA, S_AXI_WSTRB} = '0;
        addra_i = '0;
        
        // Reset sequence
        @(posedge clk_i); #1;
        rst_n_i = 1'b0;
        @(posedge clk_i); #1;
        rst_n_i = 1'b1;
        @(posedge clk_i); #1;  // one clean cycle after reset release

        // Fill matrix_a
        for (row = 0; row < ARRAY_SIZE; row++)
            for (int col = 0; col < ARRAY_SIZE; col++)
                matrix_a[row][col] = row + col + 1;

        // Fill matrix_b
        for (row = 0; row < ARRAY_SIZE; row++)
            for (int col = 0; col < ARRAY_SIZE; col++)
                matrix_b[row][col] = row + col + 1;

        // calculate_expected();

        // load_weight_memory();
        // load_activation_memory();
        // read_and_process();
        @(posedge clk_i); #1;
        dispatch_i=1'b1;
        @(posedge clk_i); #1;
        dispatch_i=1'b0;
        
        repeat(10000) @(posedge clk_i);
        // Wait(NPU_DUT.dispatch_reg);
        // read_and_process();
        // repeat(3 * ARRAY_SIZE + 10) @(posedge clk_i);
        
        // Check results
        // $display("\n=== Results ===");
        // for (int i = 0; i < ARRAY_SIZE; i++) begin
        //     $display("Output[%0d] = %0d | Expected[%0d][0] = %0d",
        //         i,
        //         $signed(result_output[(i*ACC_WIDTH) +: ACC_WIDTH]),
        //         i,
        //         expected_result[i][0]);
        // end

        $display("\nFinal output raw: %h", result_output);
        $finish;
    end

endmodule