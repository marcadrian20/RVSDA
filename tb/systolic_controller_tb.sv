`timescale 1ns/1ps

module Systolic_Controller_tb;
    parameter ARRAY_SIZE = 8;
    parameter DATA_WIDTH = 8;
    parameter CLK_I_PERIOD = 10;
    parameter ACC_WIDTH = 32;
    parameter MEM_DEPTH = 512;
    parameter ADDR_WIDTH = 9;
    
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

    NPU_SYS_CTRL_TEST #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) NPU_DUT (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .dispatch_i(dispatch_i),
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

   
    task load_weight_memory();
        begin
            integer row, col;
         
            
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
            
            weight_mem_wea_i = '0;
            weight_mem_ena_i = 1'b0;
            weight_input = '0;
            addra_i = '0;
            
           
        end
    endtask

    //                    
    // load_activation_memory
    //                    
    task load_activation_memory();
        begin
            integer row, col;
           
            
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

            
            act_mem_wea_i = '0;
            act_mem_ena_i = 1'b0;
            activation_input = '0;
            addra_i = '0;

          
        end
    endtask

    

    task reset_memories();
        begin
            integer addr;
            $display("\n  Starting Memory Reset  ");
            
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
            
            $display("  Memory Reset Complete  \n");
        end
    endtask

                    
    initial begin
        $dumpfile("Systolic_Controller_tb.vcd");
        $dumpvars(0, Systolic_Controller_tb);
    end

                
    initial begin
        integer row;
        
        {rst_n_i, dispatch_i} = '0;
        {act_mem_ena_i, act_mem_wea_i} = '0;
        {weight_mem_ena_i, weight_mem_wea_i} = '0;
        {activation_input, weight_input} = '0;
        addra_i = '0;
        
        @(posedge clk_i); #1;
        rst_n_i = 1'b0;
        @(posedge clk_i); #1;
        rst_n_i = 1'b1;
        @(posedge clk_i); #1;  

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
        
        repeat(3 * ARRAY_SIZE + 10) @(posedge clk_i);
       
        // Check results
        // $display("\n  Results  ");
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