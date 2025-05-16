import argparse
import os
import traceback
from itertools import product
from time import time

import cv2
import numpy as np
import openvino as ov

backends = ["opencv", "openvino"]

def convert_to_openvino(onnx_file):
    if not os.path.isfile(onnx_file):
        raise FileNotFoundError(f"Model file not found: {onnx_file}")
    model_path_no_suffix = onnx_file.removesuffix('.onnx')
    model = ov.convert_model(onnx_file)
    xml_path = f"{model_path_no_suffix}.xml"
    bin_path = f"{model_path_no_suffix}.bin"
    ov.serialize(model, xml_path, bin_path)
    return xml_path, bin_path

def get_available_devices():
    core = ov.Core()
    available_devices = core.available_devices
    print("Available OpenVINO devices:")
    if available_devices:
        for d in available_devices:
            print(f"- {d}")
    else:
        print("No OpenVINO devices found.")
    return available_devices

def load_model(model_path, backend_name):
    if backend_name == 'openvino':
        xml_path, bin_path = convert_to_openvino(model_path)
        return cv2.dnn.readNet(xml_path, bin_path)
    elif backend_name == 'opencv':
        return cv2.dnn.readNet(model_path)

def main(model_path, input_width, input_height, input_channels):
    devices = get_available_devices()

    target = None
    for device, backend_name in product(devices, backends):
        if backend_name == 'openvino':
            backend = cv2.dnn.DNN_BACKEND_INFERENCE_ENGINE
        elif backend_name == 'opencv':
            backend = cv2.dnn.DNN_BACKEND_OPENCV
        else:
            continue

        if device == 'CPU':
            target = cv2.dnn.DNN_TARGET_CPU
        elif device == 'GPU':
            target = cv2.dnn.DNN_TARGET_OPENCL
        else:
            continue

        print(f"Trying {backend_name} with {device}")

        try:
            net = load_model(model_path, backend_name)
            net.setPreferableBackend(backend)
            net.setPreferableTarget(target)
            
            # Retrieve input layer information
            input_layer_names = net.getLayerNames()
            input_blob_names = net.getUnconnectedOutLayersNames()
            input_blob = input_blob_names[0]  # Assuming single input

            input_shape = (1, input_channels, input_height, input_width)

            dummy_input = np.random.rand(*input_shape).astype(np.float32)
            net.setInput(dummy_input)

            # warmup
            for _ in range(5):
                net.setInput(dummy_input)
                output = net.forward()

            # Run forward pass
            time_start = time()
            net.setInput(dummy_input)
            output = net.forward()
            time_end = time()
            time_delta = time_end - time_start
            print(f"Time taken: {time_delta*1000.0} ms, FPS: {1.0/time_delta}")

            # Display output shape
            print(f"Output shape: {output.shape}")

        except Exception as e:
            print(f"An error occurred: {e}")
            traceback.print_exc()
            exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", type=str, required=True, help="Path to the ONNX model file")
    parser.add_argument("--input_width", type=int, default=640, help="Network input width")
    parser.add_argument("--input_height", type=int, default=640, help="Network input height")
    parser.add_argument("--input_channels", type=int, default=3, help="Network input channels")
    args = parser.parse_args()
    main(args.model_path, args.input_width, args.input_height, args.input_channels)
