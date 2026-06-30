import time
import numpy as np

from .rvsda_utils import (
    build_im2col_gemm,
    matrix_to_tiled_words,
    load_matrix_to_ddr,
    read_tiled_matrix,
    quantize_symmetric,
)


def run_npu_gemm(
    npu,
    ddr,
    A_pad,
    B_pad = None,
    a_offset = 0,
    b_offset = 0
):
#     t=time.time()

    load_matrix_to_ddr(ddr, A_pad, a_offset)
#     print("ddr load", time.time()-t)

#     t=time.time()
    npu.start()
    npu.wait_done()
#     print("npu done", time.time()-t)

#     t=time.time()
    ddr.invalidate()
#     print("invalidate", time.time()-t)
    
def run_conv_layer(
    npu,
    ddr,
    image_q,
    weight_q,
    a_offset = 0,
    b_offset = 0
):
#     t=time.time()
    t0 = time.perf_counter()
    A, B, M, K, N, Mp, Kp, Np = build_im2col_gemm(
        image_q,
        weight_q
    )
    im2col_time = time.perf_counter() - t0

#     print("im2col", time.time()-t)
    t0 = time.perf_counter()
    run_npu_gemm(
        npu,
        ddr,
        A,
#         B,
        a_offset = a_offset
#         b_offset = 0
    )
    conv_pool_time = time.perf_counter() - t0

#     hw_conv = read_tiled_matrix_from_ddr(
#         ddr,
#         0x2B00,
#         Mp,
#         Np
#     )

#     hw_conv = hw_conv[:M, :N]

#     return hw_conv.reshape(26,26,8)
    return im2col_time, conv_pool_time
def run_dense_layer(
    npu,
    ddr,
    activations_q,
    weights_q,
    a_offset = 0,
    b_offset = 0,
    out_offset = 0
):
    M = 1
    K = activations_q.shape[1]
    N = weights_q.shape[1]

    Mp = ((M+7)//8)*8
    Kp = ((K+7)//8)*8
    Np = ((N+7)//8)*8

    A_pad = np.zeros((Mp,Kp), dtype=np.int8)
#     B_pad = np.zeros((Kp,Np), dtype=np.int8)

    A_pad[:M,:K] = activations_q
#     B_pad[:K,:N] = weights_q
    t0 = time.perf_counter()
    run_npu_gemm(
        npu,
        ddr,
        A_pad,
#         B_pad,
        a_offset = a_offset
#         b_offset = 0
    )
#     npu.start()
#     npu.wait_done()
    dense_time = time.perf_counter() - t0
    
    t0 = time.perf_counter()
    out = read_tiled_matrix(
        ddr,
        out_offset*8,
        Mp,
        Np
    )
    dense_readback_time = time.perf_counter() - t0


    return out[:M,:N], dense_time, dense_readback_time

def run_network(
    npu,
    ddr,
    image,
    q_conv,
    q_dense,
    scales,
    a_offset,
    out_offset
):
#     t=time.time()
    t0 = time.perf_counter()
    q_image = quantize_symmetric(
        image,
        scales["input_scale"]
    )
    quant_time = time.perf_counter() - t0
#     print("quant", time.time()-t)

#     t=time.time()
    im2col_time, conv_pool_time = run_conv_layer(
                                                npu,
                                                ddr,
                                                q_image,
                                                q_conv,
                                                a_offset = a_offset
                                            )
#     print("conv layer total", time.time()-t)

#     t=time.time()
    t0 = time.perf_counter()
    pooled = read_tiled_matrix(
        ddr,
        out_offset*8,
        176,
        8
    )
    pooled_read_time = time.perf_counter() - t0

#     print("pool read", time.time()-t)

#     t=time.time()
    dense, dense_time, dense_readback_time = run_dense_layer(
        npu,
        ddr,
        pooled.reshape(1,-1),
        q_dense,
        a_offset = a_offset,
        out_offset = out_offset
    )
    stats = {
    "quant": quant_time,
    "im2col": im2col_time,
    "conv_pool": conv_pool_time,
    "pooled_read": pooled_read_time,
    "dense": dense_time,
    "dense_readback": dense_readback_time
}
#     print("dense layer total", time.time()-t)
    return dense, stats

def preload_weights(data_buffer, q_image, q_conv,q_dense, conv_weight_offset = 0, dense_weight_offset = None):
    conv_A, conv_B, *_ = build_im2col_gemm(q_image, q_conv)


    
    K = q_dense.shape[0]
    N = q_dense.shape[1]
    Kp = ((K+7)//8)*8
    Np = ((N+7)//8)*8
    B_dense = np.zeros((Kp, Np), dtype=np.int8)
    B_dense[:K, :N] = q_dense    
    
    conv_weight_tiles = matrix_to_tiled_words(conv_B)
    
    dense_weight_offset = (
        conv_weight_offset +
        conv_weight_tiles.size
    )

    dense_weight_tiles = matrix_to_tiled_words(B_dense)

    load_matrix_to_ddr(
        data_buffer,
        conv_B,
        conv_weight_offset
    )

    load_matrix_to_ddr(
        data_buffer,
        B_dense,
        dense_weight_offset
    )
    
    print("Conv weights start at word offset:", conv_weight_offset*8)
    print("Dense weights start at word offset:",
          dense_weight_offset*8)
    activation_offset = (
        dense_weight_offset +
        dense_weight_tiles.size
    )
    print("Activations start word at:", activation_offset*8)
    activation_words = conv_A.size // 8
    output_offset = (
        activation_offset +
        activation_words
    )
    print("Output starts at :", output_offset*8)
    return activation_offset, output_offset
    