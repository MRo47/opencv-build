#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error when substituting.
set -o pipefail # Causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value.

export DEBIAN_FRONTEND=noninteractive

# --- Configuration Variables (from Dockerfile ARGs) ---
OPENCV_VERSION="4.11.0"
OPENVINO_VERSION="2025.1"
OPENVINO_TAG="2025.1.0.18503.6fec06580ab_x86_64" # Make sure this matches your architecture
ONNX_VERSION="1.21.0" # Using builder's ONNX version for compilation

# NPU Driver URLs
COMPILER_URL="https://github.com/intel/linux-npu-driver/releases/download/v1.17.0/intel-driver-compiler-npu_1.17.0.20250508-14912879441_ubuntu24.04_amd64.deb"
L0_NPU_URL="https://github.com/intel/linux-npu-driver/releases/download/v1.17.0/intel-level-zero-npu_1.17.0.20250508-14912879441_ubuntu24.04_amd64.deb"
L0_URL="https://github.com/oneapi-src/level-zero/releases/download/v1.21.9/level-zero_1.21.9+u24.04_amd64.deb"

# NPU Temporary filenames
COMPILER_DEB="intel-driver-compiler-npu.deb"
L0_NPU_DEB="intel-level-zero-npu.deb"
L0_DEB="level-zero.deb"

# --- Installation Paths (from Dockerfile ENV) ---
export OPENCV_INSTALL_PATH="/opt/opencv-${OPENCV_VERSION}"
export OPENVINO_INSTALL_DIR="/opt/intel/openvino_${OPENVINO_VERSION}"
export ONNX_ROOT_DIR="/opt/onnxruntime"

# Temporary build directory
BUILD_DIR="/tmp/opencv_build_$$"
mkdir -p "${BUILD_DIR}"
# trap 'echo ">>> Cleaning up ${BUILD_DIR}"; rm -rf "${BUILD_DIR}"; echo ">>> Cleanup complete."' EXIT # Cleanup on exit

echo ">>> Starting OpenCV and dependencies installation..."
echo ">>> OpenCV Version: ${OPENCV_VERSION}"
echo ">>> OpenVINO Version: ${OPENVINO_VERSION}"
echo ">>> ONNX Runtime Version: ${ONNX_VERSION}"
echo ">>> OpenCV Install Path: ${OPENCV_INSTALL_PATH}"
echo ">>> OpenVINO Install Path: ${OPENVINO_INSTALL_DIR}"
echo ">>> ONNX Runtime Install Path: ${ONNX_ROOT_DIR}"
echo ">>> Temporary Build Directory: ${BUILD_DIR}"
echo ""
echo ">>> This script will require sudo privileges for package installation and writing to /opt."
read -p ">>> Press Enter to continue or Ctrl+C to abort..."

# --- 1. Install Build Dependencies ---
echo ">>> Installing build dependencies..."
sudo apt update
sudo apt install -y --no-install-recommends \
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
    libwebpdemux2 \


echo ">>> Build dependencies installed."

# --- 2. Download and Extract OpenCV and Contrib Sources ---
echo ">>> Downloading and extracting OpenCV sources..."
cd "${BUILD_DIR}"
wget -O opencv.zip "https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip"
unzip opencv.zip && rm opencv.zip
wget -O opencv_contrib.zip "https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip"
unzip opencv_contrib.zip && rm opencv_contrib.zip
echo ">>> OpenCV sources downloaded and extracted."

# --- 3. Install OpenVINO ---
echo ">>> Installing OpenVINO..."
cd "${BUILD_DIR}"
wget -O openvino.tgz "https://storage.openvinotoolkit.org/repositories/openvino/packages/${OPENVINO_VERSION}/linux/openvino_toolkit_ubuntu24_${OPENVINO_TAG}.tgz"
tar -xvf openvino.tgz && rm openvino.tgz
sudo mkdir -p "${OPENVINO_INSTALL_DIR}"
sudo mv "openvino_toolkit_ubuntu24_${OPENVINO_TAG}"/* "${OPENVINO_INSTALL_DIR}/"
sudo rm -rf "openvino_toolkit_ubuntu24_${OPENVINO_TAG}"
# Install OpenVINO dependencies (first time, from builder stage logic)
echo ">>> Installing OpenVINO dependencies (pass 1)..."
sudo bash "${OPENVINO_INSTALL_DIR}/install_dependencies/install_openvino_dependencies.sh" -y
echo ">>> OpenVINO installed to ${OPENVINO_INSTALL_DIR}."

# --- 4. Install ONNX Runtime ---
echo ">>> Installing ONNX Runtime..."
cd "${BUILD_DIR}"
wget -O onnx.tgz "https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz"
tar -xvf onnx.tgz && rm onnx.tgz
sudo mkdir -p "${ONNX_ROOT_DIR}"
sudo mv "onnxruntime-linux-x64-${ONNX_VERSION}"/* "${ONNX_ROOT_DIR}/"
sudo rm -rf "onnxruntime-linux-x64-${ONNX_VERSION}"
echo ">>> ONNX Runtime installed to ${ONNX_ROOT_DIR}."

# --- 5. Handle LAPACK Symlink Issue ---
echo ">>> Checking and creating LAPACK symlink if needed..."
if [ -f /usr/include/x86_64-linux-gnu/cblas.h ]; then
    if [ ! -L /usr/include/cblas.h ] && [ ! -f /usr/include/cblas.h ]; then
        sudo ln -s /usr/include/x86_64-linux-gnu/cblas.h /usr/include/cblas.h
        echo ">>> Symlink /usr/include/cblas.h created."
    elif [ -L /usr/include/cblas.h ]; then
        echo ">>> Symlink /usr/include/cblas.h already exists."
    else
        echo ">>> File /usr/include/cblas.h exists and is not a symlink. Skipping."
    fi
else
    echo ">>> /usr/include/x86_64-linux-gnu/cblas.h not found. Skipping LAPACK symlink."
fi

# --- 6. Configure, Build, and Install OpenCV ---
echo ">>> Configuring, building, and installing OpenCV..."
cd "${BUILD_DIR}"
mkdir -p build && cd build


echo ">>> Sourcing OpenVINO setupvars.sh for OpenCV build..."
source "${OPENVINO_INSTALL_DIR}/setupvars.sh"
echo ">>> Running CMake for OpenCV..."
cmake \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${OPENCV_INSTALL_PATH}" \
    -DOPENCV_EXTRA_MODULES_PATH="${BUILD_DIR}/opencv_contrib-${OPENCV_VERSION}/modules" \
    -DOPENCV_ENABLE_NONFREE=ON \
    -DOPENCV_IPP_ENABLE_ALL=ON \
    -DWITH_OPENVINO=ON \
    -DWITH_CUDA=OFF \
    -DWITH_CUDNN=OFF \
    -DWITH_ONNX=ON \
    -DDNN_ENABLE_ONNX_RUNTIME=ON \
    -DONNXRT_ROOT_DIR="${ONNX_ROOT_DIR}" \
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
    -DCMAKE_PREFIX_PATH="${ONNX_ROOT_DIR};${OPENVINO_INSTALL_DIR}/runtime/cmake;/usr" \
    -DBUILD_opencv_gapi=OFF \
    "${BUILD_DIR}/opencv-${OPENCV_VERSION}"

echo ">>> Building OpenCV with Ninja (using $(nproc) cores)..."
ninja -j"$(nproc)"

echo ">>> Installing OpenCV with Ninja..."
sudo ninja install

echo ">>> OpenCV installed to ${OPENCV_INSTALL_PATH}."

# --- 7. Install NPU Dependencies ---
echo ">>> Installing NPU dependencies..."
cd "${BUILD_DIR}"

echo ">>> Downloading NPU .deb packages..."
wget -O "${COMPILER_DEB}" "${COMPILER_URL}"
wget -O "${L0_NPU_DEB}" "${L0_NPU_URL}"
wget -O "${L0_DEB}" "${L0_URL}"

echo ">>> Installing NPU .deb packages..."
sudo dpkg -i "${L0_DEB}"
sudo dpkg -i "${COMPILER_DEB}" "${L0_NPU_DEB}" || echo "DPKG install had errors, attempting to fix..."

echo ">>> Fixing broken dependencies if any..."
sudo apt install -y --fix-broken --no-install-recommends

echo ">>> Cleaning up NPU .deb packages..."
rm -f "${COMPILER_DEB}" "${L0_NPU_DEB}" "${L0_DEB}"
echo ">>> NPU dependencies installed."


# --- 9. Environment Variables Setup ---
PYTHON_EXECUTABLE=$(which python3)
PYTHON_VERSION_MAJOR_MINOR=$($PYTHON_EXECUTABLE -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
OPENCV_PYTHON_SITE="${OPENCV_INSTALL_PATH}/lib/python${PYTHON_VERSION_MAJOR_MINOR}/dist-packages"

echo ""
echo ">>> Installation complete!"
echo ""
echo ">>> To use the installed libraries, you need to set up environment variables."
echo ">>> Add the following lines to your ~/.bashrc or ~/.zshrc file:"
echo ""
echo "# --- OpenCV, OpenVINO, ONNX Runtime Environment ---"
echo "source \"${OPENVINO_INSTALL_DIR}/setupvars.sh\""
echo "export PYTHONPATH=\"${OPENCV_PYTHON_SITE}\${PYTHONPATH:+:\$PYTHONPATH}\""
echo "export LD_LIBRARY_PATH=\"${OPENCV_INSTALL_PATH}/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
echo "export PKG_CONFIG_PATH=\"${OPENCV_INSTALL_PATH}/lib/pkgconfig\${PKG_CONFIG_PATH:+:\$PKG_CONFIG_PATH}\""
echo "export ONNX_ROOT_DIR=\"${ONNX_ROOT_DIR}\""
echo "# --- End Environment ---"
echo ""
echo ">>> After adding them, run: source ~/.bashrc (or ~/.zshrc)"
echo ">>> You can verify python imports with: "
echo ">>> python3 -c 'import cv2; print(cv2.__version__)'"
echo ">>> python3 -c 'from openvino.runtime import Core; print(Core().available_devices)'"
echo ">>> python3 -c 'import onnxruntime; print(onnxruntime.__version__)'"
echo ""
echo ">>> Temporary build files are in ${BUILD_DIR}. You can remove this directory manually if desired:"
echo ">>> sudo rm -rf ${BUILD_DIR}"
echo ">>> Script finished."

    

IGNORE_WHEN_COPYING_START


source "${OPENVINO_INSTALL_DIR}/setupvars.sh"
export PYTHONPATH=${OPENCV_PYTHON_SITE}:${PYTHONPATH}
export LD_LIBRARY_PATH="${OPENCV_INSTALL_PATH}/lib":${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH="${OPENCV_INSTALL_PATH}/lib/pkgconfig":${PKG_CONFIG_PATH}
export ONNX_ROOT_DIR=${ONNX_ROOT_DIR}