import numpy as np
 
from .rvsda_utils import (
    build_im2col_gemm,
    quantize_symmetric,
    requantize,
)
def run_conv_layer_sw(
    image_q,
    weight_q
):
    A, B, M, K, N, Mp, Kp, Np = build_im2col_gemm(
        image_q,
        weight_q,
        dtype=np.float32
    )

    conv = A.astype(np.int32) @ B.astype(np.int32)

    conv = conv[:M, :N]

    return conv.reshape(26, 26, 8)
def relu_sw(x):
    return np.maximum(x, 0)
def maxpool2x2_sw(x):
    h,w,c = x.shape

    out = np.zeros(
        (h//2, w//2, c),
        dtype=x.dtype
    )

    for y in range(h//2):
        for x0 in range(w//2):
            region = x[
                y*2:y*2+2,
                x0*2:x0*2+2,
                :
            ]

            out[y,x0,:] = np.max(
                region,
                axis=(0,1)
            )

    return out
def run_dense_layer_sw(
    activations,
    weights
):
    return (
        activations.astype(np.int32)
        @
        weights.astype(np.int32)
    )

def conv2d_fp32(image, weights):

    A, B, M, K, N, Mp, Kp, Np = build_im2col_gemm(
        image.astype(np.float32),
        weights.astype(np.float32)
    )

    out = A @ B
    out = out[:M, :N]
    return out.reshape(26,26,N)
def run_network_sw_FP32(
    image,
    conv_weights,
    dense_weights
):

    conv = conv2d_fp32(image, conv_weights)
    conv = relu_sw(conv)
    pooled = maxpool2x2_sw(conv)
    dense = pooled.reshape(1, -1).astype(np.float32) @ dense_weights.astype(np.float32)
    return dense

def run_network_sw_INT8(
    image,
    q_conv,
    q_dense,
    scales,
    M0_conv,
    shift_conv,
    M0_dense,
    shift_dense
):

    q_image = quantize_symmetric(
        image,
        scales["input_scale"]
    )

    conv = run_conv_layer_sw(
        q_image,
        q_conv
    )

    conv=requantize(conv,M0_conv,shift_conv, True)
    pooled = maxpool2x2_sw(conv)

    dense = run_dense_layer_sw(
        pooled.reshape(1,-1),
        q_dense
    )
    dense=requantize(dense,M0_dense,shift_dense)
    

    return dense