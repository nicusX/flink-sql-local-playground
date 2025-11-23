#!/bin/bash

# Port-forward script for Flink deployments
# This script ensures only one port-forward process is running for a given Flink deployment
#
# Usage: ./port-forward-flink-ui.sh <deployment-name> <local-port> <service-port>
#
# Arguments:
#   deployment-name:  Name of the Flink deployment (service name will be <deployment-name>-rest)
#   local-port:       Local port to bind on localhost
#   service-port:     Service port to forward to

# Check if all parameters are provided
if [ $# -ne 3 ]; then
  echo "Error: Missing required parameters"
  echo ""
  echo "Usage: $0 <deployment-name> <local-port> <service-port>"
  echo ""
  echo "Arguments:"
  echo "  deployment-name   Name of the Flink Deployment"
  echo "  local-port        Local port to bind on localhost"
  echo "  service-port      Flink REST Service port to forward to"
  echo ""
  echo "Example:"
  echo "  $0 session-deployment 8081 8081"
  echo ""
  echo "Note: The service name is automatically constructed as <deployment-name>-rest"
  exit 1
fi

DEPLOYMENT_NAME="$1"
LOCAL_PORT="$2"
SERVICE_PORT="$3"

# Construct service name by appending "-rest" to deployment name
SERVICE_NAME="${DEPLOYMENT_NAME}-rest"

echo "Setting up port-forward for ${SERVICE_NAME}..."

# Find and kill any existing port-forward processes for this service
EXISTING_PIDS=$(ps aux | grep "kubectl port-forward.*${SERVICE_NAME}" | grep -v grep | awk '{print $2}')

if [ ! -z "$EXISTING_PIDS" ]; then
  echo "Found existing port-forward process(es): $EXISTING_PIDS"
  echo "Killing existing process(es)..."
  echo "$EXISTING_PIDS" | xargs kill
  sleep 2
  echo "Existing process(es) killed."
else
  echo "No existing port-forward process found."
fi

# Start new port-forward process in background
echo "Starting new port-forward on localhost:${LOCAL_PORT}..."
kubectl port-forward svc/${SERVICE_NAME} ${LOCAL_PORT}:${SERVICE_PORT} > /dev/null 2>&1 &
NEW_PID=$!

# Wait a moment to check if the process started successfully
sleep 2

# Verify the process is running
if ps -p $NEW_PID > /dev/null 2>&1; then
  echo "✓ Port-forward started successfully (PID: ${NEW_PID})"
  echo "✓ Access Flink UI at: http://localhost:${LOCAL_PORT}"
else
  echo "✗ Failed to start port-forward"
  exit 1
fi
