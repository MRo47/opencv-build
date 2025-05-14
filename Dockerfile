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
    ninja install'

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

# install NPU dependencies
ARG COMPILER_URL=https://github.com/intel/linux-npu-driver/releases/download/v1.17.0/intel-driver-compiler-npu_1.17.0.20250508-14912879441_ubuntu24.04_amd64.deb
ARG L0_NPU_URL=https://github.com/intel/linux-npu-driver/releases/download/v1.17.0/intel-level-zero-npu_1.17.0.20250508-14912879441_ubuntu24.04_amd64.deb
ARG L0_URL=https://github.com/oneapi-src/level-zero/releases/download/v1.21.9/level-zero_1.21.9+u24.04_amd64.deb

# Define temporary filenames for downloaded packages
ARG COMPILER_DEB="intel-driver-compiler-npu.deb"
ARG L0_NPU_DEB="intel-level-zero-npu.deb"
ARG L0_DEB="level-zero.deb"

RUN /bin/bash -c -x ' \
    apt update && \
    apt install -y --no-install-recommends wget ca-certificates libtbb12 && \
    wget -O "${COMPILER_DEB}" "${COMPILER_URL}" && \
    wget -O "${L0_NPU_DEB}" "${L0_NPU_URL}" && \
    wget -O "${L0_DEB}" "${L0_URL}" && \
    dpkg -i "${L0_DEB}" && \
    dpkg -i "${COMPILER_DEB}" "${L0_NPU_DEB}" && \
    apt install -y --fix-broken --no-install-recommends && \
    rm -f "${COMPILER_DEB}" "${L0_NPU_DEB}" "${L0_DEB}" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*'

# openvino env vars set by setupvars.sh
ENV INTEL_OPENVINO_DIR="${OPENVINO_INSTALL_DIR}"
ENV OpenVINO_DIR="${INTEL_OPENVINO_DIR}/runtime/cmake"
ARG OV_SYSTEM_ARCH="intel64"
ENV OV_PLUGINS_PATH="${INTEL_OPENVINO_DIR}/runtime/lib/${OV_SYSTEM_ARCH}"
ENV LD_LIBRARY_PATH="${OV_PLUGINS_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
ENV PKG_CONFIG_PATH="${OV_PLUGINS_PATH}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
ARG TBB_LIB_PATH="${INTEL_OPENVINO_DIR}/runtime/3rdparty/tbb/lib/"
ENV LD_LIBRARY_PATH="${TBB_LIB_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
ENV TBB_DIR="${INTEL_OPENVINO_DIR}/runtime/3rdparty/tbb/lib/cmake/tbb"
ARG OV_PYTHON_DIR="${INTEL_OPENVINO_DIR}/python"
ENV PYTHONPATH="${OV_PYTHON_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

# opencv env vars
ARG OPENCV_PYTHON_SITE="/opt/opencv-4.11.0/lib/python3.12/dist-packages"
ENV PYTHONPATH="${OPENCV_PYTHON_SITE}${PYTHONPATH:+:${PYTHONPATH}}"
ENV LD_LIBRARY_PATH="${OPENCV_INSTALL_PATH}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# remove sudo requirement for ubuntu user
RUN apt update && \
    apt install -y sudo && \
    rm -rf /var/lib/apt/lists/* && \
    (getent group ubuntu || groupadd -r ubuntu) && \
    (id -u ubuntu || useradd -r -g ubuntu -G sudo -s /bin/bash -m -d /home/ubuntu ubuntu)

# Configure sudo for no password for the 'ubuntu' user
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-nopasswd-ubuntu && \
    chmod 0440 /etc/sudoers.d/90-nopasswd-ubuntu

USER ubuntu
WORKDIR /app

# Example command
CMD ["/bin/bash"]