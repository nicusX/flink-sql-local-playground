#!/bin/bash

# Shortcut to run the Flink SQL Client against the local Flink SQL Gateway

set -e

SQL_GATEWAY_ENDPOINT="${SQL_GATEWAY_ENDPOINT:=http://localhost:8083}"

# ----------------------------
# Check FLINK_HOME
# ----------------------------

if [ -z "$FLINK_HOME" ]; then
  echo "ERROR: FLINK_HOME is not set."
  echo "Please download and install Apache Flink locally, with version matching the playground's Flink version,"
  echo "then set the FLINK_HOME environment variable, e.g.:"
  echo
  echo "  export FLINK_HOME=/path/to/flink/distribution"
  echo
  exit 1
fi

SQL_CLIENT="$FLINK_HOME/bin/sql-client.sh"

# ----------------------------
# Check sql-client.sh exists
# ----------------------------

if [ ! -x "$SQL_CLIENT" ]; then
  echo "ERROR: $SQL_CLIENT not found or not executable."
  echo "Please ensure Apache Flink is installed locally and FLINK_HOME is correct."
  exit 1
fi

# ----------------------------
# Run SQL Client with extra args
# ----------------------------

echo "Starting Flink SQL Client from $FLINK_HOME"
echo "Gateway endpoint: $SQL_GATEWAY_ENDPOINT"
echo "Passing extra args: $*"
echo

exec "$SQL_CLIENT" gateway --endpoint "$SQL_GATEWAY_ENDPOINT" "$@"
