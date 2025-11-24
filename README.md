# Flink SQL Playground

This project allows you to set up a simple local playground to experiment with Flink SQL (Flink 1.20)

A local Kubernetes cluster (Minikube) runs: a Flink cluster in session mode, Flink SQL Gateway, a Kafka cluster, Schema Registry, Kafka UI.

You can use Flink SQL CLI to run interactive SQL on the cluster.

Kafka UI and Flink UI are also exposed on localhost, to help with the experimentation.

The [sql-examples](./sql-examples/) folder contains some examples of SQL jobs (WIP).


## Quick Start

1. Verify you meet all [prerequisites](#prerequisites)
2. Install the required [Helm repositories](#install-helm-repositories)
3. Run the setup script for [Flink SQL Playground quick setup](#flink-sql-playground-quick-setup)
4. Start the [Flink SQL Client](#start-flink-sql-client) and start interacting with the cluster
5. [Delete the Playground](#delete-the-playground) when you have finished

---

## Prerequisites

- macOS (for this guide)
- Homebrew package manager
- Docker Desktop (for minikube) - must be running with sufficient resource limits (see [Create Kubernetes cluster](#11-create-kubernetes-cluster), below)
- Minikube
- Helm
- Local installation of a Flink distribution matching the Flink version used in the playground (see [Install Flink Distribution](#install-flink-distribution))

**Note**: while it should easily work on Linux and Windows machines too, this playground has been tested on macOS only.

### Version Information

- Kubernetes: v1.28.0
- Helm: v4.0.0
- cert-manager: v1.19.1
- Flink Kubernetes Operator: v1.13.0
- Flink: v1.20.3


### Install Flink Distribution

To use the Flink SQL Client from your host machine, you need to have the Flink distribution installed locally and the `FLINK_HOME` environment variable configured.

> ⚠️ **Important:** make sure your local Flink distribution is Flink 1.20.x. The Flink SQL client version 2.x or earlier than 1.20 may not work with Flink 1.20.3 used in the playground.

**Download and extract Flink distribution:**

Move to the folder where you want to install the Flink distribution.

```bash
curl -L -O https://archive.apache.org/dist/flink/flink-1.20.3/flink-1.20.3-bin-scala_2.12.tgz
tar -xzf flink-1.20.3-bin-scala_2.12.tgz
```

**Set the FLINK_HOME environment variable:**

For the current terminal session:

```bash
export FLINK_HOME="$(pwd)/flink-1.20.3"
```

To make this permanent, add the export statement to your shell profile (`~/.zshrc` for zsh or `~/.bash_profile` for bash):

```bash
echo 'export FLINK_HOME=<flink-distro-dir>' >> ~/.zshrc
source ~/.zshrc
```
Replace `<flink-distro-dir>` with the directory where you installed the Flink distribution

**Verify the installation:**

```bash
echo $FLINK_HOME
# Should output the absolute path where the Flink distribution has been installed
```


## Install Helm Repositories

Add the Jetstack Helm repository:
```bash
helm repo add jetstack https://charts.jetstack.io
```

Add the Flink operator Helm repository:
```bash
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.13.0/
```

**Make sure Helm repositories are up to date:**

```bash
helm repo update
```

---

## Flink SQL Playground: Quick Setup

To quickly set up the Flink SQL playground use the following:

```bash
./setup-flink-sql-playground.sh
```

The playground includes:
1. The minikube cluster
2. Custom Flink Docker image with Kafka connector
3. Cert-manager
4. Flink Operator
5. Kafka ecosystem: Kafka cluster, Kafka UI, and Schema Registry
6. Flink Session cluster, with 2 task managers
7. Flink SQL Gateway
8. Port-forward for Flink UI, Kafka UI, and SQL Gateway

**Note**: the script is idempotent. It creates components only if required.

### Docker Resources

The Minikube cluster requires a minimum amount of resources available to Docker.
With the current setup these are:
- 6 CPU
- 10 GiB memory

Your Docker Desktop resource limits must be higher than or equal to the resources dedicated to minikube.
The setup script automatically checks Docker resources before starting Minikube.
You can check the limits set to Docker with: `docker info | grep -E "CPUs|Total Memory"`

See [Modifying Resource Requirements](#modifying-resource-requirements) to change the resources dedicated to the various components.


### Minikube Dashboard

Open the Minikube K8s Dashboard in the browser:

```bash
minikube dashboard
```


### Stop (pause) the playground

Stop the minikube cluster (without deleting any component): `minikube stop`

Stop the port-forward processes (running in background): `./scripts/stop-all-port-forwards.sh`

Restart the playground and port-forwards: `./setup-flink-sql-playground.sh` 

### Delete the playground

Delete the minikube cluster: `minikube delete` or `./delete-flink-sql-playground.sh`

---

## Flink SQL Playground: Manual Step-by-Step Setup

As an alternative to using the `./setup-flink-sql-playground.sh` script, you can manually set up each component of the playground by following the step-by-step instructions in this chapter.

### 1. Setup the Minikube cluster

#### 1.1. Create Kubernetes Cluster

Create a minikube cluster with Kubernetes v1.28.0 (required for compatibility with Flink Operator v1.13.0), with a specific amount of resources. 
For example, to set up a cluster with 6 CPU and 10GiB use:

```bash
minikube start --kubernetes-version=v1.28.0 --cpus=6 --memory=10g
```

#### 1.2. Install cert-manager

cert-manager is required by the Flink Kubernetes Operator for webhook certificate management.

**Note**: Flink Operator 1.13 [Flink Operator Quick Start](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.13/docs/try-flink-kubernetes-operator/quick-start/) instruct to install cert-manager v1.18.2 via YAML manifest. However, this causes a `CreateContainerConfigError` due to security context issues, when installing on Minikube. Installing from the full Jetstack Helm repo avoid this problem.

Install cert-manager:
```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify cert-manager is running:
```bash
kubectl get pods -n cert-manager
```

All three pods should show `1/1` in the READY column:
- cert-manager
- cert-manager-cainjector
- cert-manager-webhook

#### 1.3. Install Flink Kubernetes Operator

Install the Flink Kubernetes Operator:
```bash
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
```

Verify the operator is running:
```bash
kubectl get pods -n default
```

The flink-kubernetes-operator pod should show `2/2` in the READY column.

#### 1.4. Verify Installation

Check all pods across all namespaces:
```bash
kubectl get pods -A
```

You should see:
- cert-manager pods (3) in `cert-manager` namespace
- flink-kubernetes-operator pod (1) in `default` namespace
- Core Kubernetes components in `kube-system` namespace


### 2. Build Custom Flink Docker Image

The Flink session cluster uses a custom Docker image (`flink-with-dependencies:latest`) that extends the official Flink image with additional dependencies for Kafka and Avro support. See [Custom Flink Image Dependencies](#custom-flink-image-dependencies) for details on the included JARs.

**Using the build script (recommended):**

```bash
./scripts/build-flink-image.sh
```

The script will:
- Build the Docker image `flink-with-dependencies:latest`
- Load it into minikube's image cache
- Verify the image is available
- Use Docker's build cache for efficient rebuilds when nothing changes

**Manual build (alternative):**

If you prefer to build and load the image manually:

```bash
# Build the custom image
docker build -t flink-with-dependencies:latest -f flink-custom-image/Dockerfile flink-custom-image

# Load the image into minikube
minikube image load flink-with-dependencies:latest

# Verify the image is loaded
minikube image ls | grep flink-with-dependencies
```

You should see `docker.io/library/flink-with-dependencies:latest` in the output.


### 4. Deploy a Flink Session Cluster with fixed TaskManagers and SQL Gateway

In this section we deploy a Flink session cluster with standby task managers and SQL gateway.
It allows experimenting with interactive SQL statements.

#### 4.1. Deploy Flink Session Cluster

First, deploy a Flink session cluster that will accept SQL queries:

```bash
kubectl apply -f k8s/session-deployment.yaml
```

This creates a Flink cluster named `session-deployment` with no pre-loaded jobs, ready to accept job submissions via the SQL Gateway.

Verify the deployment:

```bash
kubectl get flinkdeployment session-deployment
```

The deployment should show `LIFECYCLE STATE` as `STABLE`.


#### 4.2. Expose Flink UI for the Flink Deployment to the Host Machine

The Flink UI can be easily exposed on localhost using `kubectl port-forward`.

**Note:** Note, each FlinkDeployment creates a separate Flink cluster with a Job Manager, with a separate ClusterIP Service named `<flink-deployment-name>-rest`
for the Flink REST API and UI.
If you have more than one  FlinkDeployment, you need to create a separate port-forward for each deployment.

**Using the convenience script (recommended):**

```bash
./scripts/port-forward-flink-ui.sh <deployment-name> <local-port> <service-port>
```

Where `<deployment-name>` is the name of the FlinkDeployment which deploys the specific cluster.

The Session cluster deployed in this playground is called `session-deployment` and it creates  `session-deployment-rest` service on port `8081`. The full command to expose it's Flink UI is the following:

```bash
./scripts/port-forward-flink-ui.sh session-deployment 8081 8081
```


**Note**: this script automatically kills any existing port-forward processes for the Flink UI and starts a new one in the background.

**Manual setup:**

```bash
kubectl port-forward svc/<deployment-name>-rest 8081:8081
```

Example:
```bash
kubectl port-forward svc/session-deployment-rest 8081:8081
```

**This command must be kept running** - it will block the terminal and continue forwarding traffic. You have two options:
- Run it in a separate terminal window/tab
- Run it in the background by adding `&` at the end: `kubectl port-forward svc/session-deployment-rest 8081:8081 &`

Then access the Flink UI at: **http://localhost:8081**

**Important Note:**
When you modify and redeploy a FlinkDeployment (e.g., changing resource allocations), the Flink operator creates a new pod and terminates the old one. This breaks the port-forward connection since it was connected to the specific pod. You will need to manually restart the port-forward command after each deployment update.

##### Why Ingress doesn't work with minikube on macOS

When using minikube with the Docker driver on macOS (the default setup), the Kubernetes cluster runs inside a Docker container, 
creating network isolation between your host machine and the cluster. This presents several challenges for Ingress:

1. **Network Accessibility**: On macOS, you cannot directly access the minikube cluster's IP address from your host machine 
   (unlike Linux where `minikube ip` is directly accessible)
2. **Ingress Controller Requirements**: Even if you install an Ingress controller (like NGINX Ingress), it would only be accessible within the Docker network, 
   not from your host
3. **DNS Resolution**: Ingress relies on host-based routing (using hostnames), but DNS resolution and routing from macOS host to the containerized cluster 
   is not straightforward


#### 4.3. Deploy SQL Gateway

The Flink SQL Gateway provides a REST API for executing SQL queries against your Flink session cluster. 
This allows you to use the Flink SQL Client from your host machine to interact with the cluster.

The SQL Gateway deployment is defined in `k8s/sql-gateway.yaml` and is configured to connect to the `session-deployment` cluster. Deploy it with:

```bash
kubectl apply -f k8s/sql-gateway.yaml
```

This creates:
- A ConfigMap with SQL Gateway configuration
- A Deployment running the SQL Gateway service
- A ClusterIP Service exposing port 8083

**Note**: `sql-gateway.yaml` has a hardwired dependency on the name of the service which deploys the Flink session cluster (`session-deployment`).


##### Verify SQL Gateway is Running

Check the pod status:

```bash
kubectl get pods -l app=flink-sql-gateway
```

The pod should show `1/1` in the READY column.

Check the logs to verify startup:

```bash
kubectl logs -l app=flink-sql-gateway
```

You should see a message like: `Rest endpoint listening at 0.0.0.0:8083`

#### 4.4. Expose SQL Gateway to the Host Machine

Similarly to what has been done for the Flink UI, the SQL Gateway is exposed to localhost using port-forward.

**Note:** The SQL Gateway port-forward is independent of the Flink session cluster. 
If you modify the `session-deployment` FlinkDeployment, you only need to restart the Flink UI port-forward (port 8081), 
not the SQL Gateway port-forward (port 8083). However, if you redeploy the SQL Gateway itself, you will need to restart its port-forward.

**Using the convenience script (recommended):**

```bash
./scripts/port-forward-sql-gateway.sh
```

This script automatically kills any existing port-forward processes for the SQL Gateway and starts a new one in the background.

**Manual setup:**

```bash
kubectl port-forward svc/flink-sql-gateway 8083:8083
```

**This command must be kept running** - it will block the terminal and continue forwarding traffic. You have two options:
- Run it in a separate terminal window/tab
- Run it in the background by adding `&` at the end: `kubectl port-forward svc/flink-sql-gateway 8083:8083 &`

Verify the API is accessible:

```bash
curl http://localhost:8083/v1/info
```

Expected response:
```json
{"productName":"Apache Flink","version":"1.20.3"}
```

### 5. Deploy Kafka Ecosystem

This section covers the deployment and usage of Apache Kafka with Schema Registry and Kafka UI.
The Kafka cluster can be used as a data source and sink for Flink jobs.

#### 5.1. Overview

The Kafka ecosystem deployment includes:
- **Kafka Cluster**: 3-node Kafka cluster running in KRaft mode (without Zookeeper)
- **Schema Registry**: Confluent Schema Registry for managing Avro/JSON/Protobuf schemas
- **Kafka UI**: Web-based interface for managing and monitoring Kafka

#### 5.2. Deploying the Kafka Ecosystem

Deploy all components with a single command:

```bash
kubectl apply -f k8s/kafka.yaml
```

This creates:
- A 3-broker Kafka cluster (kafka-0, kafka-1, kafka-2) using StatefulSet
- A Schema Registry instance
- A Kafka UI instance
- All necessary services for internal and external access

Verify the deployment:

```bash
# Check Kafka pods
kubectl get pods -l app=kafka

# Check Schema Registry
kubectl get pods -l app=schema-registry

# Check Kafka UI
kubectl get pods -l app=kafka-ui
```

All pods should show `1/1` in the READY column.

#### 5.3. Accessing Kafka from Inside the Kubernetes Cluster

When connecting to Kafka from Flink jobs or other applications running inside the Kubernetes cluster, use the following service addresses.

**Assumption:** The examples below assume Kafka clients (Flink jobs, applications) are running in the same namespace as the Kafka cluster (`default` namespace). If your clients run in a different namespace, use fully qualified domain names (e.g., `kafka-0.kafka.default.svc.cluster.local:9092`).

##### Kafka Brokers

**Bootstrap Servers:**

Kafka clients connect to bootstrap servers to discover the cluster topology, then connect directly to individual brokers as needed.
For production use, always specify all brokers for redundancy:

```
kafka-0.kafka:9092,kafka-1.kafka:9092,kafka-2.kafka:9092
```

**Example Flink Configuration:**
```yaml
spec:
  flinkConfiguration:
    pipeline.name: my-flink-job
  job:
    args:
      - "--kafka.bootstrap.servers"
      - "kafka-0.kafka:9092,kafka-1.kafka:9092,kafka-2.kafka:9092"
```

##### Schema Registry

Access the Schema Registry API from inside the cluster (same namespace):
```
http://schemaregistry:8082
```

**Example usage in Flink job:**
```yaml
- "--schema.registry.url"
- "http://schemaregistry:8082"
```

#### 5.4. Accessing Kafka UI from Host Machine

The Kafka UI provides a web interface for managing topics, viewing messages, monitoring consumer groups, and managing schemas.

##### Using the Port-Forward Script

A convenience script is provided to expose Kafka UI to your host machine:

```bash
./scripts/port-forward-kafka-ui.sh
```

This script:
- Automatically kills any existing port-forward processes for Kafka UI
- Starts a new port-forward in the background
- Exposes Kafka UI on `http://localhost:8080`

##### Manual Port-Forward

Alternatively, you can manually set up port-forwarding:

```bash
kubectl port-forward svc/kafka-ui 8080:8080
```

**This command must be kept running** - it will block the terminal and continue forwarding traffic. You have two options:
- Run it in a separate terminal window/tab
- Run it in the background by adding `&` at the end

##### Accessing the Kafka UI

Once port-forwarding is active, access Kafka UI at: **http://localhost:8080**

From the UI you can:
- View and manage Kafka topics
- Inspect messages in topics
- Monitor consumer groups and lag
- View broker configurations
- Manage schemas via Schema Registry integration

#### 5.5. Kafka Cluster Configuration

The Kafka cluster is configured for experimental use with minimal resource requirements:

**Resources per broker:**
- Memory request: 512Mi
- Memory limit: 768Mi
- CPU request: 250m
- CPU limit: 500m
- JVM heap: 256MB

**Cluster settings:**
- Mode: KRaft (no Zookeeper)
- Replication factor: 3
- Min in-sync replicas: 2
- Auto topic creation: Enabled
- Persistent storage: 10Gi per broker

**Note:** These resource limits are intentionally minimal because this playground is for development and testing purposes only.

#### 5.6. Verifying the Kafka Cluster

Check cluster health:

```bash
# View Kafka pod status
kubectl get pods -l app=kafka

# Check Kafka logs
kubectl logs kafka-0

# Verify all brokers are running
kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092
```

Test topic creation and messaging:

```bash
# Create a test topic
kubectl exec -it kafka-0 -- kafka-topics --create --topic test-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 3

# List topics
kubectl exec -it kafka-0 -- kafka-topics --list --bootstrap-server localhost:9092

# Produce a message
echo "test message" | kubectl exec -i kafka-0 -- kafka-console-producer --topic test-topic --bootstrap-server localhost:9092

# Consume messages
kubectl exec -it kafka-0 -- kafka-console-consumer --topic test-topic --from-beginning --bootstrap-server localhost:9092 --max-messages 1
```

#### 5.7. Verifying Schema Registry

The Schema Registry is normally not exposed to the host. To be able to access the endpoint from the host a port-forward is required. 


Check Schema Registry health (Schema Registry is not exposed on localhost, you can activate a temporary port-forward to test it):

```bash
# Port-forward Schema Registry (if needed for direct access)
kubectl port-forward svc/schemaregistry 8082:8082

# Check Schema Registry (returns version info)
curl http://localhost:8082/

# List schemas (subjects)
curl http://localhost:8082/subjects
```

**Note:** Schema Registry is accessible within the cluster at `http://schemaregistry:8082` (same namespace) without port-forwarding.

---

## Start Flink SQL Client

**Prerequisites**: install a Flink 1.20 distribution locally and set the `FLINK_HOME` env variable to point the installation folder.

**Use the provided script (recommended):**

```bash
./flink-sql-client.sh
```

You can also pass additional [SQL client command line options](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sqlclient/#configuration):

```bash
./flink-sql-client.sh --file my-sql-script.sql
```

**Manually run the SQL client:**

```bash
$FLINK_HOME/bin/sql-client.sh gateway --endpoint http://localhost:8083
```

---

## Custom Flink Image Dependencies

The `flink-with-dependencies:latest` custom image extends the official `flink:1.20.3-scala_2.12-java11` base image with additional dependencies required for working with Kafka and Avro data formats.

This custom image is used for both Flink Deployment and SQL Gateway. 
The SQL Gateway also needs these dependencies for planning and validation of SQL queries.

### Dependency Management Strategy

The image uses a **hybrid approach** to eliminate manual transitive dependency tracking:

1. **SQL Connector Uber JARs**: Pre-bundled JARs that include all their transitive dependencies (e.g., `flink-sql-connector-kafka`)
2. **Uber JAR including transitive dependencies**: Use Maven to automatically resolve complex transitive dependencies (e.g., Confluent Schema Registry client)
   and build a single Uber JAR.
3. **Simple wget**: Direct download for standalone JARs without complex dependencies

This approach ensures all required dependencies are included without manual tracking of transitive dependencies like Jackson libraries, while keeping the Docker image reasonably sized.

### How the Build Works

The Dockerfile uses a **multi-stage build**:

1. **Stage 1 (Maven)**: Resolves transitive dependencies defined in `pom.xml`
2. **Stage 2 (Flink)**:
   - Downloads SQL connector uber JARs
   - Downloads Avro format JARs
   - Copies Maven-resolved dependencies
   - Creates final Flink image

**Note:** the custom image is rebuilt every time you set up the playground (or you run `scripts/build-flink-image.sh`). 

### How to Add New Dependencies

If you need to add any new dependency, edit the  `Dockerfile` or the `pom.xml`, then rebuild the image and redeploy SQL Gateway and Session cluster, 
using `rebuild-flink-image-and-redeploy.sh`  

#### For Flink Connectors with Uber JARs

If a SQL connector uber JAR exists (e.g., `flink-sql-connector-elasticsearch`):

1. Edit `flink-custom-image/Dockerfile`
2. Add a wget command:
   ```dockerfile
   RUN wget -P /opt/flink/lib \
       https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-NAME/VERSION/flink-sql-connector-NAME-VERSION.jar
   ```
3. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh`

#### For Dependencies with Complex Transitive Dependencies

If you need a library with many transitive dependencies:

1. Edit `flink-custom-image/pom.xml` and add the dependency
2. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh`

#### For Standalone JARs

For simple JARs without transitive dependencies:

1. Edit `flink-custom-image/Dockerfile`
2. Add a wget command in the appropriate section
3. Rebuild the image and redeploy: `./rebuild-flink-image-and-redeploy.sh`


---

## Modifying Resource Requirements

Minikube requires a minimum amount of resources dedicated to Docker (6 CPU and 10 GiB by default).
You can modify the dedicated resources by editing the `setup-flink-sql-playground.sh` script.

Make sure you provide enough resources to spin up all the components of the playground.

With the current deployment definitions:
- Job Manager: (requests=limits) 0.5 CPU, 1024 MiB 
- 2x Task Managers: (requests=limits) 1 CPU, 2048 MiB **each**
- 3x Kafka brokers: (requests|limits) 0.25|0.5 CPU, 512|768 MiB **each**
- Flink Kubernetes Operator: actual memory utilization ~1.2 GiB (no requests/limits)
- SQL Gateway: actual memory utilization ~500 MiB, may vary when planning complex queries (no requests/limits)
- Kafka UI: actual memory utilization ~500 MiB (no requests/limits)
- Schema Registry: actual memory utilization ~300 MiB (no requests/limits)

**Note**: While the default 6 CPU is slightly overprovisioned, 10 GiB provides limited headroom for active workloads. 
Reducing the cluster resources may cause some of the Pods to get OOMkilled.

---

## Troubleshooting

### cert-manager pods not starting
If using cert-manager v1.18.2 via YAML manifest, as explained in the [Flink Operator Quick Start](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.13/docs/try-flink-kubernetes-operator/quick-start/), 
you may encounter `CreateContainerConfigError` due to security context issues. 
Use the Helm installation method instead (shown above).

### Flink operator installation fails with "metadata.managedFields must be nil"
This occurs when using Kubernetes v1.30+ with Flink operator v1.13.0. 
Use Kubernetes v1.28.0 as shown in step 2.

### Troubleshooting Dependencies

If you encounter `ClassNotFoundException` or `NoClassDefFoundError`:

1. Check if a SQL connector uber JAR exists for your connector
2. For missing transitive dependencies, add the parent dependency to `flink-custom-image/pom.xml`
3. Maven will automatically resolve all required transitive dependencies
4. Rebuild the image and redeploy

---

## Pending Improvements and Known Limitations

- Schema Registry starts immediately, before Kafka brokers are available. This causes the Container to fail and restart a few times before it stabilizes. 
  Normally, this is not an issue.
- Enable/test checkpoints and savepoints

---

## License

This project is licensed under the [MIT License](LICENSE).
