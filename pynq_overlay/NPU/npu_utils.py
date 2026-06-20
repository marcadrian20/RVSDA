import numpy as np
import time
import math
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
    pad=0
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

    # --------------------------------------------------
    # Build im2col matrix A
    # --------------------------------------------------

    A = np.zeros((M, K), dtype=np.int8)

    row = 0

    for r in range(0, OH):
        for c in range(0, OW):

            patch = image[
                r*stride:r*stride+KH,
                c*stride:c*stride+KW,
                :
            ]

            A[row, :] = patch.flatten()

            row += 1

    # --------------------------------------------------
    # Build weight matrix B
    # --------------------------------------------------

    B = kernels.reshape(K, N).astype(np.int8)

    # --------------------------------------------------
    # Pad all GEMM dimensions to multiples of 8
    # --------------------------------------------------

    M_pad = ((M + 7) // 8) * 8
    K_pad = ((K + 7) // 8) * 8
    N_pad = ((N + 7) // 8) * 8

    A_padded = np.zeros(
        (M_pad, K_pad),
        dtype=np.int8
    )

    B_padded = np.zeros(
        (K_pad, N_pad),
        dtype=np.int8
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
def split_into_8x8_tiles(mat):

    rows, cols = mat.shape

    assert rows % 8 == 0
    assert cols % 8 == 0

    tiles = []

    for r in range(0, rows, 8):
        for c in range(0, cols, 8):

            tiles.append(
                mat[r:r+8, c:c+8]
            )

    return tiles
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

def unpack_from_axi_64bit(uint64_array, target_dtype=np.int8):
    """Converts eight 64-bit words back into an 8x8 matrix for verification."""
    return uint64_array.view(target_dtype).reshape((8, 8))

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
def load_tiles_to_ddr(
    ddr_buffer,
    A_tiles=None,
    B_tiles=None,
    a_offset=0,
    b_offset= None
):
    if A_tiles is not None:
        ptr = a_offset
        if b_offset is None:
            b_offset = len(A_tiles) * 8
        for tile in A_tiles:
            packed = pack_to_axi_64bit(tile)
            ddr_buffer[ptr:ptr+8] = packed
            ptr += 8

    if B_tiles is not None:
        ptr = b_offset

        for tile in B_tiles:
            packed = pack_to_axi_64bit(tile)
            ddr_buffer[ptr:ptr+8] = packed
            ptr += 8

    ddr_buffer.flush()

    return b_offset
def read_tiled_matrix_from_ddr(
    buffer,
    base_addr,
    rows,
    cols,
    tile_size=8,
    dtype=np.int8
):
    """
    Reads a tiled matrix stored in DDR and reconstructs it.

    Parameters
    ----------
    buffer    : PYNQ DDR buffer
    base_addr : byte address
    rows      : matrix rows
    cols      : matrix cols
    tile_size : usually 8
    dtype     : np.int8

    Returns
    -------
    matrix : (rows, cols)
    """

    assert rows % tile_size == 0
    assert cols % tile_size == 0

    tiles_r = rows // tile_size
    tiles_c = cols // tile_size

    words_per_tile = (tile_size * tile_size) // 8

    word_offset = base_addr // 8

    result = np.zeros(
        (rows, cols),
        dtype=dtype
    )

    tile_idx = 0

    for tr in range(tiles_r):
        for tc in range(tiles_c):

            start = word_offset + tile_idx * words_per_tile
            end   = start + words_per_tile

            tile = unpack_from_axi_64bit(
                buffer[start:end],
                target_dtype=dtype
            )

            result[
                tr*tile_size:(tr+1)*tile_size,
                tc*tile_size:(tc+1)*tile_size
            ] = tile

            tile_idx += 1

    return result
