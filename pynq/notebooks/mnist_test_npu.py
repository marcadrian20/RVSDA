#!/usr/bin/env python
# coding: utf-8

# In[2]:


from pynq import Overlay, allocate
import numpy as np

from pynq.overlays.RVSDA import *

ol = Overlay("RVSDA.bit")

# print(ol.ip_dict)
rvsda = ol.RVSDA_0 



# Allocate the ddr buffer
data_buffer = allocate(shape=(4096,), dtype=np.uint64)
data_buffer[:] = 0 
rvsda.ddr_base = data_buffer.device_address

data_buffer.flush() # Ensure DDR is completely loaded



image = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/test_image.npy"
)

conv_weights = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/conv_weights.npy"
)

dense_weights = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/dense_weights.npy"
)

ref_conv = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/ref_conv.npy"
)

ref_relu = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/ref_relu.npy"
)

ref_pool = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/ref_pool.npy"
)

ref_dense = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/ref_dense.npy"
)

scales = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/scales.npz"
)

input_scale = float(scales["input_scale"])

conv_scale = float(scales["conv_weight_scale"])
dense_scale = float(scales["dense_weight_scale"])

conv_out_scale = float(scales["conv_out_scale"])
pool_out_scale = float(scales["pool_out_scale"])
dense_out_scale = float(scales["dense_out_scale"])

print("Image:", image.shape)
print("Conv:", conv_weights.shape)
# print("Dense:", dense_weights.shape)

# ============================================================
# Quantize
# ============================================================

q_image = quantize_symmetric(image, input_scale)
q_conv = quantize_symmetric(conv_weights, conv_scale)
q_ref_conv = quantize_symmetric(ref_conv, conv_out_scale)

q_dense = quantize_symmetric(dense_weights, dense_scale)
print("Image scale =", input_scale)
print("Conv scale  =", conv_scale)
print("Conv output scale  =", conv_out_scale)
print("conv_out_scale = ", conv_out_scale)
print("Dense scale =", dense_scale)
print("Quantized img shape: ",q_image.shape)
print("Quantized conv shape: ",q_conv.shape)

Multiplier = input_scale * conv_scale / conv_out_scale
M0_conv, shift_conv = compute_multiplier_and_shift(Multiplier)

print("M0_conv =", M0_conv)
print("shift_conv =", shift_conv)



#load instructions in the rv core
instructions = np.fromfile("/home/xilinx/pynq/overlays/RVSDA/firmware/firmware_pynq_simple_28x28_test.bin", dtype=np.uint32)
rvsda.load_instruction_memory(instructions)
print("\nKicking off PicoRV32 processor core...")
# npu.start()
# npu.wait_done()
# time.sleep(1)

# Invalidate data cache to safely read recent physical master updates
data_buffer.invalidate()
activation_offset, output_offset = preload_weights(
    data_buffer,
    q_image,
    q_conv,
    q_dense
)

run_conv_layer(
    rvsda,
    data_buffer,
    q_image,
    q_conv,
    activation_offset
)

hw_conv = read_tiled_matrix(
    data_buffer,
    0x2B00,
    680,
    8
)[:676]

golden_conv = requantize(
    run_conv_layer_sw(q_image, q_conv),
    M0_conv,
    shift_conv,
    relu=True
).reshape(676,8)
print(hw_conv[:5])
print(golden_conv[:5])

diff = hw_conv.astype(np.int16) - golden_conv.astype(np.int16)
print(np.max(np.abs(diff)))
print(np.argwhere(diff != 0)[:20])
assert np.array_equal(hw_conv, golden_conv)
print("Quantization unit and CONV PASSED")

print("POOLING TEST: ")
print("REF RELU SHAPE: ",ref_relu.shape)
print("REF POOL SHAPE: ",ref_pool.shape)

ref_pool_flat = ref_pool.reshape(169,8)

hw_pool = read_tiled_matrix_from_ddr(
    buffer=data_buffer,
    base_addr=0x4040,
    rows=176,
    cols=8,
    dtype=np.int8
)
print("hw pool shape = ",hw_pool.shape)

hw_pool = hw_pool[:169, :]
print(hw_pool)

q_ref_pool = quantize_symmetric(ref_pool,pool_out_scale)

ref_pool_flat = q_ref_pool.reshape(169, 8)
print("ref pool flat shape = ", ref_pool_flat.shape)
print("HW matches reference:",
      np.array_equal(hw_pool, ref_pool_flat))

print("hw max =", np.max(hw_pool))
print("hw min =", np.min(hw_pool))
print("nonzero =", np.count_nonzero(hw_pool))

golden_pool = maxpool2x2_sw(golden_int8)
print(np.array_equal(hw_pool, golden_pool))

for addr in [0x4040, 0x4200, 0x4400, 0x4580, 0x4800]:
    dump = read_tiled_matrix_from_ddr(
        buffer=data_buffer,
        base_addr=addr,
        rows=32,
        cols=8,
        dtype=np.int8
    )

    print(
        hex(addr),
        "nonzero =", np.count_nonzero(dump),
        "max =", np.max(dump)
    )
print("golden nonzero =", np.count_nonzero(golden_pool))
print("golden max =", np.max(golden_pool))
hw_nonzero_rows = np.where(
    np.any(hw_pool != 0, axis=1)
)[0]

gold_nonzero_rows = np.where(
    np.any(golden_pool != 0, axis=1)
)[0]

print(hw_nonzero_rows[:20])
print(gold_nonzero_rows[:20])

from collections import Counter

hw_list = [tuple(x) for x in hw_pool]
gold_list = [tuple(x) for x in golden_pool]

print(Counter(hw_list) == Counter(gold_list))
print(np.array_equal(hw_pool, golden_pool))
diff = hw_pool.astype(np.int16) - golden_pool.astype(np.int16)

print("max abs diff =", np.max(np.abs(diff)))

idx = np.argwhere(diff != 0)

print("mismatches =", len(idx))

for r,c in idx[:20]:
    print(
        r,
        c,
        hw_pool[r,c],
        golden_pool[r,c]
    )
    
hw_pool_fp32 = (
    hw_pool.astype(np.float32)
    * conv_out_scale
)
print(
    np.max(
        np.abs(
            hw_pool_fp32 -
            ref_pool.reshape(169,8)
        )
    )
)
# print(npu.status)
print("DENSE TEST:")

print(dense_weights.shape)
print(ref_dense.shape)


dense_multiplier = (
    conv_out_scale *
    dense_scale /
    dense_out_scale
)

M0_dense, shift_dense = compute_multiplier_and_shift(
    dense_multiplier
)
print("Mult dense: ", M0_dense)
print("SHFT dense: ", shift_dense)

hw_dense = run_dense_layer(
    rvsda,
    data_buffer,
    hw_pool.reshape(1,-1),
    q_dense,
    activation_offset,
    output_offset
)

golden_dense = run_dense_layer_sw(
    hw_pool.reshape(1,-1),
    q_dense
)

golden_dense = requantize(
    golden_dense,
    M0_dense,
    shift_dense
)
print(np.array_equal(
    hw_dense,
    golden_dense_int8
))

print("HW dense:")
print(hw_dense)

print("Golden dense:")
print(golden_dense_int8)

diff = hw_dense.astype(np.int16) - golden_dense_int8.astype(np.int16)

print("max abs diff =", np.max(np.abs(diff)))

idx = np.argwhere(diff != 0)

print("mismatches =", len(idx))

for r,c in idx[:20]:
    print(
        r,
        c,
        hw_dense[r,c],
        golden_dense_int8[r,c]
    )
print(np.min(ref_dense))
print(np.max(ref_dense))

pred_hw = np.argmax(hw_dense)
pred_ref = np.argmax(ref_dense)

print(pred_hw, pred_ref)
hw_dense_fp32 = (
    hw_dense.astype(np.float32)
    * dense_out_scale
)

print(
    "max abs error vs ref =",
    np.max(
        np.abs(
            hw_dense_fp32 -
            ref_dense
        )
    )
)

print("mean abs error",
      np.mean(np.abs(hw_dense_fp32 - ref_dense)))

print(
    np.argmax(hw_dense_fp32),
    np.argmax(ref_dense)
)


# In[ ]:





# In[ ]:




