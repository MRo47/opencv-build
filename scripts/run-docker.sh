#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ENV_FILE="$SCRIPT_DIR/../.env"
CONTAINER_NAME="opencv_dev"

# --- Source environment variables ---
if [ -f "$ENV_FILE" ]; then
  echo "Sourcing environment variables from $ENV_FILE..."
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Error: Environment file '$ENV_FILE' not found."
  echo "Please create it with necessary variables like VIDEO_GROUPID, RENDER_GROUPID, and ensure DISPLAY is set. Run 'bash $SCRIPT_DIR/../scripts/export-env.sh' to generate it."
  exit 1
fi

# --- Validate required variables ---
: "${DISPLAY:?Error: DISPLAY environment variable is not set. Please set it in $ENV_FILE or your current environment.}"
: "${VIDEO_GROUPID:?Error: VIDEO_GROUPID environment variable is not set. Please set it in $ENV_FILE.}"
: "${RENDER_GROUPID:?Error: RENDER_GROUPID environment variable is not set. Please set it in $ENV_FILE.}"

# --- Docker Run Command ---
echo "Starting OpenCV development container..."

# Stop and remove if a container with the same name already exists
if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    echo "Stopping and removing existing container named '$CONTAINER_NAME'..."
    docker stop "$CONTAINER_NAME" >/dev/null
    docker rm "$CONTAINER_NAME" >/dev/null
fi

docker run \
    -it \
    --rm \
    --name "$CONTAINER_NAME" \
    --network host \
    --device "/dev/video0:/dev/video0" \
    --device "/dev/accel/accel0:/dev/accel/accel0" \
    --device "/dev/dri:/dev/dri" \
    --group-add "$VIDEO_GROUPID" \
    --group-add "$RENDER_GROUPID" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    -v "/dev/bus/usb:/dev/bus/usb" \
    -v "$SCRIPT_DIR/../opencv_ws:/home/ubuntu/opencv_ws" \
    -e "DISPLAY=$DISPLAY" \
    -e "QT_X11_NO_MITSHM=1" \
    ghcr.io/mro47/opencv-build:latest \
    bash


