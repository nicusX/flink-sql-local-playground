#!/bin/bash
# Flink 2.1.1 Version Configuration
# This file contains only essential metadata used by build and deployment scripts
# All dependency versions are hardwired in the Dockerfile

# Flink version information
FLINK_VERSION="2.1.1"               # Human-readable version
FLINK_VERSION_TAG="v2_1"            # Kubernetes operator flinkVersion field
FLINK_IMAGE_TAG="2.1.1"             # Docker image tag for flink-with-dependencies
FLINK_BASE_IMAGE="flink:2.1.1-scala_2.12-java17"  # Base image referenced in Dockerfile
