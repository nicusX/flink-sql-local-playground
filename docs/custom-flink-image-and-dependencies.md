# Custom Flink Image and Dependencies


The custom Flink images extend the official Flink base images with additional dependencies required for working with Kafka and Avro data formats.

**Available images:**
- `flink-with-dependencies:1.20.3` - extends `flink:1.20.3-scala_2.12-java11`
- `flink-with-dependencies:2.1.1` - extends `flink:2.1.1-scala_2.12-java17`

This custom image is used for both Flink Deployment and SQL Gateway. 
The SQL Gateway also needs these dependencies for planning and validation of SQL queries.

## Dependency Management Strategy

The image uses a **hybrid approach** to eliminate manual transitive dependency tracking:

1. **SQL Connector Uber JARs**: Pre-bundled JARs that include all their transitive dependencies (e.g., `flink-sql-connector-kafka`)
2. **Uber JAR including transitive dependencies**: Use Maven to automatically resolve complex transitive dependencies (e.g., Confluent Schema Registry client)
   and build a single Uber JAR.
3. **Simple wget**: Direct download for standalone JARs without complex dependencies

This approach ensures all required dependencies are included without manual tracking of transitive dependencies like Jackson libraries, while keeping the Docker image reasonably sized.

## How the Build Works

The Dockerfile uses a **multi-stage build**:

1. **Stage 1 (Maven)**: Resolves transitive dependencies defined in `pom.xml`
2. **Stage 2 (Flink)**:
   - Downloads SQL connector uber JARs
   - Downloads Avro format JARs
   - Copies Maven-resolved dependencies
   - Creates final Flink image

**Note:** The version-specific custom image is rebuilt every time you set up the playground (or you run `scripts/build-flink-image.sh`). 

## How to Add New Dependencies

If you need to add any new dependency, edit the version-specific `Dockerfile` (in `flink-versions/{VERSION}/`) or `pom.xml`, then rebuild the image and redeploy SQL Gateway and Session cluster using `rebuild-flink-image-and-redeploy.sh` with the appropriate `--flink-version` parameter.  

### For Flink Connectors with Uber JARs

If a SQL connector uber JAR exists (e.g., `flink-sql-connector-elasticsearch`):

1. Edit the version-specific Dockerfile (e.g., `flink-versions/1.20.3/Dockerfile`)
2. Add a wget command with the appropriate connector version:
   ```dockerfile
   RUN wget -P /opt/flink/lib \
       https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-NAME/VERSION/flink-sql-connector-NAME-VERSION.jar
   ```
3. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh --flink-version=1.20.3`

### For Dependencies with Complex Transitive Dependencies

If you need a library with many transitive dependencies:

1. Edit the version-specific `pom.xml` (e.g., `flink-versions/1.20.3/pom.xml`) and add the dependency
2. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh --flink-version=1.20.3`

### For Standalone JARs

For simple JARs without transitive dependencies:

1. Edit the version-specific Dockerfile (e.g., `flink-versions/1.20.3/Dockerfile`)
2. Add a wget command in the appropriate section
3. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh --flink-version=1.20.3`

