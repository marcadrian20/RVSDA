#!/usr/bin/env python
# coding: utf-8

from pynq import Overlay, allocate
import numpy as np
import time
import math
from pynq.overlays.RVSDA import *

ol = Overlay("RVSDA.bit")

# print(ol.ip_dict)
rvsda = ol.RVSDA_0 

# Allocate the ddr buffer
data_buffer = allocate(shape=(8192,), dtype=np.uint64)
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

mnist = np.load(
    "/home/xilinx/pynq/overlays/RVSDA/mnist_test/mnist_test_full.npz"
)

images = mnist["images"]
labels = mnist["labels"]

print(images.shape)  # (10000, 28, 28)
print(labels.shape)  # (10000,)

#load instructions in the rv core
instructions = np.fromfile("/home/xilinx/pynq/overlays/RVSDA/firmware/firmware_mnist_net_test.bin", dtype=np.uint32)
rvsda.load_instruction_memory(instructions)
print("\nKicking off PicoRV32 processor core...")

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

activation_offset,output_offset=preload_weights(data_buffer, image,q_conv,q_dense)
# t0 = time.perf_counter()

# dense = run_network(
#     rvsda,
#     data_buffer,
#     image,
#     q_conv,
#     q_dense,
#     scales,
#     a_offset=activation_offset,
#     out_offset=output_offset
# )
# t1 = time.perf_counter()
# print("network done",t1 - t0)
# # time.sleep(1)
# print(dense)
# dense_out = run_network_sw_INT8(
#         image,
#         q_conv,
#         q_dense,
#         scales,
#         M0_conv,
#         shift_conv,
#         M0_dense,
#         shift_dense
#     )
# print(dense_out)

# dense_out= run_network_sw_FP32(
#     image,
#     conv_weights,
#     dense_weights
# )
# print(dense_out)

# correct_sw = 0
# t0 = time.perf_counter()

# for i in range(len(images)):
# #     t2 = time.time()
#     dense_out = run_network_sw_FP32(
#         images[i],
#         conv_weights,
#         dense_weights
#     )
# #     t3 = time.time()
# #     print(t3 - t2)
#     pred = np.argmax(dense_out)

#     if pred == labels[i]:
#         correct_sw += 1
# t1 = time.perf_counter()
# arm_FP32_latency_ms = (t1-t0)/len(images)*1000
# print("FP32 latency:",
#       arm_FP32_latency_ms,
#       "ms")

# print("FP32 accuracy:",
#       100*correct_sw/len(images))


correct = 0
t0 = time.perf_counter()
for i in range(len(images)):

    dense_out, _ = run_network(
        rvsda,
        data_buffer,
        images[i],
        q_conv,
        q_dense,
        scales,
        a_offset=activation_offset,
        out_offset=output_offset
    )

    pred = np.argmax(dense_out)

    if pred == labels[i]:
        correct += 1

t1 = time.perf_counter()
rvsda_latency_ms = (t1-t0)/len(images)*1000
print("RVSDA latency:",
      rvsda_latency_ms,
      "ms")

print("RVSDA accuracy:",
      100*correct/len(images))

# correct_sw = 0

# t0 = time.perf_counter()

# for i in range(len(images)):
# #     t2 = time.time()
#     dense_out = run_network_sw_INT8(
#         images[i],
#         q_conv,
#         q_dense,
#         scales,
#         M0_conv,
#         shift_conv,
#         M0_dense,
#         shift_dense
#     )
# #     t3 = time.time()
# #     print(t3 - t2)
#     pred = np.argmax(dense_out)

#     if pred == labels[i]:
#         correct_sw += 1

# t1 = time.perf_counter()
# arm_latency_ms = (t1-t0)/len(images)*1000
# print(
#     "ARM latency:",
#     arm_latency_ms,
#     "ms"
# )
# print(
#     "ARM accuracy:",
#     100*correct_sw/len(images)
# )

# correct = 0
# total_quant_time = 0.0
# total_im2col_time = 0.0
# total_conv_pool_time = 0.0
# total_pooled_read_time = 0.0
# total_dense_time = 0.0
# total_dense_readback_time = 0.0
# correct = 0
# t0 = time.perf_counter()
# for i in range(1000):

#     dense_out,stats = run_network(
#                                 rvsda,
#                                 data_buffer,
#                                 images[i],
#                                 q_conv,
#                                 q_dense,
#                                 scales,
#                                 a_offset=activation_offset,
#                                 out_offset=output_offset,
#                                 )

#     pred = np.argmax(dense_out)

#     if pred == labels[i]:
#         correct += 1
#     total_quant_time += stats["quant"]
#     total_im2col_time += stats[ "im2col"]
#     total_conv_pool_time += stats["conv_pool"]
#     total_pooled_read_time += stats["pooled_read"]
#     total_dense_time += stats["dense"]
#     total_dense_readback_time += stats["dense_readback"]
    
# t1 = time.perf_counter()
# rvsda_latency_ms = (t1-t0)/1000*1000
# print("RVSDA latency:",
#       rvsda_latency_ms,
#       "ms")

# print("RVSDA accuracy:",
#       100*correct/1000)
# num_images = 1000
# print("Average quantization:", total_quant_time / num_images * 1000, "ms")
# print("Average im2col:", total_im2col_time / num_images * 1000, "ms")
# print("Average conv+pool:", total_conv_pool_time / num_images * 1000, "ms")
# print("Average pooled read:", total_pooled_read_time / num_images * 1000, "ms")
# print("Average dense:", total_dense_time / num_images * 1000, "ms")
# print("Average dense readback:", total_dense_readback_time / num_images * 1000, "ms")


