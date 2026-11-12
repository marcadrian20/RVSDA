#!/usr/bin/env python3
# coding: utf-8

import cv2
import numpy as np
import socket
import struct
import time

 
# Ip Config for pynq
PYNQ_IP = "192.168.2.99"
PORT = 12345

latencies = []
MAX_SAMPLES = 100

def prepare_image(frame):
    #Convert to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    #Square crop at high resolution
    h, w = gray.shape
    size = min(h, w)
    top = (h - size) // 2
    left = (w - size) // 2
    cropped = gray[top:top+size, left:left+size]
    
    #Apply Adaptive Thresholding (handle shadows prod binary inv pic)
    thresh = cv2.adaptiveThreshold(
        cropped, 
        255, 
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
        cv2.THRESH_BINARY_INV, #Flip dark ink on white paper to white on black
        21, 
        4
    )
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel) #cleanup noise and artifs
    thickened = cv2.dilate(cleaned, kernel, iterations=2) #compensate fr thin line/make lines tihcker
    #Resize the clean binary image to 28x28
    resized = cv2.resize(thickened, (28, 28), interpolation=cv2.INTER_AREA)
    #Convert to float32 scaled between 0.0 and 1.0, normalizare
    img_float = resized.astype(np.float32) / 255.0
    return img_float

 
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Cannot open camera")
    exit()

print("Press 'q' to quit.")

while True:
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((PYNQ_IP, PORT))
        print(f"Connected to PYNQ at {PYNQ_IP}:{PORT}")
    except Exception as e:
        print(f"Connection failed: {e}")
        time.sleep(1)
        continue

    # Keep sending frames as long as the socket is alive
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        img_float = prepare_image(frame)
        disp = (img_float * 255).astype(np.uint8)
        cv2.imshow(
            "Processed",
            cv2.resize(
                disp,
                (280,280),
                interpolation=cv2.INTER_NEAREST
            )
        )       
        cv2.waitKey(1)  
        print(f"Sent image: min={np.min(img_float):.3f}, max={np.max(img_float):.3f}, mean={np.mean(img_float):.3f}")
        try:
            #start = time.perf_counter()
            sock.sendall(img_float.tobytes())

            # Wait for prediction (1 byte)
            pred_bytes = sock.recv(1)
            #end = time.perf_counter()
            #latency_ms = (end - start) * 1000
            #latencies.append(latency_ms)
            #print(f"Latency: {latency_ms:.2f} ms")

            # if len(latencies) == MAX_SAMPLES:
            #     avg_latency = sum(latencies) / len(latencies)
            #     print(f"\nAverage latency over {MAX_SAMPLES} frames: {avg_latency:.2f} ms\n")
            #     latencies.clear()
            if not pred_bytes:
                print("Server closed connection")
                break
            pred = struct.unpack('B', pred_bytes)[0]
            if pred == 255:
                print("Server reported error")
                pred = -1
            
        except (ConnectionResetError, BrokenPipeError, socket.error) as e:
            print(f"Socket error: {e}, reconnecting...")
            sock.close()
            break

        # Show result
        display = cv2.resize(frame, (640, 480))
        cv2.putText(display, f"Prediction: {pred}", (10, 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 2)
        cv2.imshow("MNIST Camera", display)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            cap.release()
            cv2.destroyAllWindows()
            sock.close()
            exit()

    # If we broke out of the inner loop, close the socket and try to reconnect
    sock.close()
    print("Reconnecting in 1 second...")
    time.sleep(1)
