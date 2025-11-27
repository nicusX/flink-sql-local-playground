# ============================================================================
# Flink 2.1.1 Custom Image with Kafka and Avro Dependencies
# ============================================================================
# This Dockerfile is for Flink version 2.1.1 specifically.
# All dependency versions are hardwired for this Flink version.
# For other Flink versions, see sibling directories under flink-versions/
# ============================================================================
#
# Base image: flink:2.1.1-scala_2.12-java17
#
# Uses a hybrid approach for dependency management:
# - SQL connector uber JARs (flink-sql-connector-kafka) that bundle most dependencies
# - Simple wget for Avro format JARs
# - Maven auto-resolution for Confluent Schema Registry transitive dependencies
#
# This approach eliminates manual transitive dependency tracking while keeping
# the Docker image reasonably sized.
#
# Dependencies included:
# - flink-sql-connector-kafka: Kafka source/sink uber JAR (bundles kafka-clients + deps)
# - flink-avro: Avro format support
# - flink-sql-avro-confluent-registry: SQL support for Avro with Schema Registry
# - Maven-resolved: kafka-schema-registry-client, and their transitive deps

# ============================================================================
# Stage 1: Maven dependency resolution
# ============================================================================
FROM maven:3.9-eclipse-temurin-17 AS maven-resolver

WORKDIR /build

# Copy pom.xml for dependency resolution
COPY pom.xml .

# Download and resolve all transitive dependencies
# This layer is cached unless pom.xml changes
RUN mvn dependency:copy-dependencies \
    -DoutputDirectory=target/flink-lib \
    -DincludeScope=runtime

# ============================================================================
# Stage 2: Final Flink image
# ============================================================================
FROM flink:2.1.1-scala_2.12-java17

# Build argument for timestamp - this ensures the timestamp layer is never cached
ARG BUILD_TIMESTAMP=unknown

# Download SQL Kafka Connector (uber JAR with bundled dependencies)
# Using Flink 2.0 connector version 4.0.0-2.0 (compatible with Flink 2.1.x)
RUN wget -P /opt/flink/lib \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/4.0.0-2.0/flink-sql-connector-kafka-4.0.0-2.0.jar

# Download Avro format support JARs
RUN wget -P /opt/flink/lib \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-avro/2.1.1/flink-avro-2.1.1.jar && \
    wget -P /opt/flink/lib \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-avro-confluent-registry/2.1.1/flink-avro-confluent-registry-2.1.1.jar && \
    wget -P /opt/flink/lib \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/2.1.1/flink-sql-avro-confluent-registry-2.1.1.jar

# Copy Maven-resolved dependencies (Confluent Schema Registry + Jackson + transitive deps)
COPY --from=maven-resolver /build/target/flink-lib/*.jar /opt/flink/lib/

# Verify critical JARs are present
RUN ls -lh /opt/flink/lib/flink-sql-connector-kafka-4.0.0-2.0.jar && \
    ls -lh /opt/flink/lib/flink-avro-2.1.1.jar && \
    ls -lh /opt/flink/lib/flink-avro-confluent-registry-2.1.1.jar && \
    ls -lh /opt/flink/lib/flink-sql-avro-confluent-registry-2.1.1.jar && \
    echo "✓ All dependencies present" && \
    echo ""

# Add timestamp file to track when image was built
# This helps verify that the latest image is being used in Kubernetes pods
# Using BUILD_TIMESTAMP arg ensures this layer is never cached
RUN touch /opt/flink/modified-${BUILD_TIMESTAMP} && \
    echo "Build timestamp: ${BUILD_TIMESTAMP}" && \
    ls -lh /opt/flink/modified-*
