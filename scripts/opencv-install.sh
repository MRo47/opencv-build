#!/bin/bash

OPENCV_VERSION="4.11.0"
OPENCV_INSTALL_PATH="/opt/opencv-${OPENCV_VERSION}"

OPENVINO_INSTALL_PATH="/opt/intel/openvino_2025"
OPENVINO_VERSION="2025.1"
OPENVINO_TAG="2025.1.0.18503.6fec06580ab_x86_64"

# ONNX_VERSION="gpu-1.12.0" # for gpu
ONNX_VERSION="1.12.0"
ONNX_ROOT_DIR="/opt/onnxruntime"

### install openvino

wget -O openvino.tgz https://storage.openvinotoolkit.org/repositories/openvino/packages/${OPENVINO_VERSION}/linux/openvino_toolkit_ubuntu24_${OPENVINO_TAG}.tgz
tar -xvf openvino.tgz
sudo mkdir -p ${OPENEVINO_INSTALL_DIR}
sudo mv openvino_toolkit_ubuntu24_${OPENVINO_TAG}/* ${OPENEVINO_INSTALL_DIR}
rm -rf openvino_toolkit_ubuntu24_${OPENVINO_TAG} openvino.tgz
cd ${OPENEVINO_INSTALL_DIR}
sudo -E ${OPENVINO_INSTALL_PATH}/install_dependencies/install_openvino_dependencies.sh
source ${OPENEVINO_INSTALL_DIR}/setupvars.sh

### end openvino install

### install onnx runtime

wget -O onnx.tgz "https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz"
tar -xvf onnx.tgz
sudo mv "onnxruntime-linux-x64-${ONNX_VERSION}/*" ${ONNX_ROOT_DIR}
rm -rf onnxruntime-linux-x64-${ONNX_VERSION} onnx.tgz

### end onnx install

### install other dependencies

sudo apt install -y \
    ninja-build \
    intel-opencl-icd \
    libopenblas-dev \
    liblapacke-dev \
    ffmpeg \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libgtk-3-dev \
    libeigen3-dev \
    libtbb-dev \
    libprotobuf-dev \
    python3-dev \
    python3-numpy \
    ffmpeg \
    intel-opencl-icd \

# lapack path issue https://github.com/opencv/opencv/issues/12957
# sudo ln -s /usr/include/lapacke.h /usr/include/x86_64-linux-gnu
      
# Check if the target file exists before creating the symlink
if [ -f /usr/include/x86_64-linux-gnu/cblas.h ]; then
    sudo ln -s /usr/include/x86_64-linux-gnu/cblas.h /usr/include/cblas.h
fi

### end install other dependencies

### install opencv

# fetch opencv
wget -O opencv.zip https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip
wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip
unzip opencv.zip
unzip opencv_contrib.zip

# python paths
# Find Python 3 paths (run these commands and use their output)
PYTHON3_EXECUTABLE=$(which python3)
PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON3_LIBRARY=$(python3 -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR') + '/' + sysconfig.get_config_var('LDVERSION') + sysconfig.get_config_var('ABIFLAGS') + sysconfig.get_config_var('EXT_SUFFIX'))" | sed 's/\.so.*/\.so/')
PYTHON3_PACKAGES_PATH=$(python3 -c "import site; print(site.getusersitepackages())") # Or site.getsitepackages()[0] if installing as root

echo "PYTHON3_EXECUTABLE: $PYTHON3_EXECUTABLE"
echo "PYTHON3_INCLUDE_DIR: $PYTHON3_INCLUDE_DIR"
echo "PYTHON3_LIBRARY: $PYTHON3_LIBRARY"
echo "PYTHON3_PACKAGES_PATH: $PYTHON3_PACKAGES_PATH"

mkdir -p build && cd build

# configure build

# Find CUDA arch (compute capability) for your specific GPU(s)
# Look up your GPU model online or use nvidia-smi to find its compute capability
# Examples: Pascal (6.x), Volta (7.0), Turing (7.5), Ampere (8.x)
# Use dot notation or remove dot, e.g., 7.5 -> 75.
# If you have multiple GPUs, list them separated by spaces or commas: "75 86"
# CUDA_ARCH="75 86" # <<< CHANGE THIS TO MATCH YOUR GPU(s)
# -DWITH_CUDA=ON \
# -DWITH_CUDNN=ON \
# -DWITH_CUBLAS=ON \
# -DOPENCV_DNN_CUDA=ON \ Enable CUDA backend. CUDA, CUBLAS and CUDNN must be installed. 
# -DCUDA_ARCH_BIN="${CUDA_ARCH}" \
# -DBUILD_DOCS Enable documentation build (doxygen, doxygen_cpp, doxygen_python, doxygen_javadoc targets). Doxygen must be installed for C++ documentation build. Python and BeautifulSoup4 must be installed for Python documentation build.
# -DENABLE_PYLINT=ON \ Enable python scripts check with Pylint (check_pylint target). Pylint must be installed. 
# -DENABLE_FLAKE8=ON \ Enable python scripts check with Flake8 (check_flake8 target). Flake8 must be installed. 
# -DDNN_PLUGIN_LIST=openvino,onnx,ocl4dnn \
# -DWITH_MFX=ON \ intel media SDK with VA api fo video decoding

cmake \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${OPENCV_INSTALL_PATH} \
    -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib-${OPENCV_VERSION}/modules \
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
    -DWITH_EIGEN=ON \
    -DWITH_LAPACK=ON \
    -DWITH_GTK=ON \
    -DBUILD_NEW_PYTHON_SUPPORT=ON \
    -DCMAKE_PREFIX_PATH="${ONNX_ROOT_DIR};${OPENVINO_INSTALL_PATH};/usr" \
    -DBUILD_opencv_gapi=OFF \
    ../opencv-${OPENCV_VERSION}

# Build and install
ninja -j$(nproc)
sudo ninja install

# cleanup
cd .. # back from build
rm -rf opencv-${OPENCV_VERSION} opencv_contrib-${OPENCV_VERSION} build opencv.zip opencv_contrib.zip

# Add to shellrc file

# check shell and add to shell file, only zsh and bash supported
if [ "$(basename "$0")" = "zsh" ]; then
    SHELLRC=~/.zshrc
elif [ "$(basename "$0")" = "bash" ]; then
    SHELLRC=~/.bashrc
fi

echo "export LD_LIBRARY_PATH=${OPENCV_INSTALL_PATH}/lib:\$LD_LIBRARY_PATH" >> "$SHELLRC"
echo "source ${OPENVINO_INSTALL_PATH}/setupvars.sh" >> "$SHELLRC"
source $SHELLRC