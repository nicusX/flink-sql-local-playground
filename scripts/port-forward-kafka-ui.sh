#!/bin/bash

# Port-forward script for Kafka UI
# This script ensures only one port-forward process is running for kafka-ui service

SERVICE_NAME="kafka-ui"
LOCAL_PORT=8080
SERVICE_PORT=8080

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
  echo "✓ Access Kafka UI at: http://localhost:${LOCAL_PORT}"
else
  echo "✗ Failed to start port-forward"
  exit 1
fi
