`timescale 1ns/1ps

import axi_vip_pkg::*;
import npu_bd_axi_vip_0_0_pkg::*;   // AXI-Lite master  (firmware load + ctrl)
import npu_bd_axi_vip_1_0_pkg::*;   // AXI4 slave mem   (NPU data port)

module tb_npu();


// Test tracking

xil_axi_uint error_cnt = 0;
xil_axi_uint pass_cnt  = 0;


// VIP agents

npu_bd_axi_vip_0_0_mst_t     mst_agent;   // AXI-Lite master
npu_bd_axi_vip_1_0_slv_mem_t slv_agent;   // AXI4 slave memory


// Clock and reset

logic clk_100MHz;
logic reset_rtl_0;

initial clk_100MHz = 0;
always #5 clk_100MHz = ~clk_100MHz;

initial begin
    reset_rtl_0 = 0;
    #160;
    reset_rtl_0 = 1;
end

// DUT
npu_bd_wrapper DUT(
    .clk_100MHz  (clk_100MHz),
    .reset_rtl_0 (reset_rtl_0)
);

// Shorthands
`define BD  DUT.npu_bd_i
`define VIP `BD.axi_vip_1    // AXI4 slave VIP - NPU master port connects here
`define NPU `BD.RVSDA_0


// Helper tasks

task automatic check(input string name, input logic condition);
    if (condition) begin
        $display("  PASS: %s", name);
        pass_cnt++;
    end else begin
        $display("  FAIL: %s", name);
        error_cnt++;
    end
endtask

// AXI-Lite write through master VIP
task axi_write(
    input [12:0] addr,
    input [31:0] data,
    input [3:0]  strb
);
    xil_axi_resp_t resp;
    mst_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
    if (resp != XIL_AXI_RESP_OKAY)
        $display("  WARNING: Write to 0x%03X non-OKAY response: %0d", addr, resp);
endtask

// AXI-Lite read through master VIP
task axi_read(
    input  [12:0] addr,
    output [31:0] data
);
    xil_axi_resp_t    resp;
    xil_axi_data_beat beat;
    mst_agent.AXI4LITE_READ_BURST(addr, 0, beat, resp);
    data = beat[31:0];
    if (resp != XIL_AXI_RESP_OKAY)
        $display("  WARNING: Read from 0x%03X non-OKAY response: %0d", addr, resp);
endtask

// Firmware loader
//   firmware_sim_base_operation_tests.hex must live in the simulation working directory.
//   AXI-Lite BRAM slave: word 0 = ctrl (0x000), word 1 = status (0x004), word 2 = ddr base
//   word 3 onwards = instruction memory (byte addr 0x00C)
localparam int FW_WORDS     = 2048;           // max instruction words
localparam int FW_BASE_ADDR ='h00C;       // byte addr of BRAM[0]

task automatic load_firmware(input string hex_file = "firmware_sim_base_operation_tests.hex");
    reg [31:0] fw [0:FW_WORDS-1];
    $display("\n--- Loading firmware: %s ---", hex_file);
    $readmemh(hex_file, fw);

    for (int i = 0; i < FW_WORDS; i++) begin
        if (^fw[i] === 1'bx) continue;
        axi_write(FW_BASE_ADDR + (i * 4), fw[i], 4'hF);
    end
    $display("  Firmware loaded into instruction BRAM.");
endtask

// Matrix Test Selector
typedef enum int {
    GRADIENT_TEST   = 0,
    SIGN_STRESS     = 1,
    IDENTITY_TEST   = 2,
    MAX_SAT_STRESS  = 3
} test_mode_e;

test_mode_e test_mode = GRADIENT_TEST;

// Constant Matrix Repository
// 1. Standard Linear Gradient Matrix
const byte MATRIX_GRADIENT [0:7][0:7] = '{
    '{8'd1,  8'd2,  8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8},
    '{8'd2,  8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8,  8'd9},
    '{8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8,  8'd9,  8'd10},
    '{8'd4,  8'd5,  8'd6,  8'd7,  8'd8,  8'd9,  8'd10, 8'd11},
    '{8'd5,  8'd6,  8'd7,  8'd8,  8'd9,  8'd10, 8'd11, 8'd12},
    '{8'd6,  8'd7,  8'd8,  8'd9,  8'd10, 8'd11, 8'd12, 8'd13},
    '{8'd7,  8'd8,  8'd9,  8'd10, 8'd11, 8'd12, 8'd13, 8'd14},
    '{8'd8,  8'd9,  8'd10, 8'd11, 8'd12, 8'd13, 8'd14, 8'd15}
};

// 2. Alternating Sign Matrix (+1 and -1)
const byte MATRIX_SIGN_STRESS [0:7][0:7] = '{
    '{ 8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1},
    '{-8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1},
    '{ 8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1},
    '{-8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1},
    '{ 8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1},
    '{-8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1},
    '{ 8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1},
    '{-8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1, -8'sd1,  8'sd1}
};

// 3. Identity Matrix (Pass-through diagonal 1s)
const byte MATRIX_IDENTITY [0:7][0:7] = '{
    '{8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1}
};

// 4. Maximum Int8 signed boundaries (+127 and -128)
const byte MATRIX_MAX_SAT [0:7][0:7] = '{
    '{ 8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128},
    '{-8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127},
    '{ 8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128},
    '{-8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127},
    '{ 8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128},
    '{-8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127},
    '{ 8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128},
    '{-8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127, -8'sd128,  8'sd127}
};

// 16x16 Tiled Test Matrices (Broken down into 8x8 sub-tiles)

// --- MATRIX A (Activations) ---
const byte MATRIX_16x16_A_T0 [0:7][0:7] = '{
    '{10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1},
    '{10'd2, 10'd2, 10'd2, 10'd2, 10'd2, 10'd2, 10'd2, 10'd2},
    '{10'd3, 10'd3, 10'd3, 10'd3, 10'd3, 10'd3, 10'd3, 10'd3},
    '{10'd4, 10'd4, 10'd4, 10'd4, 10'd4, 10'd4, 10'd4, 10'd4},
    '{10'd5, 10'd5, 10'd5, 10'd5, 10'd5, 10'd5, 10'd5, 10'd5},
    '{10'd6, 10'd6, 10'd6, 10'd6, 10'd6, 10'd6, 10'd6, 10'd6},
    '{10'd7, 10'd7, 10'd7, 10'd7, 10'd7, 10'd7, 10'd7, 10'd7},
    '{10'd8, 10'd8, 10'd8, 10'd8, 10'd8, 10'd8, 10'd8, 10'd8}
};
const byte MATRIX_16x16_A_T1 [0:7][0:7] = '{
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}
};
const byte MATRIX_16x16_A_T2 [0:7][0:7] = '{
    '{8'd9,  8'd9,  8'd9,  8'd9,  8'd9,  8'd9,  8'd9,  8'd9},
    '{8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10},
    '{8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11},
    '{8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12},
    '{8'd13, 8'd13, 8'd13, 8'd13, 8'd13, 8'd13, 8'd13, 8'd13},
    '{8'd14, 8'd14, 8'd14, 8'd14, 8'd14, 8'd14, 8'd14, 8'd14},
    '{8'd15, 8'd15, 8'd15, 8'd15, 8'd15, 8'd15, 8'd15, 8'd15},
    '{8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16}
};
const byte MATRIX_16x16_A_T3 [0:7][0:7] = '{
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1}
};

// --- MATRIX B (Weights) ---
const byte MATRIX_16x16_B_T0 [0:7][0:7] = '{
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1}
};
const byte MATRIX_16x16_B_T1 [0:7][0:7] = '{
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2},
    '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2}
};
const byte MATRIX_16x16_B_T2 [0:7][0:7] = '{
    '{8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd1}
 };
const byte MATRIX_16x16_B_T3 [0:7][0:7] = '{
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
    '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1}
};
const byte MATRIX_SIMPLE_A[0:7][0:7] = '{
    '{8'd2, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd1, 8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd4, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd1, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd3, 8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd1, 8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd2, 8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}
};

const byte MATRIX_SIMPLE_B[0:7][0:7] = '{
    '{8'd2, 8'd1, 8'd3, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd1, 8'd1, 8'd2, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}
};

const byte MATRIX_SIMPLE_C[0:7][0:7] = '{
    '{8'd1, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd4, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd2, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd4, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd5, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}
};

const byte MATRIX_SIMPLE_D[0:7][0:7] = '{
    '{8'd1, 8'd2, 8'd3, 8'd4, 8'd1, 8'd2, 8'd3, 8'd4},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0},
    '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0}
};

const byte MAT24x8_A0 [0:7][0:7] = '{
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd3,8'd3,8'd3,8'd3,8'd3,8'd3,8'd3,8'd3},
    '{8'd4,8'd4,8'd4,8'd4,8'd4,8'd4,8'd4,8'd4},
    '{8'd5,8'd5,8'd5,8'd5,8'd5,8'd5,8'd5,8'd5},
    '{8'd6,8'd6,8'd6,8'd6,8'd6,8'd6,8'd6,8'd6},
    '{8'd7,8'd7,8'd7,8'd7,8'd7,8'd7,8'd7,8'd7},
    '{8'd8,8'd8,8'd8,8'd8,8'd8,8'd8,8'd8,8'd8}
};

const byte MAT24x8_A1 [0:7][0:7] = '{
    '{8'd9,8'd9,8'd9,8'd9,8'd9,8'd9,8'd9,8'd9},
    '{8'd10,8'd10,8'd10,8'd10,8'd10,8'd10,8'd10,8'd10},
    '{8'd11,8'd11,8'd11,8'd11,8'd11,8'd11,8'd11,8'd11},
    '{8'd12,8'd12,8'd12,8'd12,8'd12,8'd12,8'd12,8'd12},
    '{8'd13,8'd13,8'd13,8'd13,8'd13,8'd13,8'd13,8'd13},
    '{8'd14,8'd14,8'd14,8'd14,8'd14,8'd14,8'd14,8'd14},
    '{8'd15,8'd15,8'd15,8'd15,8'd15,8'd15,8'd15,8'd15},
    '{8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16,8'd16}
    };

const byte MAT24x8_A2 [0:7][0:7] = '{
    '{8'd17,8'd17,8'd17,8'd17,8'd17,8'd17,8'd17,8'd17},
    '{8'd18,8'd18,8'd18,8'd18,8'd18,8'd18,8'd18,8'd18},
    '{8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19},
    '{8'd20,8'd20,8'd20,8'd20,8'd20,8'd20,8'd20,8'd20},
    '{8'd21,8'd21,8'd21,8'd21,8'd21,8'd21,8'd21,8'd21},
    '{8'd22,8'd22,8'd22,8'd22,8'd22,8'd22,8'd22,8'd22},
    '{8'd23,8'd23,8'd23,8'd23,8'd23,8'd23,8'd23,8'd23},
    '{8'd24,8'd24,8'd24,8'd24,8'd24,8'd24,8'd24,8'd24}
};

const byte MAT8x16_B0 [0:7][0:7] = '{
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1},
    '{8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1,8'd1}
};

const byte MAT8x16_B1 [0:7][0:7] = '{
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2},
    '{8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2,8'd2}
};

////////input feature map generator of 8x8
byte POOL_CH[0:7][0:7][0:7];

initial begin
    int pixel;

    for (int ch = 0; ch < 8; ch++) begin
        pixel = ch*64;

        for (int y = 0; y < 8; y++) begin
            for (int x = 0; x < 8; x++) begin
                POOL_CH[ch][y][x] = pixel;
                pixel++;
            end
        end
    end
end

//////////////////////////////////


// Matrix Preloader Task
task automatic preload_matrix();
    logic [63:0] row_grad, row_sign, row_ident, row_sat;
    logic [63:0] r16_a0, r16_a1, r16_a2, r16_a3;
    logic [63:0] r16_b0, r16_b1, r16_b2, r16_b3;
    logic [63:0] row_mat_a_basic, row_mat_b_basic, row_mat_c_basic, row_mat_d_basic;
    logic [63:0] row_mat24x8_a0, row_mat24x8_a1, row_mat24x8_a2;
    logic [63:0] row_mat8x16_b0, row_mat8x16_b1;
    logic [63:0] row_pool[8];
    logic [63:0] pixel_word;
    $display("\n--- Preloading ALL Scenario Matrices into VIP Memory Layout ---");
    
    for (int row = 0; row < 8; row++) begin
        // Pack all row variations (Little-Endian)
        row_grad  = { MATRIX_GRADIENT[row][7],    MATRIX_GRADIENT[row][6],    MATRIX_GRADIENT[row][5],    MATRIX_GRADIENT[row][4],
                      MATRIX_GRADIENT[row][3],    MATRIX_GRADIENT[row][2],    MATRIX_GRADIENT[row][1],    MATRIX_GRADIENT[row][0] };
                      
        row_sign  = { MATRIX_SIGN_STRESS[row][7],  MATRIX_SIGN_STRESS[row][6],  MATRIX_SIGN_STRESS[row][5],  MATRIX_SIGN_STRESS[row][4],
                      MATRIX_SIGN_STRESS[row][3],  MATRIX_SIGN_STRESS[row][2],  MATRIX_SIGN_STRESS[row][1],  MATRIX_SIGN_STRESS[row][0] };
                      
        row_ident = { MATRIX_IDENTITY[row][7],     MATRIX_IDENTITY[row][6],     MATRIX_IDENTITY[row][5],     MATRIX_IDENTITY[row][4],
                      MATRIX_IDENTITY[row][3],     MATRIX_IDENTITY[row][2],     MATRIX_IDENTITY[row][1],     MATRIX_IDENTITY[row][0] };
                      
        row_sat   = { MATRIX_MAX_SAT[row][7],      MATRIX_MAX_SAT[row][6],      MATRIX_MAX_SAT[row][5],      MATRIX_MAX_SAT[row][4],
                      MATRIX_MAX_SAT[row][3],      MATRIX_MAX_SAT[row][2],      MATRIX_MAX_SAT[row][1],     MATRIX_MAX_SAT[row][0] };
        //16x16 matrix
        r16_a0 = { MATRIX_16x16_A_T0[row][7], MATRIX_16x16_A_T0[row][6], MATRIX_16x16_A_T0[row][5], MATRIX_16x16_A_T0[row][4],
                   MATRIX_16x16_A_T0[row][3], MATRIX_16x16_A_T0[row][2], MATRIX_16x16_A_T0[row][1], MATRIX_16x16_A_T0[row][0] };
        r16_a1 = { MATRIX_16x16_A_T1[row][7], MATRIX_16x16_A_T1[row][6], MATRIX_16x16_A_T1[row][5], MATRIX_16x16_A_T1[row][4],
                   MATRIX_16x16_A_T1[row][3], MATRIX_16x16_A_T1[row][2], MATRIX_16x16_A_T1[row][1], MATRIX_16x16_A_T1[row][0] };
        r16_a2 = { MATRIX_16x16_A_T2[row][7], MATRIX_16x16_A_T2[row][6], MATRIX_16x16_A_T2[row][5], MATRIX_16x16_A_T2[row][4],
                   MATRIX_16x16_A_T2[row][3], MATRIX_16x16_A_T2[row][2], MATRIX_16x16_A_T2[row][1], MATRIX_16x16_A_T2[row][0] };
        r16_a3 = { MATRIX_16x16_A_T3[row][7], MATRIX_16x16_A_T3[row][6], MATRIX_16x16_A_T3[row][5], MATRIX_16x16_A_T3[row][4],
                   MATRIX_16x16_A_T3[row][3], MATRIX_16x16_A_T3[row][2], MATRIX_16x16_A_T3[row][1], MATRIX_16x16_A_T3[row][0] };

        // Pack Rows for B Tiles
        r16_b0 = { MATRIX_16x16_B_T0[row][7], MATRIX_16x16_B_T0[row][6], MATRIX_16x16_B_T0[row][5], MATRIX_16x16_B_T0[row][4],
                   MATRIX_16x16_B_T0[row][3], MATRIX_16x16_B_T0[row][2], MATRIX_16x16_B_T0[row][1], MATRIX_16x16_B_T0[row][0] };
        r16_b1 = { MATRIX_16x16_B_T1[row][7], MATRIX_16x16_B_T1[row][6], MATRIX_16x16_B_T1[row][5], MATRIX_16x16_B_T1[row][4],
                   MATRIX_16x16_B_T1[row][3], MATRIX_16x16_B_T1[row][2], MATRIX_16x16_B_T1[row][1], MATRIX_16x16_B_T1[row][0] };
        r16_b2 = { MATRIX_16x16_B_T2[row][7], MATRIX_16x16_B_T2[row][6], MATRIX_16x16_B_T2[row][5], MATRIX_16x16_B_T2[row][4],
                   MATRIX_16x16_B_T2[row][3], MATRIX_16x16_B_T2[row][2], MATRIX_16x16_B_T2[row][1], MATRIX_16x16_B_T2[row][0] };
        r16_b3 = { MATRIX_16x16_B_T3[row][7], MATRIX_16x16_B_T3[row][6], MATRIX_16x16_B_T3[row][5], MATRIX_16x16_B_T3[row][4],
                   MATRIX_16x16_B_T3[row][3], MATRIX_16x16_B_T3[row][2], MATRIX_16x16_B_T3[row][1], MATRIX_16x16_B_T3[row][0] };
        
        
        row_mat_a_basic={MATRIX_SIMPLE_A[row][7],    MATRIX_SIMPLE_A[row][6],    MATRIX_SIMPLE_A[row][5],    MATRIX_SIMPLE_A[row][4],
            MATRIX_SIMPLE_A[row][3],    MATRIX_SIMPLE_A[row][2],    MATRIX_SIMPLE_A[row][1],    MATRIX_SIMPLE_A[row][0] };
        row_mat_b_basic={MATRIX_SIMPLE_B[row][7],    MATRIX_SIMPLE_B[row][6],    MATRIX_SIMPLE_B[row][5],    MATRIX_SIMPLE_B[row][4],
            MATRIX_SIMPLE_B[row][3],    MATRIX_SIMPLE_B[row][2],    MATRIX_SIMPLE_B[row][1],    MATRIX_SIMPLE_B[row][0] };
        row_mat_c_basic={MATRIX_SIMPLE_C[row][7],    MATRIX_SIMPLE_C[row][6],    MATRIX_SIMPLE_C[row][5],    MATRIX_SIMPLE_C[row][4],
            MATRIX_SIMPLE_C[row][3],    MATRIX_SIMPLE_C[row][2],    MATRIX_SIMPLE_C[row][1],    MATRIX_SIMPLE_C[row][0] };
        row_mat_d_basic={MATRIX_SIMPLE_D[row][7],    MATRIX_SIMPLE_D[row][6],    MATRIX_SIMPLE_D[row][5],    MATRIX_SIMPLE_D[row][4],
            MATRIX_SIMPLE_D[row][3],    MATRIX_SIMPLE_D[row][2],    MATRIX_SIMPLE_D[row][1],    MATRIX_SIMPLE_D[row][0] };


        row_mat24x8_a0 = { MAT24x8_A0[row][7], MAT24x8_A0[row][6], MAT24x8_A0[row][5], MAT24x8_A0[row][4],
                   MAT24x8_A0[row][3], MAT24x8_A0[row][2], MAT24x8_A0[row][1], MAT24x8_A0[row][0] };
        row_mat24x8_a1 = { MAT24x8_A1[row][7], MAT24x8_A1[row][6], MAT24x8_A1[row][5], MAT24x8_A1[row][4],
                           MAT24x8_A1[row][3], MAT24x8_A1[row][2], MAT24x8_A1[row][1], MAT24x8_A1[row][0] };
        row_mat24x8_a2 = { MAT24x8_A2[row][7], MAT24x8_A2[row][6], MAT24x8_A2[row][5], MAT24x8_A2[row][4],
                           MAT24x8_A2[row][3], MAT24x8_A2[row][2], MAT24x8_A2[row][1], MAT24x8_A2[row][0] };
        
        row_mat8x16_b0 = { MAT8x16_B0[row][7], MAT8x16_B0[row][6], MAT8x16_B0[row][5], MAT8x16_B0[row][4],
                           MAT8x16_B0[row][3], MAT8x16_B0[row][2], MAT8x16_B0[row][1], MAT8x16_B0[row][0] };
        row_mat8x16_b1 = { MAT8x16_B1[row][7], MAT8x16_B1[row][6], MAT8x16_B1[row][5], MAT8x16_B1[row][4],
                           MAT8x16_B1[row][3], MAT8x16_B1[row][2], MAT8x16_B1[row][1], MAT8x16_B1[row][0] };
        
        

        
        // AXI Memory Map Layout 
        // Scenario 0: GRADIENT (A=Gradient, B=Gradient)
        slv_agent.mem_model.backdoor_memory_write('h000 + (row * 8), row_grad);  // Mat A
        slv_agent.mem_model.backdoor_memory_write('h040 + (row * 8), row_grad);  // Mat B
        
        // Scenario 1: SIGN STRESS (A=Sign, B=Sign)
        slv_agent.mem_model.backdoor_memory_write('h080 + (row * 8), row_sign);  // Mat A
        slv_agent.mem_model.backdoor_memory_write('h0C0 + (row * 8), row_sign);  // Mat B
        
        // Scenario 2: IDENTITY TEST (A=Gradient, B=Identity)
        slv_agent.mem_model.backdoor_memory_write('h100 + (row * 8), row_grad);  // Mat A
        slv_agent.mem_model.backdoor_memory_write('h140 + (row * 8), row_ident); // Mat B
        
        // Scenario 3: MAX SATURATION (A=Sat, B=Sat)
        slv_agent.mem_model.backdoor_memory_write('h180 + (row * 8), row_sat);   // Mat A
        slv_agent.mem_model.backdoor_memory_write('h1C0 + (row * 8), row_sat);   // Mat B
    
        //SCenario 4: 16x16 matrix tiling
        slv_agent.mem_model.backdoor_memory_write('h300 + (row * 8), r16_a0);
        slv_agent.mem_model.backdoor_memory_write('h340 + (row * 8), r16_a1);
        slv_agent.mem_model.backdoor_memory_write('h380 + (row * 8), r16_a2);
        slv_agent.mem_model.backdoor_memory_write('h3C0 + (row * 8), r16_a3);

        slv_agent.mem_model.backdoor_memory_write('h400 + (row * 8), r16_b0);
        slv_agent.mem_model.backdoor_memory_write('h440 + (row * 8), r16_b1);
        slv_agent.mem_model.backdoor_memory_write('h480 + (row * 8), r16_b2);
        slv_agent.mem_model.backdoor_memory_write('h4C0 + (row * 8), r16_b3);
        
        //Scenario 5: basic mat mul
        slv_agent.mem_model.backdoor_memory_write('h600 + (row * 8), row_mat_a_basic);
        slv_agent.mem_model.backdoor_memory_write('h640 + (row * 8), row_mat_b_basic);
        slv_agent.mem_model.backdoor_memory_write('h680 + (row * 8), row_mat_c_basic);
        slv_agent.mem_model.backdoor_memory_write('h6C0 + (row * 8), row_mat_d_basic);
        
        // 24x24 activation tiles
        slv_agent.mem_model.backdoor_memory_write('h800 + row*8, r16_a0);
        slv_agent.mem_model.backdoor_memory_write('h840 + row*8, r16_a1);
        slv_agent.mem_model.backdoor_memory_write('h880 + row*8, r16_a2);
        slv_agent.mem_model.backdoor_memory_write('h8C0 + row*8, r16_a3);
        slv_agent.mem_model.backdoor_memory_write('h900 + row*8, r16_a0);
        slv_agent.mem_model.backdoor_memory_write('h940 + row*8, r16_a1);
        slv_agent.mem_model.backdoor_memory_write('h980 + row*8, r16_a2);
        slv_agent.mem_model.backdoor_memory_write('h9C0 + row*8, r16_a3);
        slv_agent.mem_model.backdoor_memory_write('hA00 + row*8, r16_a0);
        
        // 24x24 weight tiles
        slv_agent.mem_model.backdoor_memory_write('hA40 + row*8, r16_b0);
        slv_agent.mem_model.backdoor_memory_write('hA80 + row*8, r16_b1);
        slv_agent.mem_model.backdoor_memory_write('hAC0 + row*8, r16_b2);
        slv_agent.mem_model.backdoor_memory_write('hB00 + row*8, r16_b3);
        slv_agent.mem_model.backdoor_memory_write('hB40 + row*8, r16_b0);
        slv_agent.mem_model.backdoor_memory_write('hB80 + row*8, r16_b1);
        slv_agent.mem_model.backdoor_memory_write('hBC0 + row*8, r16_b2);
        slv_agent.mem_model.backdoor_memory_write('hC00 + row*8, r16_b3);
        slv_agent.mem_model.backdoor_memory_write('hC40 + row*8, r16_b0);
        
        // 24x8 activation matrix (3 tiles of 8x8)  
        slv_agent.mem_model.backdoor_memory_write('hEC0 + (row * 8), row_mat24x8_a0);  // Tile 0
        slv_agent.mem_model.backdoor_memory_write('hF00 + (row * 8), row_mat24x8_a1);  // Tile 1
        slv_agent.mem_model.backdoor_memory_write('hF40 + (row * 8), row_mat24x8_a2);  // Tile 2
        
        // 8x16 weight matrix (2 tiles of 8x8)
        slv_agent.mem_model.backdoor_memory_write('hF80 + (row * 8), row_mat8x16_b0);  // Tile 0
        slv_agent.mem_model.backdoor_memory_write('hFC0 + (row * 8), row_mat8x16_b1);  // Tile 1
        
        //pooling test
        for (int x = 0; x < 8; x++) begin
        
            pixel_word = {
                POOL_CH[7][row][x],
                POOL_CH[6][row][x],
                POOL_CH[5][row][x],
                POOL_CH[4][row][x],
                POOL_CH[3][row][x],
                POOL_CH[2][row][x],
                POOL_CH[1][row][x],
                POOL_CH[0][row][x]
            };
        
            slv_agent.mem_model.backdoor_memory_write(
                'h1180 + ((row*8 + x) * 8),
                pixel_word
            );
        end
//        slv_agent.mem_model.backdoor_memory_write('h1400 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h1440 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h1480 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h14C0 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h1500 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h1540 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h1580 + (row * 8), row_ident); // Mat B
//        slv_agent.mem_model.backdoor_memory_write('h15C0 + (row * 8), row_ident); // Mat B

        
    end
    
    $display("  All test scenarios loaded");
endtask

// NPU control
//   Ctrl register at byte offset 0x000:
//     bit 0 = reset (active-low)
//     bit 1 = start / enable NPU execution
task automatic start_npu();
    logic [31:0] rd;
    $display("\n--- Starting NPU (CTRL[0] asserted) ---");
    axi_write(11'h08, 32'h0000_0000, 4'hF);
    axi_write(11'h000, 32'h0000_0003, 4'hF);
    // Read back to confirm
//    axi_read(11'h000, rd);
//    check("CTRL register reflects start bit", rd[0] == 1'b1);
//    $display("  NPU start command issued.");
endtask

// Global AXI4 bus monitor
//   Watches the NPU master ↔ slave VIP channel for all traffic
integer ar_count  = 0;   // accepted AR transactions
integer aw_count  = 0;   // accepted AW transactions
integer r_beats   = 0;   // accepted R beats
integer w_beats   = 0;   // accepted W beats
integer b_resps   = 0;   // accepted B responses

logic [31:0] ar_addr_log [0:31];
logic [7:0]  ar_len_log  [0:31];
logic [31:0] aw_addr_log [0:31];
logic [7:0]  aw_len_log  [0:31];
integer      ar_log_idx  = 0;
integer      aw_log_idx  = 0;

always @(posedge clk_100MHz) begin
    if (!reset_rtl_0) begin
        ar_count   <= 0;  aw_count  <= 0;
        r_beats    <= 0;  w_beats   <= 0;
        b_resps    <= 0;
        ar_log_idx <= 0;  aw_log_idx <= 0;
    end else begin

        // --- Read address channel ---
        if (`NPU.M_AXI_ARVALID && `NPU.M_AXI_ARREADY) begin
            ar_addr_log[ar_log_idx] <= `NPU.M_AXI_ARADDR;
            ar_len_log [ar_log_idx] <= `NPU.M_AXI_ARLEN;
            ar_log_idx <= ar_log_idx + 1;
            ar_count   <= ar_count   + 1;
            $display("  [AR #%0d]  addr=%08h  len=%0d  @ %0t",
                ar_count, `NPU.M_AXI_ARADDR, `NPU.M_AXI_ARLEN, $time);
        end

        // --- Read data channel ---
        if (`NPU.M_AXI_RVALID && `NPU.M_AXI_RREADY) begin
            r_beats <= r_beats + 1;
            if (`NPU.M_AXI_RLAST)
                $display("  [RLAST]  burst complete  r_beats=%0d  @ %0t",
                    r_beats + 1, $time);
        end

        // --- Write address channel ---
        if (`NPU.M_AXI_AWVALID && `NPU.M_AXI_AWREADY) begin
            aw_addr_log[aw_log_idx] <= `NPU.M_AXI_AWADDR;
            aw_len_log [aw_log_idx] <= `NPU.M_AXI_AWLEN;
            aw_log_idx <= aw_log_idx + 1;
            aw_count   <= aw_count   + 1;
            $display("  [AW #%0d]  addr=%08h  len=%0d  @ %0t",
                aw_count, `NPU.M_AXI_AWADDR, `NPU.M_AXI_AWLEN, $time);
        end

        // --- Write data channel ---
        if (`NPU.M_AXI_WVALID && `NPU.M_AXI_WREADY) begin
            w_beats <= w_beats + 1;
            if (`NPU.M_AXI_WLAST)
                $display("  [WLAST]  burst complete  w_beats=%0d  @ %0t",
                    w_beats + 1, $time);
        end

        // --- Write response channel ---
        if (`NPU.M_AXI_BVALID && `NPU.M_AXI_BREADY) begin
            b_resps <= b_resps + 1;
            $display("  [BRESP]  resp=%0b  b_resps=%0d  @ %0t",
                `NPU.M_AXI_BRESP, b_resps + 1, $time);
        end
    end
end

 
// Wait until the AXI4 bus goes quiet for N consecutive cycles
 
task automatic wait_for_quiet(input int quiet_threshold = 200,
                               input int hard_timeout    = 500_000);
    int quiet_cycles = 0;
    int prev_r = 0, prev_w = 0;
    bit is_quiet = 0;

    for (int i = 0; i < hard_timeout; i++) begin
        @(posedge clk_100MHz);
        if (r_beats == prev_r && w_beats == prev_w) begin
            quiet_cycles++;
            if (quiet_cycles >= quiet_threshold) begin
                is_quiet = 1;
                break; 
            end
        end else begin
            quiet_cycles = 0;
            prev_r = r_beats;
            prev_w = w_beats;
        end
    end

    if (is_quiet) begin
        $display("  [QUIET]  bus idle for %0d cycles at t=%0t", quiet_threshold, $time);
    end else begin
        $display("  [TIMEOUT]  wait_for_quiet expired after %0d cycles", hard_timeout);
        error_cnt++;
    end
endtask

 
// Summary of observed AXI4 traffic
 
task automatic print_traffic_summary();
    $display("\n--- AXI4 Traffic Summary ---");
    $display("  Read  address transactions : %0d", ar_count);
    $display("  Read  data beats           : %0d", r_beats);
    $display("  Write address transactions : %0d", aw_count);
    $display("  Write data beats           : %0d", w_beats);
    $display("  Write responses            : %0d", b_resps);

    // Sanity checks
    check("AW/B counts match (no lost responses)", aw_count == b_resps);
    check("At least one read  issued by NPU",       ar_count  > 0);
    check("At least one write issued by NPU",       aw_count  > 0);
endtask


 
// Software Reference Model & Result Validator
 
task automatic check_matrix_result(
    input string test_name,
    input int    axi_base_addr,
    input byte   matA[0:7][0:7],
    input byte   matB[0:7][0:7],
    input logic  use_relu
);
    int acc;
    byte expected_val;
    byte actual_val;
    logic [63:0] read_row;
    int local_errors = 0;

    $display("\n--- Verifying %s at AXI addr 0x%03X ---", test_name, axi_base_addr);

    for (int row = 0; row < 8; row++) begin
        // Read the resulting 64-bit row written back by the NPU
        read_row = slv_agent.mem_model.backdoor_memory_read(axi_base_addr + (row * 8));
        $display("ROW[%0d] = %016h", row, read_row);        
        for (int col = 0; col < 8; col++) begin
            // 1. Matrix Multiplication (Accumulation)
            acc = 0;
            for (int k = 0; k < 8; k++) begin
                acc += signed'(matA[row][k]) * signed'(matB[k][col]);
            end
            
            // 2. Quantization (shift amount is 0 in your C code)
            // acc = acc >>> 0; 
            
            // 3. Clamping (to Int8 limits)
            if (acc > 127)       acc = 127;
            else if (acc < -128) acc = -128;

            // 4. ReLU Activation
            if (use_relu && acc < 0) acc = 0;

            expected_val = byte'(acc);

            
           actual_val = read_row[col*8 +: 8];
           //actual_val = read_row[(7 - col)*8 +: 8];
            if (actual_val !== expected_val) begin
                $display("    [MISMATCH] Row %0d, Col %0d: Expected %0d, Got %0d", 
                         row, col, signed'(expected_val), signed'(actual_val));
                local_errors++;
            end
        end
    end
    
    check(test_name, local_errors == 0);
endtask
typedef byte tile_t[8][8];
tile_t A_tiles[16];
tile_t B_tiles[16];
task automatic check_tiled_matrix_result(
    input string test_name,
    input int output_base_addr,

    input int M_tiles,   // output rows in tiles
    input int K_tiles,   // reduction dimension in tiles
    input int N_tiles,   // output cols in tiles

    input tile_t A_tiles[16],
    input tile_t B_tiles[16]
);

    int local_errors;
    int acc;

    logic [63:0] read_row;

    byte expected_val;
    byte actual_val;

    int output_tile_addr;

    local_errors = 0;

    // Iterate over output tiles
    for (int m = 0; m < M_tiles; m++) begin

        for (int n = 0; n < N_tiles; n++) begin

            output_tile_addr =
                output_base_addr +
                ((m * N_tiles + n) * 64);

            for (int row = 0; row < 8; row++) begin

                read_row =
                    slv_agent.mem_model.backdoor_memory_read(
                        output_tile_addr + row * 8
                    );

                for (int col = 0; col < 8; col++) begin

                    acc = 0;

                    // Tile reduction
                    for (int k_tile = 0;
                             k_tile < K_tiles;
                             k_tile++) begin

                        int a_idx;
                        int b_idx;

                        a_idx = m * K_tiles + k_tile;
                        b_idx = k_tile * N_tiles + n;

                        for (int k = 0; k < 8; k++) begin

                            acc +=
                                signed'(A_tiles[a_idx][row][k]) *
                                signed'(B_tiles[b_idx][k][col]);

                        end
                    end

                    // Saturation
                    if (acc > 127)
                        acc = 127;
                    else if (acc < -128)
                        acc = -128;

                    // ReLU
                    if (acc < 0)
                        acc = 0;

                    expected_val = byte'(acc);
                    actual_val   = read_row[col*8 +: 8];

                    if (actual_val !== expected_val) begin

                        $display(
                            "[MISMATCH] Tile[%0d,%0d] Row=%0d Col=%0d Exp=%0d Got=%0d",
                            m,
                            n,
                            row,
                            col,
                            signed'(expected_val),
                            signed'(actual_val)
                        );

                        local_errors++;

                    end
                end
            end
        end
    end

    check(test_name, local_errors == 0);

endtask
task automatic check_parallel_max_pooling(
    input string test_name,
    input int    axi_base_addr,
    input byte   src[0:7][0:7][0:7]
);
    byte expected[8];
    byte actual[8];
    logic [63:0] read_word;
    int local_errors = 0;
    int word_idx = 0;

    for (int pool_row = 0; pool_row < 4; pool_row++) begin
        for (int pool_col = 0; pool_col < 4; pool_col++) begin
            read_word = slv_agent.mem_model.backdoor_memory_read(axi_base_addr + (word_idx * 8));
            $display("ADDR=%h DATA=%016h",
         axi_base_addr + (word_idx-1)*8,
         read_word);
            word_idx++;
            
            // Compute expected for each of 8 channels
            for (int ch = 0; ch < 8; ch++) begin

                byte m0, m1, m2, m3;
            
                m0 = src[ch][pool_row*2+0][pool_col*2+0];
                m1 = src[ch][pool_row*2+0][pool_col*2+1];
                m2 = src[ch][pool_row*2+1][pool_col*2+0];
                m3 = src[ch][pool_row*2+1][pool_col*2+1];
            
                expected[ch] = m0;
                if (m1 > expected[ch]) expected[ch] = m1;
                if (m2 > expected[ch]) expected[ch] = m2;
                if (m3 > expected[ch]) expected[ch] = m3;
            end

            // Extract actual from read_word (little-endian: ch0 in bits 7:0)
            for (int ch = 0; ch < 8; ch++)
                actual[ch] = read_word[ch*8 +: 8];

            // Compare
            for (int ch = 0; ch < 8; ch++) begin
                if (actual[ch] !== expected[ch]) begin
                    $display("MISMATCH at (%0d,%0d) Ch%0d: exp=%0d act=%0d",
                             pool_row, pool_col, ch, expected[ch], actual[ch]);
                    local_errors++;
                end
            end
        end
    end
    check(test_name, local_errors == 0);
endtask
// Main

initial begin
    // Create master VIP (AXI-Lite, used for firmware/ctrl)
    mst_agent = new("axilite master agent",
        `BD.axi_vip_0.inst.IF);
    mst_agent.start_master();
//mst_agent.set_forward_progress_timeout(0);
    // Create slave VIP (AXI4, used as NPU data memory)
    slv_agent = new("axi4 slave agent",
        `BD.axi_vip_1.inst.IF);
    slv_agent.start_slave();

    @(posedge reset_rtl_0);
    repeat(5) @(posedge clk_100MHz);


    preload_matrix();

    load_firmware("firmware_sim_base_operation_tests.hex");


    start_npu();


    $display("\n--- Monitoring NPU AXI4 activity ---");
    wait (r_beats > 0 || w_beats > 0);
    wait_for_quiet(.quiet_threshold(10000), .hard_timeout(500_000));


    print_traffic_summary();
    A_tiles[0] = MATRIX_16x16_A_T0;
    A_tiles[1] = MATRIX_16x16_A_T1;
    A_tiles[2] = MATRIX_16x16_A_T2;
    A_tiles[3] = MATRIX_16x16_A_T3;
    A_tiles[4] = MATRIX_16x16_A_T0;
    A_tiles[5] = MATRIX_16x16_A_T1;
    A_tiles[6] = MATRIX_16x16_A_T2;
    A_tiles[7] = MATRIX_16x16_A_T3;
    A_tiles[8] = MATRIX_16x16_A_T0;

    B_tiles[0] = MATRIX_16x16_B_T0;
    B_tiles[1] = MATRIX_16x16_B_T1;
    B_tiles[2] = MATRIX_16x16_B_T2;
    B_tiles[3] = MATRIX_16x16_B_T3;
    B_tiles[4] = MATRIX_16x16_B_T0;
    B_tiles[5] = MATRIX_16x16_B_T1;
    B_tiles[6] = MATRIX_16x16_B_T2;
    B_tiles[7] = MATRIX_16x16_B_T3;
    B_tiles[8] = MATRIX_16x16_B_T0;
    check_matrix_result("Gradient Test",  'h200, MATRIX_GRADIENT,    MATRIX_GRADIENT,    1);
    check_matrix_result("Sign Stress",    'h240, MATRIX_SIGN_STRESS, MATRIX_SIGN_STRESS, 1);
    check_matrix_result("Identity Test",  'h280, MATRIX_GRADIENT,    MATRIX_IDENTITY,    1);
    check_matrix_result("Max Saturation", 'h2C0, MATRIX_MAX_SAT,     MATRIX_MAX_SAT,     1);
    check_tiled_matrix_result(
        .test_name("Tiled 16x16 Execution Check"),
        .output_base_addr('h500),
          .M_tiles(2),
        .K_tiles(2),
        .N_tiles(2), .A_tiles(A_tiles), .B_tiles(B_tiles)
    );
//     check_tiled_matrix_result(
//     .test_name("24x24 tiled"),
//     .output_base_addr('hC80),
//     .M_tiles(3),
//     .K_tiles(3),
//     .N_tiles(3),
//     .A_tiles(A_tiles),
//     .B_tiles(B_tiles)
// );
   
  
    check_matrix_result("Normal Operation Test 1",  'h700, MATRIX_SIMPLE_A,    MATRIX_SIMPLE_B,    1);
    check_matrix_result("Normal Operation Test 2",  'h740, MATRIX_SIMPLE_C,    MATRIX_SIMPLE_D,    1);  
//     A_tiles[0] = MAT24x8_A0;
//     A_tiles[1] = MAT24x8_A1;
//     A_tiles[2] = MAT24x8_A2;
    
//     B_tiles[0] = MAT8x16_B0;
//     B_tiles[1] = MAT8x16_B1;
    
    
//     check_tiled_matrix_result(
//     .test_name("24x8 x 8x16"),
//     .output_base_addr('h1000),

//     .M_tiles(3),
//     .K_tiles(1),
//     .N_tiles(2),

//     .A_tiles(A_tiles),
//     .B_tiles(B_tiles)
// );

//     check_parallel_max_pooling(
//     "All-Channel Max Pooling Verification",
//     'h1380,
//     POOL_CH
// );            
           

            
//    check_parallel_max_pooling(
//    "Tiled matrix mult, All-Channel Max Pooling Verification",
//    'h1600,
//    POOL_CH
//);    
    repeat(10) @(posedge clk_100MHz);
    $display("\n=============================");
    $display("PASSED : %0d", pass_cnt);
    $display("FAILED : %0d", error_cnt);
    $display("=============================\n");

    $finish;
end

endmodule