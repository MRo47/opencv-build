# OpenCV Build

This repository provides scripts and Dockerfiles to simplify building OpenCV from source on Ubuntu. The build includes the contrib and non-free modules, and is compiled with support for OpenVINO, ONNX Runtime, LAPACK, and TBB for enhanced performance and capabilities.

## Prebuilt Docker image

A prebuilt Docker image is available at `ghcr.io/mro47/opencv-build:latest`.

To pull the latest image, run the following command

```bash
docker pull ghcr.io/mro47/opencv-build:latest
```

You can use the prebuilt image in the following ways:

> __NOTE__: running the image will require permissions to system hardware inside the container. Run the script in scripts/export-env.sh to generate the .env file, before using the prebuilt image.

### 1. Run using docker compose

The `docker-compose.yml` file is configured to use the prebuilt image.
*   `docker compose up -d`: This command starts the services defined in your `docker-compose.yml` file in detached mode (`-d`), meaning the containers run in the background. In this case, it will pull and run the `opencv_dev` service using the prebuilt image.

```bash
docker compose up -d
```
*   `docker exec -it opencv_dev bash`: This command executes an interactive bash shell (`bash`) inside the running `opencv_dev` container. This allows you to work within the container's environment.

```bash
docker exec -it opencv_dev bash
```

> __NOTE__: If you are using VSCode and have the `Dev Containers` extension installed, you can connect to the OpenCV development container directly from within VSCode by clicking the `><` icon in the bottom left corner, then attach to running container, then select `opencv_dev` container.

Learn more about Docker Compose: [https://docs.docker.com/compose/](https://docs.docker.com/compose/)

### 2. Using docker run

A convenience script `scripts/run-docker.sh` is provided to run the Docker container directly using `docker run` with the necessary arguments (like volume mounts and environment variables from the `.env` file).

Run the script, which will drop user into the container's shell
```bash
bash scripts/run-docker.sh
```

## Build from source

To build OpenCV from source along with its dependencies, you can use the convenience script `scripts/build-opencv.sh`. This script automates the entire build process as defined in the Dockerfile and installs dependencies but runs it on your host machine.

## Test installation

This repository includes a test script `test_dnn.py` to verify the OpenCV installation along with its OpenVINO and ONNX Runtime integrations. The script loads a YOLO-NAS object detection model `yolo_nas_s.onnx` using OpenCV's DNN module and performs a dummy inference. The model file is managed using Git LFS.

To download the model file, ensure you have Git LFS installed and then pull the LFS files from the root of this repository:
```bash
git lfs install
git lfs pull
```
This will download the model to `opencv_ws/models/yolo_nas_s.onnx`.

> __NOTE__: models have a different license than this repository. The original license can be found at https://github.com/Deci-AI/super-gradients/blob/master/LICENSE.YOLONAS.md

### Running the test script:

*   **Inside the Docker Container:**
    After accessing the container's shell (e.g., via `docker exec -it opencv_dev bash`), the workspace is mounted at `/home/ubuntu/opencv_ws`.
    ```bash
    cd /home/ubuntu/opencv_ws
    python3 test_dnn.py --model_path models/yolo_nas_s.onnx --input_width 640 --input_height 640 --input_channels 3
    ```

*   **Locally (after building on host):**
    If you built OpenCV locally using `scripts/build-opencv.sh`, the OpenCV libraries and necessary environment variables should be configured. You might need to open a new terminal or source your `~/.bashrc` (or equivalent) file if the build script modified it.
    From the root of this repository:
    ```bash
    cd opencv_ws
    python3 test_dnn.py --model_path models/yolo_nas_s.onnx --input_width 640 --input_height 640 --input_channels 3
    ```

## Related work
The openvino backend helps optimise deep learning inference tasks: [yolo_nas_cpp](https://github.com/MRo47/yolo_nas_cpp)