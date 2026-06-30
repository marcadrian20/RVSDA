`timescale 1ns/1ps

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;  

module tb_Axil_Slave_Bram_top();

// Test tracking
xil_axi_uint error_cnt = 0;
xil_axi_uint pass_cnt  = 0;

// VIP agent
design_1_axi_vip_0_0_mst_t mst_agent;

design_1_wrapper DUT();

// Helper tasks
task axi_write(
    input [10:0] addr,
    input [31:0] data,
    input [3:0]  strb
);
    xil_axi_resp_t resp;
    mst_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
    if(resp != XIL_AXI_RESP_OKAY)
        $display("WARNING: Write to 0x%03X non-OKAY response: %0d", addr, resp);
endtask

task axi_read(
    input  [10:0] addr,
    output [31:0] data
);
    xil_axi_resp_t    resp;
    xil_axi_data_beat beat;
    mst_agent.AXI4LITE_READ_BURST(addr, 0, beat, resp);
    data = beat[31:0];
    if(resp != XIL_AXI_RESP_OKAY)
        $display("WARNING: Read from 0x%03X non-OKAY response: %0d", addr, resp);
endtask

task check(
    input string name,
    input logic  condition
);
    if(condition) begin
        $display("PASS: %s", name);
        pass_cnt++;
    end else begin
        $display("FAIL: %s", name);
        error_cnt++;
    end
endtask
    logic [31:0] rd_data;

initial begin
    // Create and start agent - update path from empty sim output
    mst_agent = new("master vip agent",
        DUT.design_1_i.axi_vip_0.inst.IF);
    mst_agent.start_master();

    // Wait for reset to deassert - driven by BD internally
    #200;

      
    // TEST 1: Write CTRL register (byte addr 0x000)
      
    $display("\n--- TEST 1: Write CTRL register ---");
    axi_write(11'h000, 32'hA5A5_A5A5, 4'hF);
    #20;
    check("CTRL reg write",
        DUT.design_1_i.AXIL_TEST_0.inst.ctrl_reg
        == 32'hA5A5_A5A5);

      
    // TEST 2: imem_wr_en NOT asserted on CTRL reg write
      
    $display("\n--- TEST 2: imem_wr_en gating on reg write ---");
    check("imem_wr_en suppressed on CTRL write",
        !DUT.design_1_i.AXIL_TEST_0.inst.imem_wr_en_o);

      
    // TEST 3: Read STATUS register (byte addr 0x004, should be DEADBEEF)
      
    $display("\n--- TEST 3: Read STATUS register ---");
    axi_read(11'h004, rd_data);
    check("STATUS reg read", rd_data == 32'hDEAD_BEEF);

      
    // TEST 4: Write IMEM (byte addr 0x008 = word addr 0x2 = BRAM[2])
      
    $display("\n--- TEST 4: Write IMEM entry ---");
    axi_write(11'h008, 32'hCAFE_BABE, 4'hF);
    #20;
    check("BRAM[2] write",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[2]
        == 32'hCAFE_BABE);

      
    // TEST 5: CTRL write does not corrupt BRAM
      
    $display("\n--- TEST 5: CTRL write does not corrupt BRAM ---");
    axi_write(11'h000, 32'hDEAD_DEAD, 4'hF);
    #20;
    check("BRAM[2] unchanged after CTRL write",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[2]
        == 32'hCAFE_BABE);

      
    // TEST 6: Back to back IMEM writes
      
    $display("\n--- TEST 6: Back to back IMEM writes ---");
    axi_write(11'h008, 32'hAABB_CC01, 4'hF);
    axi_write(11'h00C, 32'hAABB_CC02, 4'hF);
    axi_write(11'h010, 32'hAABB_CC03, 4'hF);
    #20;
    check("Back to back BRAM[2]",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[2]
        == 32'hAABB_CC01);
    check("Back to back BRAM[3]",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[3]
        == 32'hAABB_CC02);
    check("Back to back BRAM[4]",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[4]
        == 32'hAABB_CC03);

      
    // TEST 7: Partial byte strobe
      
    $display("\n--- TEST 7: Partial byte strobe ---");
    axi_write(11'h014, 32'h0000_0000, 4'hF);   // clear first
    axi_write(11'h014, 32'hFF00_0000, 4'b1000); // upper byte only
    #20;
    check("Partial strobe upper byte",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[5]
        == 32'hFF00_0000);

      
    // TEST 8: Write last BRAM entry (byte addr 0x7FC)
      
    $display("\n--- TEST 8: Write last BRAM entry ---");
    axi_write(11'h7FC, 32'hDEAD_BEEF, 4'hF);
    #20;
    check("Last BRAM entry",
        DUT.design_1_i.AXIL_TEST_0.inst.IMEM_Memory.ram[9'h1FF]
        == 32'hDEAD_BEEF);

      
    // Summary
      
    #100;
    $display("\n=============================");
    $display("PASSED : %0d", pass_cnt);
    $display("FAILED : %0d", error_cnt);
    $display("=============================\n");
    $finish;
end

endmodule