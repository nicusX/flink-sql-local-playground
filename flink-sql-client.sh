#!/bin/bash

# Shortcut to run the Flink SQL Client against the local Flink SQL Gateway

set -e

FLINK_VERSION="${FLINK_VERSION:=1.20.3}"
SQL_GATEWAY_ENDPOINT="${SQL_GATEWAY_ENDPOINT:=http://localhost:8083}"

# ----------------------------
# Check FLINK_HOME
# ----------------------------

if [ -z "$FLINK_HOME" ]; then
  echo "ERROR: FLINK_HOME is not set."
  echo "Please download and install Apache Flink $FLINK_VERSION locally,"
  echo "then set the FLINK_HOME environment variable, e.g.:"
  echo
  echo "  export FLINK_HOME=/path/to/flink-$FLINK_VERSION"
  echo
  exit 1
fi

SQL_CLIENT="$FLINK_HOME/bin/sql-client.sh"

# ----------------------------
# Check sql-client.sh exists
# ----------------------------

if [ ! -x "$SQL_CLIENT" ]; then
  echo "ERROR: $SQL_CLIENT not found or not executable."
  echo "Please ensure Apache Flink $FLINK_VERSION is installed locally and FLINK_HOME is correct."
  echo
  echo "Download Flink $FLINK_VERSION from:"
  echo "  https://www.apache.org/dyn/closer.lua/flink/flink-$FLINK_VERSION/"
  echo
  echo "Then set FLINK_HOME, for example:"
  echo "  export FLINK_HOME=/path/to/flink-$FLINK_VERSION"
  echo
  exit 1
fi

# ----------------------------
# Run SQL Client with extra args
# ----------------------------

echo "Starting Flink SQL Client (Flink $FLINK_VERSION)"
echo "Gateway endpoint: $SQL_GATEWAY_ENDPOINT"
echo "Passing extra args: $*"
echo

exec "$SQL_CLIENT" gateway --endpoint "$SQL_GATEWAY_ENDPOINT" "$@"
