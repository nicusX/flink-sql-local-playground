#!/bin/bash

# Script to stop all kubectl port-forward processes running in background

echo "Stopping all kubectl port-forward processes..."
echo ""

# Find all kubectl port-forward processes
PORT_FORWARD_PIDS=$(ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print $2}')

if [ -z "$PORT_FORWARD_PIDS" ]; then
  echo "No kubectl port-forward processes found running."
  exit 0
fi

# Display the processes that will be killed
echo "Found the following kubectl port-forward process(es):"
ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print "  PID: " $2 " - " $11 " " $12 " " $13 " " $14}'
echo ""

# Kill all port-forward processes
echo "Killing process(es)..."
echo "$PORT_FORWARD_PIDS" | xargs kill

# Wait a moment for processes to terminate
sleep 1

# Verify they are stopped
REMAINING_PIDS=$(ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print $2}')

if [ -z "$REMAINING_PIDS" ]; then
  echo "✓ All kubectl port-forward processes stopped successfully."
else
  echo "⚠ Some processes may still be running. Attempting force kill..."
  echo "$REMAINING_PIDS" | xargs kill -9
  sleep 1
  echo "✓ Force kill completed."
fi

echo ""
echo "All port-forwards have been stopped."
