#!/usr/bin/env python3
# coding: utf-8

import cv2
import numpy as np
import socket
import struct
import time

# IP Config for PYNQ
PYNQ_IP = "192.168.1.104"
PORT = 12345

MAX_SAMPLES = 1000

capture_times = []
preprocess_times = []
send_times = []
receive_times = []
total_times = []

def prepare_image(frame):
    # Convert to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Square crop
    h, w = gray.shape
    size = min(h, w)
    top = (h - size) // 2
    left = (w - size) // 2
    cropped = gray[top:top + size, left:left + size]

    # Adaptive threshold
    thresh = cv2.adaptiveThreshold(
        cropped,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        21,
        4
    )

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    thickened = cv2.dilate(cleaned, kernel, iterations=2)

    # Resize
    resized = cv2.resize(thickened, (28, 28), interpolation=cv2.INTER_AREA)

    # Normalize
    img_float = resized.astype(np.float32) / 255.0

    return img_float


cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Cannot open camera")
    exit(1)

print(f"Collecting {MAX_SAMPLES} samples...")

samples = 0

while samples < MAX_SAMPLES:

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((PYNQ_IP, PORT))
        print(f"Connected to PYNQ at {PYNQ_IP}:{PORT}")
        break
    except Exception as e:
        print(f"Connection failed: {e}")
        time.sleep(1)

while samples < MAX_SAMPLES:

    try:
        # ---------------- Capture ----------------
        t0 = time.perf_counter()
        ret, frame = cap.read()
        t1 = time.perf_counter()

        if not ret:
            print("Camera capture failed.")
            break

        # ---------------- Preprocess ----------------
        img_float = prepare_image(frame)
        t2 = time.perf_counter()

        # ---------------- Send ----------------
        sock.sendall(img_float.tobytes())
        t3 = time.perf_counter()

        # ---------------- Receive ----------------
        pred_bytes = sock.recv(1)
        t4 = time.perf_counter()

        if not pred_bytes:
            print("Server closed connection.")
            break

        pred = struct.unpack("B", pred_bytes)[0]

        if pred == 255:
            pred = -1

        # ---------------- Store timings ----------------
        capture_times.append((t1 - t0) * 1000.0)
        preprocess_times.append((t2 - t1) * 1000.0)
        send_times.append((t3 - t2) * 1000.0)
        receive_times.append((t4 - t3) * 1000.0)
        total_times.append((t4 - t0) * 1000.0)

        samples += 1

        if samples % 100 == 0:
            print(f"{samples}/{MAX_SAMPLES} samples")

    except (ConnectionResetError, BrokenPipeError, socket.error) as e:
        print(f"Socket error: {e}")
        break

print("\n   Performance   ")
print(f"Samples        : {samples}")
print(f"Capture        : {np.mean(capture_times):8.3f} ms")
print(f"Preprocessing  : {np.mean(preprocess_times):8.3f} ms")
print(f"Send           : {np.mean(send_times):8.3f} ms")
print(f"Receive        : {np.mean(receive_times):8.3f} ms")
print("---------------------------------")
print(f"End-to-End     : {np.mean(total_times):8.3f} ms")
print("\n")

cap.release()
sock.close()
cv2.destroyAllWindows()