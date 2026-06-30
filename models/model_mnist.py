import tensorflow as tf
from tensorflow import keras
import numpy as np
import os

os.makedirs("model_weights", exist_ok=True)

# ============================================================
# MNIST
# ============================================================

(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

x_train = x_train.astype(np.float32) / 255.0
x_test  = x_test.astype(np.float32) / 255.0

# ============================================================
# Hardware-friendly model
# ============================================================

model = keras.Sequential([
    keras.layers.Input(shape=(28,28)),
    keras.layers.Reshape((28,28,1), name="input_reshape"),

    keras.layers.Conv2D(
        filters=8,
        kernel_size=(3,3),
        padding="valid",
        use_bias=False,
        activation=None,
        name="conv1"
    ),

    keras.layers.ReLU(name="relu1"),

    keras.layers.MaxPooling2D(
        pool_size=(2,2),
        strides=2,
        name="pool1"
    ),

    keras.layers.Flatten(name="flatten"),

    keras.layers.Dense(
        10,
        use_bias=False,
        activation=None,
        name="dense1"
    )
])

model.summary()

model.compile(
    optimizer="adam",
    loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
    metrics=["accuracy"]
)

model.fit(
    x_train,
    y_train,
    epochs=3,
    batch_size=128,
    validation_split=0.1
)

score = model.evaluate(x_test, y_test)

print("Accuracy:", score[1])

conv_weights = model.get_layer("conv1").get_weights()[0]
dense_weights = model.get_layer("dense1").get_weights()[0]

np.save(
    "model_weights/conv_weights.npy",
    conv_weights.astype(np.float32)
)

np.save(
    "model_weights/dense_weights.npy",
    dense_weights.astype(np.float32)
)
dense_weights_gemm = dense_weights.T

np.save(
    "model_weights/dense_weights_gemm.npy",
    dense_weights_gemm.astype(np.float32)
)
print("conv_weights:", conv_weights.shape)
print("dense_weights:", dense_weights.shape)

debug_model = keras.Model(
    inputs=model.inputs,
    outputs=[
        model.get_layer("conv1").output,
        model.get_layer("relu1").output,
        model.get_layer("pool1").output,
        model.get_layer("dense1").output
    ]
)

sample = x_test[0:1]

conv_out, relu_out, pool_out, dense_out = \
    debug_model.predict(sample)
np.save(
    "model_weights/test_image.npy",
    sample[0]
)

np.save(
    "model_weights/test_label.npy",
    np.array([y_test[0]])
)
np.save(
    "model_weights/ref_conv.npy",
    conv_out
)

np.save(
    "model_weights/ref_relu.npy",
    relu_out
)

np.save(
    "model_weights/ref_pool.npy",
    pool_out
)

np.save(
    "model_weights/ref_dense.npy",
    dense_out
)
np.savez_compressed(
    "model_weights/mnist_test_full.npz",
    images=x_test.astype(np.float32),
    labels=y_test.astype(np.int32)
)

calib_images = x_train[:1000]

max_conv  = 0.0
max_relu  = 0.0
max_pool  = 0.0
max_dense = 0.0

for i in range(len(calib_images)):

    img = calib_images[i:i+1]

    conv_out, relu_out, pool_out, dense_out = \
        debug_model.predict(img, verbose=0)

    max_conv = max(
        max_conv,
        np.max(np.abs(conv_out))
    )

    max_relu = max(
        max_relu,
        np.max(np.abs(relu_out))
    )

    max_pool = max(
        max_pool,
        np.max(np.abs(pool_out))
    )

    max_dense = max(
        max_dense,
        np.max(np.abs(dense_out))
    )

conv_out_scale = max_conv / 127.0
pool_out_scale = max_pool / 127.0
dense_out_scale = max_dense / 127.0

np.savez(
    "model_weights/scales.npz",

    input_scale = np.max(np.abs(x_train)) / 127.0,

    conv_weight_scale=
        np.max(np.abs(conv_weights))/127,

    dense_weight_scale=
        np.max(np.abs(dense_weights))/127,

    conv_out_scale=conv_out_scale,
    pool_out_scale=pool_out_scale,
    dense_out_scale=dense_out_scale
)