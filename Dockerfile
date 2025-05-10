# Stage 1: Builder
FROM ubuntu:24.04 AS builder

ARG OPENCV_VERSION="4.11.0"
ARG OPENVINO_VERSION="2025.1"
ARG OPENVINO_TAG="2025.1.0.18503.6fec06580ab_x86_64"
ARG ONNX_VERSION="1.21.0"

ENV OPENCV_INSTALL_PATH="/opt/opencv-${OPENCV_VERSION}"
ENV OPENVINO_INSTALL_DIR="/opt/intel/openvino_${OPENVINO_VERSION}"
ENV ONNX_ROOT_DIR="/opt/onnxruntime"

# Install build dependencies, development libraries, and Python 3
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    wget \
    ca-certificates \
    unzip \
    cmake \
    ninja-build \
    build-essential \
    pkg-config \
    libgtk-3-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libopenblas-dev \
    liblapacke-dev \
    libeigen3-dev \
    ffmpeg \
    intel-opencl-icd \
    libva-dev \
    libmfx-dev \
    python3 \
    python3-dev \
    python3-numpy \
    libtbb-dev \
    libprotobuf-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Download and extract OpenCV and Contrib sources
WORKDIR /app
RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
    unzip opencv.zip && rm opencv.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
    unzip opencv_contrib.zip && rm opencv_contrib.zip

# Install OpenVINO
RUN wget -O openvino.tgz https://storage.openvinotoolkit.org/repositories/openvino/packages/${OPENVINO_VERSION}/linux/openvino_toolkit_ubuntu24_${OPENVINO_TAG}.tgz && \
    tar -xvf openvino.tgz && rm openvino.tgz && \
    mkdir -p ${OPENVINO_INSTALL_DIR} && \
    mv openvino_toolkit_ubuntu24_${OPENVINO_TAG}/* ${OPENVINO_INSTALL_DIR}/ && \
    rm -rf openvino_toolkit_ubuntu24_${OPENVINO_TAG}

# Install ONNX Runtime
RUN wget -O onnx.tgz "https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz" && \
    tar -xvf onnx.tgz && rm onnx.tgz && \
    mkdir -p ${ONNX_ROOT_DIR} && \
    mv "onnxruntime-linux-x64-${ONNX_VERSION}"/* ${ONNX_ROOT_DIR}/ && \
    rm -rf "onnxruntime-linux-x64-${ONNX_VERSION}" && \
    bash -x ${OPENVINO_INSTALL_DIR}/install_dependencies/install_openvino_dependencies.sh -y

# Handle potential LAPACK symlink issue for OPENCV: https://github.com/opencv/opencv/issues/12957
# Check if the target file exists before creating the symlink
RUN if [ -f /usr/include/x86_64-linux-gnu/cblas.h ]; then \
        ln -s /usr/include/x86_64-linux-gnu/cblas.h /usr/include/cblas.h; \
    fi

# Configure, build, and install OpenCV
WORKDIR /app/build
RUN /bin/bash -c ' \
    source "${OPENVINO_INSTALL_DIR}/setupvars.sh" && \
    cmake \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${OPENCV_INSTALL_PATH} \
        -DOPENCV_EXTRA_MODULES_PATH=/app/opencv_contrib-${OPENCV_VERSION}/modules \
        -DOPENCV_ENABLE_NONFREE=ON \
        -DOPENCV_IPP_ENABLE_ALL=ON \
        -DWITH_OPENVINO=ON \
        -DWITH_CUDA=OFF \
        -DWITH_CUDNN=OFF \
        -DWITH_ONNX=ON \
        -DDNN_ENABLE_ONNX_RUNTIME=ON \
        -DONNXRT_ROOT_DIR=${ONNX_ROOT_DIR} \
        -DWITH_PROTOBUF=ON \
        -DBUILD_opencv_python3=ON \
        -DBUILD_UNGUI_PYTHON=ON \
        -DBUILD_DOCS=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        -DWITH_OPENMP=ON \
        -DWITH_TBB=ON \
        -DWITH_VA=ON \
        -DWITH_VA_INTEL=ON \
        -DWITH_MFX=ON \
        -DWITH_EIGEN=ON \
        -DWITH_LAPACK=ON \
        -DWITH_GTK=ON \
        -DBUILD_NEW_PYTHON_SUPPORT=ON \
        -DCMAKE_PREFIX_PATH="${ONNX_ROOT_DIR};${OPENVINO_INSTALL_DIR};/usr" \
        -DBUILD_opencv_gapi=OFF \
        /app/opencv-${OPENCV_VERSION} && \
    ninja -j$(nproc) && \
    ninja install
'

# Stage 2: Runtime
FROM ubuntu:24.04

ARG OPENCV_VERSION="4.11.0"
ARG OPENVINO_VERSION="2025.1"
ARG ONNX_VERSION="1.12.0"

ENV OPENCV_INSTALL_PATH="/opt/opencv-${OPENCV_VERSION}"
ENV OPENVINO_INSTALL_DIR="/opt/intel/openvino_${OPENVINO_VERSION}"
ENV ONNX_ROOT_DIR="/opt/onnxruntime"

COPY --from=builder ${OPENCV_INSTALL_PATH} ${OPENCV_INSTALL_PATH}
COPY --from=builder ${OPENVINO_INSTALL_DIR} ${OPENVINO_INSTALL_DIR}
COPY --from=builder ${ONNX_ROOT_DIR} ${ONNX_ROOT_DIR}

# Install runtime dependencies
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    libgtk-3-0 \
    libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libavcodec60 \
    libavformat60 \
    libavutil58 \
    libswscale7 \
    libswresample4 \
    libopenblas0 \
    liblapack3 \
    libeigen3-dev \
    ffmpeg \
    intel-opencl-icd \
    python3 \
    python3-numpy \
    libtbb12 \
    libva2 \
    libmfx1 \
    libwebpdemux2 \
    libprotobuf32t64 && \
    bash -x /opt/intel/openvino_2025.1/install_dependencies/install_openvino_dependencies.sh -y && \
    rm -rf /var/lib/apt/lists/*

# Create an entrypoint for setting up the environment
RUN cat <<'EOF' > /usr/local/bin/docker-entrypoint.sh
#!/bin/bash
set -e

# Find Python site-packages path in the runtime image to set PYTHONPATH
SYSTEM_PYTHON_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])")
export PYTHONPATH=$SYSTEM_PYTHON_SITE:$PYTHONPATH

# Find opencv site-packages path in the runtime image to set PYTHONPATH
OPENCV_PYTHON_SITE=$(find "${OPENCV_INSTALL_PATH}" -name "cv2" -prune -exec dirname {} \; 2>/dev/null)
export PYTHONPATH=$OPENCV_PYTHON_SITE:$PYTHONPATH

# Source the OpenVINO setup
source "${OPENVINO_INSTALL_DIR}/setupvars.sh" || exit 1

# Add OpenCV libs to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${OPENCV_INSTALL_PATH}/lib:$LD_LIBRARY_PATH

echo "Entrypoint ready, running: $@"

# Check if any arguments were passed
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
EOF

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

WORKDIR /app

# Example command
CMD ["/bin/bash"]