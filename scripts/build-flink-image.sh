#!/bin/bash

# Script to build and load custom Flink image with dependencies into minikube
# Always rebuilds the image to pick up any Dockerfile changes
# Docker's build cache makes this efficient when nothing has changed

set -e

IMAGE_NAME="flink-with-dependencies"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
DOCKERFILE="flink-custom-image/Dockerfile"

echo "===================================="
echo "Building Flink Custom Image"
echo "===================================="
echo ""

# Build the Docker image (always rebuild to catch Dockerfile changes)
echo "Building Docker image ${FULL_IMAGE_NAME}..."
echo "(Docker will use cache for unchanged layers)"

# Generate timestamp for this build
BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo "Build timestamp: ${BUILD_TIMESTAMP}"

# Build with timestamp argument to ensure timestamp layer is never cached
docker build --build-arg BUILD_TIMESTAMP=${BUILD_TIMESTAMP} -t ${FULL_IMAGE_NAME} -f ${DOCKERFILE} flink-custom-image

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
