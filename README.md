# Flink SQL Playground

This project allows you to set up a simple local playground to experiment with Flink SQL.

**Supported Flink versions:** 1.20.3, 2.1.1

A local Kubernetes cluster (Minikube) runs: a Flink cluster in session mode, Flink SQL Gateway, a Kafka cluster, Schema Registry, Kafka UI.

You can use Flink SQL CLI to run interactive SQL on the cluster.

Kafka UI and Flink UI are also exposed on localhost, to help with the experimentation.

The [sql-examples](./sql-examples/) folder contains some examples of SQL jobs (WIP).


## Quick Start

1. Verify you meet all [prerequisites](#prerequisites)
2. Install the required [Helm repositories](#install-helm-repositories)
3. Run the setup script for [Flink SQL Playground quick setup](#flink-sql-playground-quick-setup)
   - Alternatively, follow the [Manual Step-by-Step Setup](./docs/manual-setup.md) instructions to set up the Playground manually
4. Start the [Flink SQL Client](#run-the-flink-sql-client) and start interacting with the cluster
5. [Delete the Playground](#delete-the-playground) when you have finished

---

## Prerequisites

- macOS (for this guide)
- Homebrew package manager
- Docker Desktop (for minikube) - must be running with sufficient resource limits (see [Create Kubernetes cluster](./docs/manual-setup.md#11-create-kubernetes-cluster), below)
- Minikube
- Helm
- Local installation of a Flink distribution matching the Flink version used in the playground (see [Install Flink Distribution](#install-flink-distribution))

**Note**: while it should easily work on Linux and Windows machines too, this playground has been tested on macOS only.

### Version Information

- Kubernetes: v1.28.0
- Helm: v4.0.0
- cert-manager: v1.19.1
- Flink Kubernetes Operator: v1.13.0
- Flink: v1.20.3 or v2.1.1 (user-selectable)


### Flink Custom Image and Dependencies

The Flink session cluster and the SQL Gateway use a customized Flink image where some dependencies, such as Kafka connector and AVRO Schema Registry Format, have been included.

For more details, see [Custom Flink Image and Dependencies](./docs/custom-flink-image-and-dependencies.md).

### Install Flink Distribution

To use the Flink SQL Client from your host machine, you need to have the Flink distribution installed locally and the `FLINK_HOME` environment variable configured.

> ⚠️ **Important:** Your local Flink distribution version should match the version you're using in the playground. 
> The Flink SQL client from a different major version may not be compatible with the Flink version running in the cluster.

**Download and extract Flink distribution:**

Move to the folder where you want to install the Flink distribution.

For Flink 1.20.3:
```bash
curl -L -O https://archive.apache.org/dist/flink/flink-1.20.3/flink-1.20.3-bin-scala_2.12.tgz
tar -xzf flink-1.20.3-bin-scala_2.12.tgz
```

For Flink 2.1.1:
```bash
curl -L -O https://archive.apache.org/dist/flink/flink-2.1.1/flink-2.1.1-bin-scala_2.12.tgz
tar -xzf flink-2.1.1-bin-scala_2.12.tgz
```

**Set the FLINK_HOME environment variable:**

For the current terminal session (adjust the version as needed):

```bash
# For Flink 1.20.3
export FLINK_HOME="$(pwd)/flink-1.20.3"

# For Flink 2.1.1
export FLINK_HOME="$(pwd)/flink-2.1.1"
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
**Note**: To manually set up and customize the playground, follow the [Manual Step-by-Step Setup](./docs/manual-setup.md) instructions instead of using the setup script.

**Multiple Flink Versions Supported:**
The playground supports multiple Flink versions. By default, it uses **Flink 1.20.3**. To use a different version:

```bash
# Use Flink 1.20.3 (default)
./setup-flink-sql-playground.sh

# Use Flink 2.1.1
./setup-flink-sql-playground.sh --flink-version=2.1.1
```

**Available versions:** `1.20.3`, `2.1.1`

The playground includes:
1. The minikube cluster
2. Custom Flink Docker image with Kafka connector (version-specific)
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

## Quick Reference

### Run the Flink SQL Client

Assuming you have a Flink distribution, matching the Flink version used in the playground, installed locally and the `FLINK_HOME` environment variable pointing to the folder with the distribution, use the shortcut script to run the SQL client.

```bash
./flink-sql-client.sh <optional-parameters...>
```

Any additional parameter is passed to the SQL client. For example, to pass a file with a SQL script: 

```bash
./flink-sql-client.sh --file my-sql-script.sql
```

### Check Current Flink Version

To check which Flink version is currently running in the cluster:

```bash
# Check the Docker image being used (shows 1.20.3 or 2.1.1)
kubectl get flinkdeployment session-deployment -o jsonpath='{.spec.image}{"\n"}'

# Check the flinkVersion field (shows v1_20 or v2_1)
kubectl get flinkdeployment session-deployment -o jsonpath='{.spec.flinkVersion}{"\n"}'

# Check actual Flink version inside a running pod
kubectl exec deployment/flink-sql-gateway -- /opt/flink/bin/flink --version

# Check when the image was last built (timestamp file)
kubectl exec deployment/flink-sql-gateway -- sh -c 'ls -lh /opt/flink/modified-*'
```

### Build Custom Images

Build Flink custom images with dependencies:

```bash
# Build for Flink 1.20.3 (default)
./scripts/build-flink-image.sh

# Build for Flink 2.1.1
./scripts/build-flink-image.sh --flink-version=2.1.1

# Verify images in minikube
minikube image ls | grep flink-with-dependencies
```

### Rebuild and Redeploy

After modifying Dockerfile or dependencies, rebuild the image and redeploy:

```bash
# Rebuild and redeploy Flink 1.20.3
./rebuild-flink-image-and-redeploy.sh

# Rebuild and redeploy Flink 2.1.1
./rebuild-flink-image-and-redeploy.sh --flink-version=2.1.1
```

### Service URLs

When port-forwards are active:
- **Flink UI**: http://localhost:8081
- **Kafka UI**: http://localhost:8080
- **SQL Gateway**: http://localhost:8083

### Useful kubectl Commands

```bash
# View all pods
kubectl get pods

# View Flink deployment status
kubectl get flinkdeployment session-deployment

# Check SQL Gateway logs
kubectl logs -l app=flink-sql-gateway

# Check TaskManager logs
kubectl logs session-deployment-taskmanager-1-1
```
 

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
- Materialized Tables
- Test and document submitting JAR dependencies via SQL Client
- Improve custom image build process to leverage image layer caching

---

## License

This project is licensed under the [MIT License](LICENSE).
