#!/bin/bash

set -e  # Exit on error

# Kubernetes cluster configuration
K8S_VERSION="v1.28.0"
K8S_CPUS=6
K8S_MEMORY=10 # in GB


echo "===================================="
echo "Flink SQL Playground Setup"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 0. Check and add required Helm repositories
echo "Step 0: Checking required Helm repositories..."

REPOS_ADDED=false

if ! helm repo list 2>/dev/null | grep -q "^jetstack"; then
    print_info "Adding jetstack Helm repository..."
    helm repo add jetstack https://charts.jetstack.io
    REPOS_ADDED=true
    print_success "jetstack repository added"
else
    print_success "jetstack repository already present"
fi

if ! helm repo list 2>/dev/null | grep -q "^flink-operator-repo"; then
    print_info "Adding flink-operator-repo Helm repository..."
    helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.13.0/
    REPOS_ADDED=true
    print_success "flink-operator-repo repository added"
else
    print_success "flink-operator-repo repository already present"
fi

if [ "$REPOS_ADDED" = true ]; then
    print_info "Updating Helm repositories..."
    helm repo update
    print_success "Helm repositories updated"
else
    print_success "All required Helm repositories are present"
fi
echo ""

# 1. Check/Start Minikube

echo "Step 1: Checking Minikube cluster..."
if minikube status  | grep -q "host: Running"; then
    print_success "Minikube is already running"
else
    # Check Docker resources
    print_info "Checking Docker resources..."
    DOCKER_CPUS=$(docker info 2>/dev/null | grep "CPUs:" | awk '{print $2}')
    DOCKER_MEMORY=$(docker info 2>/dev/null | grep "Total Memory:" | awk '{print $3}' | sed 's/GiB//')

    if [ -z "$DOCKER_CPUS" ] || [ -z "$DOCKER_MEMORY" ]; then
        print_error "Unable to get Docker resource information. Is Docker running?"
        exit 1
    fi

    # Compare resources (use bc for decimal comparison)
    if (( $(echo "$DOCKER_MEMORY >= $K8S_MEMORY" | bc -l) )) && [ "$DOCKER_CPUS" -ge "$K8S_CPUS" ]; then
        print_success "Docker has sufficient resources (CPUs: $DOCKER_CPUS, Memory: ${DOCKER_MEMORY}GiB)"
    else
        print_error "Insufficient Docker resources!"
        print_error "Required: ${K8S_CPUS} CPUs, ${K8S_MEMORY} GiB memory"
        print_error "Available: ${DOCKER_CPUS} CPUs, ${DOCKER_MEMORY} GiB memory"
        print_error "Please increase Docker Desktop resource limits in Settings > Resources"
        exit 1
    fi

    print_info "Starting Minikube cluster with Kubernetes v$K8S_VERSION, $K8S_CPUS CPUs, ${K8S_MEMORY} GiB memory..."
    minikube start --kubernetes-version=$K8S_VERSION --cpus=$K8S_CPUS --memory=${K8S_MEMORY}g
    print_success "Minikube cluster started"

    print_info "Enabling metrics-server addon..."
    minikube addons enable metrics-server
fi
echo ""

# 2. Build custom Flink image
echo "Step 2: Building custom Flink image with dependencies..."
./scripts/build-flink-image.sh
echo ""

# 3. Check/Install cert-manager
echo "Step 3: Checking cert-manager..."
if kubectl get namespace cert-manager &> /dev/null; then
    print_success "cert-manager namespace exists"
    # Wait for cert-manager to be ready
    print_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
    print_success "cert-manager is ready"
else
    print_info "Installing cert-manager..."
    helm install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --set crds.enabled=true
    print_success "cert-manager installed"
    # Wait for cert-manager to be ready
    print_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
    print_success "cert-manager is ready"
fi
echo ""

# 4. Check/Install Flink Kubernetes Operator
echo "Step 4: Checking Flink Kubernetes Operator..."
if helm list | grep -q "flink-kubernetes-operator"; then
    print_success "Flink Kubernetes Operator is already installed"
    # Wait for operator to be ready
    print_info "Waiting for Flink operator to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flink-kubernetes-operator --timeout=120s
    print_success "Flink operator is ready"
else
    print_info "Installing Flink Kubernetes Operator..."
    helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
    print_success "Flink Kubernetes Operator installed"
    # Wait for operator to be ready
    print_info "Waiting for Flink operator to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flink-kubernetes-operator --timeout=120s
    print_success "Flink operator is ready"
fi
echo ""

# 5. Deploy Kafka ecosystem
echo "Step 5: Checking Kafka deployment..."
if kubectl get statefulset kafka &> /dev/null; then
    print_success "Kafka is already deployed"
else
    print_info "Deploying Kafka ecosystem..."
    kubectl apply -f k8s/kafka.yaml
    print_success "Kafka deployment created"
fi

# Wait for Kafka to be ready
print_info "Waiting for Kafka cluster to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s --all
print_success "Kafka cluster is ready"

# Wait for Schema Registry
print_info "Waiting for Schema Registry to be ready..."
kubectl wait --for=condition=ready pod -l app=schema-registry --timeout=120s
print_success "Schema Registry is ready"

# Wait for Kafka UI
print_info "Waiting for Kafka UI to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka-ui --timeout=120s
print_success "Kafka UI is ready"
echo ""

# 6. Deploy Flink Session Cluster
echo "Step 6: Checking Flink session deployment..."
if kubectl get flinkdeployment session-deployment &> /dev/null; then
    print_success "Flink session deployment already exists"
else
    print_info "Deploying Flink session cluster..."
    kubectl apply -f k8s/session-deployment.yaml
    print_success "Flink session deployment created"
fi

# Wait for session deployment to be ready
print_info "Waiting for Flink session deployment to be ready (this may take a few minutes)..."
kubectl wait --for=jsonpath='{.status.lifecycleState}'=STABLE flinkdeployment/session-deployment --timeout=300s
print_success "Flink session deployment is ready"
echo ""

# 7. Deploy SQL Gateway
echo "Step 7: Checking SQL Gateway deployment..."
if kubectl get deployment flink-sql-gateway &> /dev/null; then
    print_success "SQL Gateway is already deployed"
else
    print_info "Deploying SQL Gateway..."
    kubectl apply -f k8s/sql-gateway.yaml
    print_success "SQL Gateway deployment created"
fi

# Wait for SQL Gateway to be ready
print_info "Waiting for SQL Gateway to be ready..."
kubectl wait --for=condition=ready pod -l app=flink-sql-gateway --timeout=120s
print_success "SQL Gateway is ready"
echo ""

# 8. Set up port-forwards
echo "Step 8: Setting up port-forwards..."
echo ""

print_info "Starting port-forward for Flink UI..."
./scripts/port-forward-flink-ui.sh session-deployment 8081 8081
echo ""

print_info "Starting port-forward for Kafka UI..."
./scripts/port-forward-kafka-ui.sh
echo ""

print_info "Starting port-forward for SQL Gateway..."
./scripts/port-forward-sql-gateway.sh
echo ""

# 9. Display URLs and summary
echo "===================================="
echo "✓ Setup Complete!"
echo "===================================="
echo ""
echo "Run 'minikube dashboard' to open the Kubernetes dashboard in your browser."
echo ""
echo "Access your services at:"
echo ""
echo "  Flink UI:        http://localhost:8081"
echo "  Kafka UI:        http://localhost:8080"
echo "  SQL Gateway:     http://localhost:8083"
echo ""
echo "To connect with Flink SQL Client:"
echo "  ./flink-sql-client.sh"
echo ""
echo "Verify SQL Gateway:"
echo "  curl http://localhost:8083/v1/info"
echo ""
echo "===================================="
