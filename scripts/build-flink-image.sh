#!/bin/bash

# Script to build and load custom Flink image with dependencies into minikube
# Always rebuilds the image to pick up any Dockerfile changes
# Docker's build cache makes this efficient when nothing has changed
#
# Usage: ./build-flink-image.sh [--flink-version=VERSION]
# Example: ./build-flink-image.sh --flink-version=2.1.1

set -e

# Default Flink version
FLINK_VERSION="1.20.3"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --flink-version=*)
      FLINK_VERSION="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--flink-version=VERSION]"
      exit 1
      ;;
  esac
done

# Validate version exists
VERSION_DIR="flink-versions/${FLINK_VERSION}"
if [ ! -d "$VERSION_DIR" ]; then
    echo "Error: Unsupported Flink version: ${FLINK_VERSION}"
    echo ""
    echo "Available versions:"
    ls -1 flink-versions/ 2>/dev/null || echo "  (none found)"
    exit 1
fi

# Load version-specific configuration
CONFIG_FILE="${VERSION_DIR}/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

source "$CONFIG_FILE"

# Set build variables
IMAGE_NAME="flink-with-dependencies"
IMAGE_TAG="${FLINK_IMAGE_TAG}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
DOCKERFILE="${VERSION_DIR}/Dockerfile"
BUILD_CONTEXT="${VERSION_DIR}"

echo "===================================="
echo "Building Flink Custom Image"
echo "===================================="
echo "Flink Version: ${FLINK_VERSION}"
echo "Image Tag: ${FULL_IMAGE_NAME}"
echo "Base Image: ${FLINK_BASE_IMAGE}"
echo ""

# Build the Docker image (always rebuild to catch Dockerfile changes)
echo "Building Docker image ${FULL_IMAGE_NAME}..."
echo "(Docker will use cache for unchanged layers)"

# Generate timestamp for this build
BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo "Build timestamp: ${BUILD_TIMESTAMP}"

# Build with timestamp argument to ensure timestamp layer is never cached
docker build \
    --build-arg BUILD_TIMESTAMP=${BUILD_TIMESTAMP} \
    --build-arg FLINK_VERSION=${FLINK_VERSION} \
    -t ${FULL_IMAGE_NAME} \
    -f ${DOCKERFILE} \
    ${BUILD_CONTEXT}

if [ $? -eq 0 ]; then
    echo "✓ Docker image built successfully"
else
    echo "✗ Failed to build Docker image"
    exit 1
fi

echo ""

# Remove old cached image from minikube
echo "Removing old cached image from minikube (if exists)..."
minikube image rm docker.io/library/${FULL_IMAGE_NAME} 2>/dev/null || true
echo "✓ Old cached image removed (or didn't exist)"

echo ""

# Load image into minikube
echo "Loading image into minikube..."
minikube image load ${FULL_IMAGE_NAME}

if [ $? -eq 0 ]; then
    echo "✓ Image loaded into minikube successfully"
else
    echo "✗ Failed to load image into minikube"
    exit 1
fi

echo ""

# Verify image is in minikube
echo "Verifying image in minikube..."
if minikube image ls | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
    echo "✓ Image ${FULL_IMAGE_NAME} is available in minikube"
    echo ""
    echo "===================================="
    echo "✓ Image Build Complete!"
    echo "===================================="
else
    echo "✗ Image verification failed"
    exit 1
fi
