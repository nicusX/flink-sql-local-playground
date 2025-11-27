# Flink SQL Playground: Manual Step-by-Step Setup

As an alternative to using the `./setup-flink-sql-playground.sh` script, you can manually set up each component of the playground by following the step-by-step instructions in this chapter.

## 1. Setup the Minikube cluster

### 1.1. Create Kubernetes Cluster

Create a minikube cluster with Kubernetes v1.28.0 (required for compatibility with Flink Operator v1.13.0), with a specific amount of resources. 
For example, to set up a cluster with 6 CPU and 10GiB use:

```bash
minikube start --kubernetes-version=v1.28.0 --cpus=6 --memory=10g
```

### 1.2. Install cert-manager

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

### 1.3. Install Flink Kubernetes Operator

Install the Flink Kubernetes Operator:
```bash
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
```

Verify the operator is running:
```bash
kubectl get pods -n default
```

The flink-kubernetes-operator pod should show `2/2` in the READY column.

### 1.4. Verify Installation

Check all pods across all namespaces:
```bash
kubectl get pods -A
```

You should see:
- cert-manager pods (3) in `cert-manager` namespace
- flink-kubernetes-operator pod (1) in `default` namespace
- Core Kubernetes components in `kube-system` namespace


## 2. Build Custom Flink Docker Image

The Flink session cluster uses a custom Docker image that extends the official Flink image with additional dependencies for Kafka and Avro support. See [Custom Flink Image Dependencies](./custom-flink-image-and-dependencies.md) for details on the included JARs.

**Multiple Versions Available:**
- Flink 1.20.3: `flink-with-dependencies:1.20.3` (Java 11)
- Flink 2.1.1: `flink-with-dependencies:2.1.1` (Java 17)

**Using the build script (recommended):**

```bash
# Build Flink 1.20.3 (default)
./scripts/build-flink-image.sh

# Build Flink 2.1.1
./scripts/build-flink-image.sh --flink-version=2.1.1
```

The script will:
- Build the version-specific Docker image with explicit version tag
- Load it into minikube's image cache
- Verify the image is available
- Use Docker's build cache for efficient rebuilds when nothing changes

**Manual build (alternative):**

If you prefer to build and load the image manually:

```bash
# Build Flink 1.20.3
docker build -t flink-with-dependencies:1.20.3 -f flink-versions/1.20.3/Dockerfile flink-versions/1.20.3
minikube image load flink-with-dependencies:1.20.3

# Or build Flink 2.1.1
docker build -t flink-with-dependencies:2.1.1 -f flink-versions/2.1.1/Dockerfile flink-versions/2.1.1
minikube image load flink-with-dependencies:2.1.1

# Verify the images are loaded
minikube image ls | grep flink-with-dependencies
```

You should see the version-tagged images in the output (e.g., `docker.io/library/flink-with-dependencies:1.20.3`).


## 3. Deploy a Flink Session Cluster with fixed TaskManagers and SQL Gateway

In this section we deploy a Flink session cluster with standby task managers and SQL gateway.
It allows experimenting with interactive SQL statements.

**Version-Specific Manifests:**
Each Flink version has its own Kubernetes manifests that reference the correct image and flinkVersion:
- Flink 1.20.3 manifests: `flink-versions/1.20.3/k8s/`
- Flink 2.1.1 manifests: `flink-versions/2.1.1/k8s/`

### 3.1. Deploy Flink Session Cluster

First, deploy a Flink session cluster that will accept SQL queries:

```bash
# Deploy Flink 1.20.3 (default)
kubectl apply -f flink-versions/1.20.3/k8s/session-deployment.yaml

# Or deploy Flink 2.1.1
kubectl apply -f flink-versions/2.1.1/k8s/session-deployment.yaml
```

This creates a Flink cluster named `session-deployment` with no pre-loaded jobs, ready to accept job submissions via the SQL Gateway.

Verify the deployment:

```bash
kubectl get flinkdeployment session-deployment
```

The deployment should show `LIFECYCLE STATE` as `STABLE`.


### 3.2. Expose Flink UI for the Flink Deployment to the Host Machine

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

#### Why Ingress doesn't work with minikube on macOS

When using minikube with the Docker driver on macOS (the default setup), the Kubernetes cluster runs inside a Docker container, 
creating network isolation between your host machine and the cluster. This presents several challenges for Ingress:

1. **Network Accessibility**: On macOS, you cannot directly access the minikube cluster's IP address from your host machine 
   (unlike Linux where `minikube ip` is directly accessible)
2. **Ingress Controller Requirements**: Even if you install an Ingress controller (like NGINX Ingress), it would only be accessible within the Docker network, 
   not from your host
3. **DNS Resolution**: Ingress relies on host-based routing (using hostnames), but DNS resolution and routing from macOS host to the containerized cluster 
   is not straightforward


### 3.3. Deploy SQL Gateway

The Flink SQL Gateway provides a REST API for executing SQL queries against your Flink session cluster.
This allows you to use the Flink SQL Client from your host machine to interact with the cluster.

The SQL Gateway deployment is configured to connect to the `session-deployment` cluster. Deploy it with the version-specific manifest:

```bash
# Deploy SQL Gateway for Flink 1.20.3 (default)
kubectl apply -f flink-versions/1.20.3/k8s/sql-gateway.yaml

# Or deploy for Flink 2.1.1
kubectl apply -f flink-versions/2.1.1/k8s/sql-gateway.yaml
```

This creates:
- A ConfigMap with SQL Gateway configuration
- A Deployment running the SQL Gateway service
- A ClusterIP Service exposing port 8083

**Note**: The SQL Gateway configuration has a hardwired dependency on the name of the service which deploys the Flink session cluster (`session-deployment`).


#### Verify SQL Gateway is Running

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

### 3.4. Expose SQL Gateway to the Host Machine

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

## 4. Deploy Kafka Ecosystem

This section covers the deployment and usage of Apache Kafka with Schema Registry and Kafka UI.
The Kafka cluster can be used as a data source and sink for Flink jobs.

### 4.1. Overview

The Kafka ecosystem deployment includes:
- **Kafka Cluster**: 3-node Kafka cluster running in KRaft mode (without Zookeeper)
- **Schema Registry**: Confluent Schema Registry for managing Avro/JSON/Protobuf schemas
- **Kafka UI**: Web-based interface for managing and monitoring Kafka

### 4.2. Deploying the Kafka Ecosystem

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

### 4.3. Accessing Kafka from Inside the Kubernetes Cluster

When connecting to Kafka from Flink jobs or other applications running inside the Kubernetes cluster, use the following service addresses.

**Assumption:** The examples below assume Kafka clients (Flink jobs, applications) are running in the same namespace as the Kafka cluster (`default` namespace). If your clients run in a different namespace, use fully qualified domain names (e.g., `kafka-0.kafka.default.svc.cluster.local:9092`).

#### Kafka Brokers

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

#### Schema Registry

Access the Schema Registry API from inside the cluster (same namespace):
```
http://schemaregistry:8082
```

**Example usage in Flink job:**
```yaml
- "--schema.registry.url"
- "http://schemaregistry:8082"
```

### 4.4. Accessing Kafka UI from Host Machine

The Kafka UI provides a web interface for managing topics, viewing messages, monitoring consumer groups, and managing schemas.

#### Using the Port-Forward Script

A convenience script is provided to expose Kafka UI to your host machine:

```bash
./scripts/port-forward-kafka-ui.sh
```

This script:
- Automatically kills any existing port-forward processes for Kafka UI
- Starts a new port-forward in the background
- Exposes Kafka UI on `http://localhost:8080`

#### Manual Port-Forward

Alternatively, you can manually set up port-forwarding:

```bash
kubectl port-forward svc/kafka-ui 8080:8080
```

**This command must be kept running** - it will block the terminal and continue forwarding traffic. You have two options:
- Run it in a separate terminal window/tab
- Run it in the background by adding `&` at the end

#### Accessing the Kafka UI

Once port-forwarding is active, access Kafka UI at: **http://localhost:8080**

From the UI you can:
- View and manage Kafka topics
- Inspect messages in topics
- Monitor consumer groups and lag
- View broker configurations
- Manage schemas via Schema Registry integration

### 4.5. Kafka Cluster Configuration

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

### 4.6. Verifying the Kafka Cluster

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

### 4.7. Verifying Schema Registry

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

## 5. Start Flink SQL Client

**Prerequisites**: Install a Flink distribution locally (matching the version running in your cluster) and set the `FLINK_HOME` env variable to point to the installation folder. See [Install Flink Distribution](../README.md#install-flink-distribution) for details.

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