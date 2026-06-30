import numpy as np
import math
from numpy.lib.stride_tricks import sliding_window_view
def quantize_symmetric(x, scale):

    q = np.round(x / scale)

    q = np.clip(
        q,
        -127,
        127
    ).astype(np.int8)

    return q
def requantize(acc, M0, shift, relu=False):

    prod = acc.astype(np.int64) * M0

    total_shift = 31 + shift

    rounding = 1 << (total_shift - 1)

    prod = np.where(
        prod >= 0,
        prod + rounding,
        prod + rounding - 1
    )

    out = prod >> total_shift

    if relu:
        out = np.clip(out, 0, 127)
    else:
        out = np.clip(out, -128, 127)

    return out.astype(np.int8)
def build_im2col_gemm(
    image,
    kernels,
    stride=1,
    pad=0,
    dtype=np.int8
):
    """
    image   : (H,W,C)
    kernels : (KH,KW,C,F)

    Returns:

        A_padded : (M_pad, K_pad)
        B_padded : (K_pad, N_pad)

        M = output pixels
        K = kernel volume
        N = output channels
    """

    if image.ndim == 2:
        image = image[:, :, np.newaxis]

    H, W, C = image.shape

    KH, KW, KC, F = kernels.shape

    assert KC == C

    if pad > 0:
        image = np.pad(
            image,
            (
                (pad, pad),
                (pad, pad),
                (0, 0)
            ),
            mode="constant"
        )

    H_pad, W_pad, _ = image.shape

    OH = (H_pad - KH) // stride + 1
    OW = (W_pad - KW) // stride + 1

    M = OH * OW
    K = KH * KW * C
    N = F

 
    # Build im2col matrix A
 

    patches = sliding_window_view(
    image,
    (KH, KW),
    axis=(0, 1)
)

    # apply stride
    patches = patches[::stride, ::stride]

    OH, OW = patches.shape[:2]

    A = patches.reshape(OH * OW, KH * KW * C)

 
    # Build weight matrix B
 

    B = kernels.reshape(K, N).astype(dtype)

 
    # Pad all GEMM dimensions to multiples of 8
 

    M_pad = ((M + 7) // 8) * 8
    K_pad = ((K + 7) // 8) * 8
    N_pad = ((N + 7) // 8) * 8

    A_padded = np.zeros(
        (M_pad, K_pad),
        dtype=dtype
    )

    B_padded = np.zeros(
        (K_pad, N_pad),
        dtype=dtype
    )

    A_padded[:M, :K] = A
    B_padded[:K, :N] = B

    return (
        A_padded,
        B_padded,
        M,
        K,
        N,
        M_pad,
        K_pad,
        N_pad
    )
def compute_multiplier_and_shift(M):

    shift = 0

    while M < 0.5:
        M *= 2.0
        shift += 1

    M0 = int(round(M * (1 << 31)))

    if M0 == (1 << 31):
        M0 >>= 1
        shift -= 1

    return M0, shift


# def load_tiles_to_ddr(
#     ddr_buffer,
#     A_tiles=None,
#     B_tiles=None,
#     a_offset=0,
#     b_offset= None
# ):
#     if A_tiles is not None:
#         ptr = a_offset
#         if b_offset is None:
#             b_offset = len(A_tiles) * 8
#         for tile in A_tiles:
#             packed = pack_to_axi_64bit(tile)
#             ddr_buffer[ptr:ptr+8] = packed
#             ptr += 8

#     if B_tiles is not None:
#         ptr = b_offset

#         for tile in B_tiles:
#             packed = pack_to_axi_64bit(tile)
#             ddr_buffer[ptr:ptr+8] = packed
#             ptr += 8

#     ddr_buffer.flush()

#     return b_offset
def matrix_to_tiled_words(mat):
    rows, cols = mat.shape

    tiled = (
        mat.reshape(rows//8, 8, cols//8, 8)
           .transpose(0, 2, 1, 3)
           .copy()
    )

    return tiled.view(np.uint64).reshape(-1)
def load_matrix_to_ddr(ddr, mat, offset):
    words = matrix_to_tiled_words(mat)
    ddr[offset:offset + len(words)] = words
    ddr.flush()

def read_tiled_matrix(
    buffer,
    base_addr,
    rows,
    cols,
    dtype=np.int8
):
    word_offset = base_addr // 8

    words = (rows * cols) // 8

    raw = buffer[
        word_offset:
        word_offset + words
    ]

    tiles_r = rows // 8
    tiles_c = cols // 8

    return (
        raw
        .view(dtype)
        .reshape(tiles_r, tiles_c, 8, 8)
        .transpose(0, 2, 1, 3)
        .reshape(rows, cols)
    )
