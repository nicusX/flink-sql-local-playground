#!/bin/bash

# Script to rebuild the custom Flink image and redeploy all Flink components
# This ensures that the latest Docker image is used by Kubernetes
#
# Usage: ./rebuild-flink-image-and-redeploy.sh [--flink-version=VERSION]
# Example: ./rebuild-flink-image-and-redeploy.sh --flink-version=2.1.1
#
# Order of operations:
# 1. Delete deployments FIRST (frees up containers using the old image)
# 2. Wait for pods to be fully terminated
# 3. Rebuild image (can now successfully remove old image from minikube)
# 4. Recreate deployments (will use the new image)
# 5. Restart port-forwards

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
      echo "Example: $0 --flink-version=2.1.1"
      exit 1
      ;;
  esac
done

# Validate Flink version exists
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

echo "====================================="
echo "Rebuild and Redeploy Flink"
echo "====================================="
echo "Flink Version: ${FLINK_VERSION}"
echo ""

# Step 1: Delete existing deployments FIRST
# This is crucial - we must delete deployments before rebuilding the image
# so that containers release the old image in minikube
echo "====================================="
echo "Step 1: Deleting existing deployments"
echo "====================================="
echo ""

kubectl delete flinkdeployment session-deployment --ignore-not-found=true
kubectl delete deployment flink-sql-gateway --ignore-not-found=true

echo "Waiting for pods to terminate (15 seconds)..."
sleep 15

# Step 2: Rebuild the custom Flink image
# Now that containers are deleted, minikube can remove the old image
echo ""
echo "====================================="
echo "Step 2: Rebuilding custom Flink image"
echo "====================================="
echo ""
./scripts/build-flink-image.sh --flink-version=${FLINK_VERSION}

# Step 3: Recreate deployments
echo ""
echo "====================================="
echo "Step 3: Recreating deployments"
echo "====================================="
echo ""

kubectl apply -f "${VERSION_DIR}/k8s/session-deployment.yaml"
kubectl apply -f "${VERSION_DIR}/k8s/sql-gateway.yaml"

echo ""
echo "Waiting for deployments to be ready..."
echo "(This may take a few minutes...)"
echo ""

# Wait for FlinkDeployment to be stable
echo "Waiting for session-deployment..."
kubectl wait --for=jsonpath='{.status.lifecycleState}'=STABLE flinkdeployment/session-deployment --timeout=300s 2>/dev/null || echo "Note: FlinkDeployment status check timed out or unavailable, continuing..."

# Wait for SQL Gateway deployment to be available
echo "Waiting for flink-sql-gateway..."
kubectl wait --for=condition=Available deployment/flink-sql-gateway --timeout=300s

# Step 4: Restart port-forwards
echo ""
echo "====================================="
echo "Step 4: Restarting port-forwards"
echo "====================================="
echo ""

echo "Restarting Flink UI port-forward..."
./scripts/port-forward-flink-ui.sh session-deployment 8081 8081

echo "Restarting SQL Gateway port-forward..."
./scripts/port-forward-sql-gateway.sh

echo ""
echo "====================================="
echo "✓ Rebuild and Redeploy Complete!"
echo "====================================="
echo ""
echo "Services are now accessible at:"
echo "  - Flink UI: http://localhost:8081"
echo "  - SQL Gateway: http://localhost:8083"
echo ""
echo "To verify deployments:"
echo "  kubectl get flinkdeployment session-deployment"
echo "  kubectl get deployment flink-sql-gateway"
echo "  kubectl get pods"
echo ""
echo "To verify image build timestamp:"
echo "  kubectl exec deployment/flink-sql-gateway -- sh -c 'ls -lh /opt/flink/modified-*'"
