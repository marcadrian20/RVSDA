#!/usr/bin/env python
# coding: utf-8

# In[1]:


from pynq import Overlay, allocate
import numpy as np
import time


ol = Overlay("RVSDA.bit")
rvsda = ol.RVSDA_0 

# 1. Standard Linear Gradient Matrix
MATRIX_GRADIENT = np.array([
    [1, 2, 3, 4, 5, 6, 7, 8],
    [2, 3, 4, 5, 6, 7, 8, 9],
    [3, 4, 5, 6, 7, 8, 9, 10],
    [4, 5, 6, 7, 8, 9, 10, 11],
    [5, 6, 7, 8, 9, 10, 11, 12],
    [6, 7, 8, 9, 10, 11, 12, 13],
    [7, 8, 9, 10, 11, 12, 13, 14],
    [8, 9, 10, 11, 12, 13, 14, 15]
], dtype=np.uint8)

# 2. Alternating Sign Matrix (+1 and -1)
MATRIX_SIGN_STRESS = np.array([
    [ 1, -1,  1, -1,  1, -1,  1, -1],
    [-1,  1, -1,  1, -1,  1, -1,  1],
    [ 1, -1,  1, -1,  1, -1,  1, -1],
    [-1,  1, -1,  1, -1,  1, -1,  1],
    [ 1, -1,  1, -1,  1, -1,  1, -1],
    [-1,  1, -1,  1, -1,  1, -1,  1],
    [ 1, -1,  1, -1,  1, -1,  1, -1],
    [-1,  1, -1,  1, -1,  1, -1,  1]
], dtype=np.int8)

# 3. Identity Matrix
MATRIX_IDENTITY = np.eye(8, dtype=np.uint8)

# 4. Maximum Int8 signed boundaries (+127 and -128)
MATRIX_MAX_SAT = np.array([
    [ 127, -128,  127, -128,  127, -128,  127, -128],
    [-128,  127, -128,  127, -128,  127, -128,  127],
    [ 127, -128,  127, -128,  127, -128,  127, -128],
    [-128,  127, -128,  127, -128,  127, -128,  127],
    [ 127, -128,  127, -128,  127, -128,  127, -128],
    [-128,  127, -128,  127, -128,  127, -128,  127],
    [ 127, -128,  127, -128,  127, -128,  127, -128],
    [-128,  127, -128,  127, -128,  127, -128,  127]
], dtype=np.int8)

 
# 16x16 Tiled Test Matrices (Broken down into 8x8 sub-tiles)
 

# --- MATRIX A (Activations) ---
MATRIX_16x16_A_T0 = np.ones((8, 8), dtype=np.uint8) * np.array([[1], [2], [3], [4], [5], [6], [7], [8]], dtype=np.uint8)
MATRIX_16x16_A_T1 = np.zeros((8, 8), dtype=np.uint8)
MATRIX_16x16_A_T2 = np.ones((8, 8), dtype=np.uint8) * np.array([[9], [10], [11], [12], [13], [14], [15], [16]], dtype=np.uint8)
MATRIX_16x16_A_T3 = np.ones((8, 8), dtype=np.uint8)

# --- MATRIX B (Weights) ---
MATRIX_16x16_B_T0 = np.ones((8, 8), dtype=np.uint8)
MATRIX_16x16_B_T1 = np.full((8, 8), 2, dtype=np.uint8)
MATRIX_16x16_B_T2 = np.eye(8, dtype=np.uint8)
MATRIX_16x16_B_T3 = np.ones((8, 8), dtype=np.uint8)

 
# Pooling Matrices
 

MATRIX_POOL_A = np.array([
    [2, 1, 0, 0, 0, 0, 0, 0],
    [1, 3, 0, 0, 0, 0, 0, 0],
    [4, 0, 0, 0, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0, 0],
    [3, 2, 0, 0, 0, 0, 0, 0],
    [1, 2, 0, 0, 0, 0, 0, 0],
    [0, 2, 0, 0, 0, 0, 0, 0],
    [2, 2, 0, 0, 0, 0, 0, 0]
], dtype=np.uint8)

MATRIX_POOL_B = np.array([
    [2, 1, 3, 1, 0, 0, 0, 0],
    [0, 1, 1, 2, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0]
], dtype=np.uint8)

MATRIX_POOL_C = np.array([
    [1, 0, 0, 0, 0, 0, 0, 0],
    [2, 0, 0, 0, 0, 0, 0, 0],
    [3, 0, 0, 0, 0, 0, 0, 0],
    [4, 0, 0, 0, 0, 0, 0, 0],
    [2, 0, 0, 0, 0, 0, 0, 0],
    [3, 0, 0, 0, 0, 0, 0, 0],
    [4, 0, 0, 0, 0, 0, 0, 0],
    [5, 0, 0, 0, 0, 0, 0, 0]
], dtype=np.uint8)

MATRIX_POOL_D = np.array([
    [1, 2, 3, 4, 1, 2, 3, 4],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0]
], dtype=np.uint8)

def pack_to_axi_64bit(matrix, reverse_endianness=False):
    """
    Packs an 8x8 uint8 or int8 matrix into an array of eight 64-bit integers,
    representing exactly 8 clock cycles of AXI master reads.
    """
    # Ensure the matrix is a contiguous block in memory
    mat_contiguous = np.ascontiguousarray(matrix)
    
    # Optional: Swap endianness if the RTL expects column 0 at the MSB
    if reverse_endianness:
        mat_contiguous = np.fliplr(mat_contiguous).copy()
        
    # Reinterpret the 64 bytes as 64-bit words, then flatten from (8, 1) to (8,)
    return mat_contiguous.view(np.uint64).flatten()

def compute_reference_matmul(matA, matB, use_relu=True):
    """Computes exact INT32/INT8 GEMM with optional ReLU for golden checks."""
    # Cast up to int32 to prevent overflow during accumulation
    a_32 = matA.astype(np.int32)
    b_32 = matB.astype(np.int32)
    
    res = np.matmul(a_32, b_32)
    if use_relu:
        res = np.clip(res, 0, 127) # Quantized ReLU bounding
    else:
        res = np.clip(res, -128, 127)
        
    return res.astype(np.int8)

def unpack_from_axi_64bit(uint64_array, target_dtype=np.int8):
    """Converts eight 64-bit words back into an 8x8 matrix for verification."""
    return uint64_array.view(target_dtype).reshape((8, 8))

def preload_all_scenario_matrices(buffer):
    """Replicates preload_matrix() task directly into the shared DDR memory map."""
    print("--- Preloading ALL Scenario Matrices into Buffer Memory Layout ---")
    
    # Pack input sets to 64-bit arrays using our utility
    pack_grad = pack_to_axi_64bit(MATRIX_GRADIENT)
    pack_sign = pack_to_axi_64bit(MATRIX_SIGN_STRESS)
    pack_ident = pack_to_axi_64bit(MATRIX_IDENTITY)
    pack_sat  = pack_to_axi_64bit(MATRIX_MAX_SAT)
    
    # Scenario 0: GRADIENT (A=0x000, B=0x040)
    np.copyto(buffer[0x000//8 : 0x040//8], pack_grad)
    np.copyto(buffer[0x040//8 : 0x080//8], pack_grad)
    
    # Scenario 1: SIGN STRESS (A=0x080, B=0x0C0)
    np.copyto(buffer[0x080//8 : 0x0C0//8], pack_sign)
    np.copyto(buffer[0x0C0//8 : 0x100//8], pack_sign)
    
    # Scenario 2: IDENTITY TEST (A=0x100, B=0x140)
    np.copyto(buffer[0x100//8 : 0x140//8], pack_grad)
    np.copyto(buffer[0x140//8 : 0x180//8], pack_ident)
    
    # Scenario 3: MAX SATURATION (A=0x180, B=0x1C0)
    np.copyto(buffer[0x180//8 : 0x1C0//8], pack_sat)
    np.copyto(buffer[0x1C0//8 : 0x200//8], pack_sat)
    
    # Scenario 4: 16x16 Matrix Tiling (A Tiles = 0x300-0x3C0, B Tiles = 0x400-0x4C0)
    np.copyto(buffer[0x300//8 : 0x340//8], pack_to_axi_64bit(MATRIX_16x16_A_T0))
    np.copyto(buffer[0x340//8 : 0x380//8], pack_to_axi_64bit(MATRIX_16x16_A_T1))
    np.copyto(buffer[0x380//8 : 0x3C0//8], pack_to_axi_64bit(MATRIX_16x16_A_T2))
    np.copyto(buffer[0x3C0//8 : 0x400//8], pack_to_axi_64bit(MATRIX_16x16_A_T3))

    np.copyto(buffer[0x400//8 : 0x440//8], pack_to_axi_64bit(MATRIX_16x16_B_T0))
    np.copyto(buffer[0x440//8 : 0x480//8], pack_to_axi_64bit(MATRIX_16x16_B_T1))
    np.copyto(buffer[0x480//8 : 0x4C0//8], pack_to_axi_64bit(MATRIX_16x16_B_T2))
    np.copyto(buffer[0x4C0//8 : 0x500//8], pack_to_axi_64bit(MATRIX_16x16_B_T3))
    
    # Scenario 5: Max Pooling Data (0x600 to 0x6C0)
    np.copyto(buffer[0x600//8 : 0x640//8], pack_to_axi_64bit(MATRIX_POOL_A))
    np.copyto(buffer[0x640//8 : 0x680//8], pack_to_axi_64bit(MATRIX_POOL_B))
    np.copyto(buffer[0x680//8 : 0x6C0//8], pack_to_axi_64bit(MATRIX_POOL_C))
    np.copyto(buffer[0x6C0//8 : 0x700//8], pack_to_axi_64bit(MATRIX_POOL_D))
    
    # Scenario 6: 24x24 Matrix Tiling

    # Activation tiles
    np.copyto(buffer[0x800//8 : 0x840//8], pack_to_axi_64bit(MATRIX_16x16_A_T0))
    np.copyto(buffer[0x840//8 : 0x880//8], pack_to_axi_64bit(MATRIX_16x16_A_T1))
    np.copyto(buffer[0x880//8 : 0x8C0//8], pack_to_axi_64bit(MATRIX_16x16_A_T2))
    np.copyto(buffer[0x8C0//8 : 0x900//8], pack_to_axi_64bit(MATRIX_16x16_A_T3))
    np.copyto(buffer[0x900//8 : 0x940//8], pack_to_axi_64bit(MATRIX_16x16_A_T0))
    np.copyto(buffer[0x940//8 : 0x980//8], pack_to_axi_64bit(MATRIX_16x16_A_T1))
    np.copyto(buffer[0x980//8 : 0x9C0//8], pack_to_axi_64bit(MATRIX_16x16_A_T2))
    np.copyto(buffer[0x9C0//8 : 0xA00//8], pack_to_axi_64bit(MATRIX_16x16_A_T3))
    np.copyto(buffer[0xA00//8 : 0xA40//8], pack_to_axi_64bit(MATRIX_16x16_A_T0))

    # Weight tiles
    np.copyto(buffer[0xA40//8 : 0xA80//8], pack_to_axi_64bit(MATRIX_16x16_B_T0))
    np.copyto(buffer[0xA80//8 : 0xAC0//8], pack_to_axi_64bit(MATRIX_16x16_B_T1))
    np.copyto(buffer[0xAC0//8 : 0xB00//8], pack_to_axi_64bit(MATRIX_16x16_B_T2))
    np.copyto(buffer[0xB00//8 : 0xB40//8], pack_to_axi_64bit(MATRIX_16x16_B_T3))
    np.copyto(buffer[0xB40//8 : 0xB80//8], pack_to_axi_64bit(MATRIX_16x16_B_T0))
    np.copyto(buffer[0xB80//8 : 0xBC0//8], pack_to_axi_64bit(MATRIX_16x16_B_T1))
    np.copyto(buffer[0xBC0//8 : 0xC00//8], pack_to_axi_64bit(MATRIX_16x16_B_T2))
    np.copyto(buffer[0xC00//8 : 0xC40//8], pack_to_axi_64bit(MATRIX_16x16_B_T3))
    np.copyto(buffer[0xC40//8 : 0xC80//8], pack_to_axi_64bit(MATRIX_16x16_B_T0))

    print("All test scenarios preloaded successfully.")
    
def preload_convolution_test(buffer):

    input_img = np.load("/home/xilinx/pynq/overlays/NPU/input_img.npy")
    kernel    = np.load("/home/xilinx/pynq/overlays/NPU/kernel.npy")

    M = 16
    K_raw = 9
    K_padded = 16
    N = 16

    conv_matA = np.zeros((M, K_padded), dtype=np.int8)
    conv_matB = np.zeros((K_padded, N), dtype=np.int8)

    patch_idx = 0

    for r in range(4):
        for c in range(4):

            patch = input_img[
                0,
                r:r+3,
                c:c+3,
                :
            ]

            conv_matA[patch_idx, :K_raw] = patch.flatten()

            patch_idx += 1

    conv_matB[:K_raw, :] = kernel.reshape(K_raw, N)

    conv_tiles_a = [
        conv_matA[0:8, 0:8],
        conv_matA[0:8, 8:16],
        conv_matA[8:16, 0:8],
        conv_matA[8:16, 8:16]
    ]

    conv_tiles_b = [
        conv_matB[0:8, 0:8],
        conv_matB[0:8, 8:16],
        conv_matB[8:16, 0:8],
        conv_matB[8:16, 8:16]
    ]

    # A @ 0x1000
    np.copyto(buffer[0x1000//8 : 0x1040//8], pack_to_axi_64bit(conv_tiles_a[0]))
    np.copyto(buffer[0x1040//8 : 0x1080//8], pack_to_axi_64bit(conv_tiles_a[1]))
    np.copyto(buffer[0x1080//8 : 0x10C0//8], pack_to_axi_64bit(conv_tiles_a[2]))
    np.copyto(buffer[0x10C0//8 : 0x1100//8], pack_to_axi_64bit(conv_tiles_a[3]))

    # B @ 0x1100
    np.copyto(buffer[0x1100//8 : 0x1140//8], pack_to_axi_64bit(conv_tiles_b[0]))
    np.copyto(buffer[0x1140//8 : 0x1180//8], pack_to_axi_64bit(conv_tiles_b[1]))
    np.copyto(buffer[0x1180//8 : 0x11C0//8], pack_to_axi_64bit(conv_tiles_b[2]))
    np.copyto(buffer[0x11C0//8 : 0x1200//8], pack_to_axi_64bit(conv_tiles_b[3]))

    return conv_matA, conv_matB
 
# Python Verification Functions
 

def check_matrix_result_python(test_name, axi_base_addr, matA, matB, use_relu, buffer):
    """Reads back data written by hardware and asserts it against NumPy golden output."""
    word_offset = axi_base_addr // 8
    
    # Read raw 64-bit words from hardware output location
    raw_hardware_data = buffer[word_offset : word_offset + 8]
    
    # Infer datatype based on inputs
    hardware_matrix = unpack_from_axi_64bit(raw_hardware_data, target_dtype=np.int8)
    
    # Compute the true golden matrix calculation
    golden_matrix = compute_reference_matmul(matA, matB, use_relu=bool(use_relu))
    
    # Check assertions
    if np.array_equal(hardware_matrix, golden_matrix):
        print(f"{test_name} PASSED at address {hex(axi_base_addr)}")
    else:
        print(f"{test_name} FAILED at address {hex(axi_base_addr)}!")
        print("Expected (Golden):\n", golden_matrix)
        print("Received (Hardware):\n", hardware_matrix)


import numpy as np
import math

def check_tiled_matrix_result_python(test_name, axi_base_addr, tiles_a, tiles_b, buffer):
    """
    Generic tiled matrix verification.

    Assumptions:
      - Input matrices are composed of square tiles (e.g. 8x8).
      - tiles_a and tiles_b contain all tiles in row-major order.
      - Hardware output is stored as packed tiles in the same order.
    """

    word_offset = axi_base_addr // 8

    num_tiles = len(tiles_a)

    if len(tiles_b) != num_tiles:
        raise ValueError("tiles_a and tiles_b must contain the same number of tiles")

    tile_grid = int(math.sqrt(num_tiles))

    if tile_grid * tile_grid != num_tiles:
        raise ValueError(
            f"Number of tiles ({num_tiles}) is not a perfect square"
        )

    tile_size = tiles_a[0].shape[0]

    # Assemble full matrix A
    full_A = np.block([
        [tiles_a[r * tile_grid + c] for c in range(tile_grid)]
        for r in range(tile_grid)
    ])

    # Assemble full matrix B
    full_B = np.block([
        [tiles_b[r * tile_grid + c] for c in range(tile_grid)]
        for r in range(tile_grid)
    ])

    # Golden result
    golden = np.matmul(
        full_A.astype(np.int32),
        full_B.astype(np.int32)
    )

    golden = np.clip(golden, 0, 127).astype(np.int8)

    # Number of 64-bit words per tile
    words_per_tile = (tile_size * tile_size) // 8

    total_words = num_tiles * words_per_tile

    raw_hw = buffer[word_offset:word_offset + total_words]

    # Unpack all hardware tiles
    hw_tiles = []

    for i in range(num_tiles):
        start = i * words_per_tile
        end = start + words_per_tile

        tile = unpack_from_axi_64bit(
            raw_hw[start:end],
            target_dtype=np.int8
        )

        hw_tiles.append(tile)

    # Reconstruct hardware matrix
    hardware = np.block([
        [hw_tiles[r * tile_grid + c] for c in range(tile_grid)]
        for r in range(tile_grid)
    ])

    if np.array_equal(hardware, golden):
        print(f"{test_name} PASSED at address {hex(axi_base_addr)}")
    else:
        print(f"{test_name} FAILED at address {hex(axi_base_addr)}!")
        
def check_convolution_result(
    axi_base_addr,
    buffer,
    reference_output
):

    word_offset = axi_base_addr // 8

    raw_hw = buffer[word_offset : word_offset + 32]

    tile0 = unpack_from_axi_64bit(raw_hw[0:8])
    tile1 = unpack_from_axi_64bit(raw_hw[8:16])
    tile2 = unpack_from_axi_64bit(raw_hw[16:24])
    tile3 = unpack_from_axi_64bit(raw_hw[24:32])

    hw = np.block([
        [tile0, tile1],
        [tile2, tile3]
    ])

    ref = reference_output.reshape(16,16)

    if np.array_equal(hw, ref):
        print("Convolution PASS")
    else:
        print("Convolution FAIL")
 
# Main Execution Pipeline
 


# 1. Allocate buffer and preload
data_buffer = allocate(shape=(2048,), dtype=np.uint64)
data_buffer[:] = 0 
rvsda.ddr_base = data_buffer.device_address

preload_all_scenario_matrices(data_buffer)
conv_matA, conv_matB = preload_convolution_test(data_buffer)

data_buffer.flush()

# 2. Trigger hardware processing
instructions = np.fromfile("/home/xilinx/pynq/overlays/RVSDA/firmware/firmware_pynq_base_test.bin", dtype=np.uint32)
rvsda.load_instruction_memory(instructions)
print("\nKicking off PicoRV32 processor core...")
rvsda.start() 
rvsda.wait_done()


# Invalidate data cache to safely read recent physical master updates
data_buffer.invalidate()

# 4. Evaluate Outputs directly using our checker updates
check_matrix_result_python("Gradient Test",   0x200, MATRIX_GRADIENT,    MATRIX_GRADIENT,    1, data_buffer)
check_matrix_result_python("Sign Stress",     0x240, MATRIX_SIGN_STRESS, MATRIX_SIGN_STRESS, 1, data_buffer)
check_matrix_result_python("Identity Test",   0x280, MATRIX_GRADIENT,    MATRIX_IDENTITY,    1, data_buffer)
check_matrix_result_python("Max Saturation",  0x2C0, MATRIX_MAX_SAT,     MATRIX_MAX_SAT,     1, data_buffer)

check_tiled_matrix_result_python(
    test_name="Tiled 16x16 Execution Check",
    axi_base_addr=0x500,
    tiles_a=(MATRIX_16x16_A_T0, MATRIX_16x16_A_T1, MATRIX_16x16_A_T2, MATRIX_16x16_A_T3),
    tiles_b=(MATRIX_16x16_B_T0, MATRIX_16x16_B_T1, MATRIX_16x16_B_T2, MATRIX_16x16_B_T3),
    buffer=data_buffer
)
check_tiled_matrix_result_python(
    test_name="24x24 Execution Check",
    axi_base_addr=0xC80,
    tiles_a = (
    MATRIX_16x16_A_T0,
    MATRIX_16x16_A_T1,
    MATRIX_16x16_A_T2,
    MATRIX_16x16_A_T3,
    MATRIX_16x16_A_T0,
    MATRIX_16x16_A_T1,
    MATRIX_16x16_A_T2,
    MATRIX_16x16_A_T3,
    MATRIX_16x16_A_T0,
),  
    tiles_b = (
    MATRIX_16x16_B_T0,
    MATRIX_16x16_B_T1,
    MATRIX_16x16_B_T2,
    MATRIX_16x16_B_T3,
    MATRIX_16x16_B_T0,
    MATRIX_16x16_B_T1,
    MATRIX_16x16_B_T2,
    MATRIX_16x16_B_T3,
    MATRIX_16x16_B_T0,
),
    buffer=data_buffer
)

check_matrix_result_python("Normal Operation Test 1", 0x700, MATRIX_POOL_A, MATRIX_POOL_B, 1, data_buffer)
check_matrix_result_python("Normal Operation Test 2", 0x740, MATRIX_POOL_C, MATRIX_POOL_D, 1, data_buffer)

reference_output = np.load("/home/xilinx/pynq/overlays/NPU/output_conv.npy")
software_gemm = np.matmul(
    conv_matA.astype(np.int32),
    conv_matB.astype(np.int32)
)

software_gemm = np.clip(
    software_gemm,
    0,
    127
).astype(np.int8)

reference_gemm = reference_output.reshape(16,16)

print(
    "Im2Col matches TensorFlow:",
    np.array_equal(
        software_gemm,
        reference_gemm
    )
)

check_convolution_result(
    axi_base_addr=0x1200,
    buffer=data_buffer,
    reference_output=reference_output
)

