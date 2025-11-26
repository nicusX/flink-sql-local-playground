#!/bin/bash
# Flink 1.20.3 Version Configuration
# This file contains only essential metadata used by build and deployment scripts
# All dependency versions are hardwired in the Dockerfile

# Flink version information
FLINK_VERSION="1.20.3"              # Human-readable version
FLINK_VERSION_TAG="v1_20"           # Kubernetes operator flinkVersion field
FLINK_IMAGE_TAG="1.20.3"            # Docker image tag for flink-with-dependencies
FLINK_BASE_IMAGE="flink:1.20.3-scala_2.12-java11"  # Base image referenced in Dockerfile
