#!/bin/bash

echo "WARN: Ensure NPU drivers for linux (https://github.com/intel/linux-npu-driver/releases) are installed on the host if you intend to use NPU device."
echo "Only the fw-npu package is required to be installed on host. Restart the machine if you just installed the package."
echo "Then run this script again to generate the .env file."
echo "Ignore this warning if you don't intend to use NPU device or have drivers installed."

ENV_FILE="../.env"

echo "DISPLAY=${DISPLAY}" > ${ENV_FILE}
echo "VIDEO_GROUPID=$(getent group video | cut -d: -f3)" >> ${ENV_FILE}
echo "RENDER_GROUPID=$(getent group render | cut -d: -f3)" >> ${ENV_FILE}