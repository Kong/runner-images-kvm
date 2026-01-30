#!/bin/bash -e
################################################################################
##  File:  install-kubernetes-tools.sh
##  Desc:  Install Kubernetes tools: kubectl, kind, minikube, helm, kustomize
################################################################################

source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/etc-environment.sh

# --- [Version Definition] ---
# Since kind version is not in toolset.json, we hardcode it here.
KIND_VERSION="0.31.0"

# --- [Architecture Detection] ---
KERNEL_ARCH=$(uname -m)
if [[ $KERNEL_ARCH == "s390x" ]]; then
    ARCH="s390x"
    MINIKUBE_BINARY="minikube-linux-s390x"
    # s390x releases are often missing on GitHub, so we build from source
    INSTALL_KIND_FROM_SOURCE="true"
elif [[ $KERNEL_ARCH == "aarch64" ]] || [[ $ARCH == "arm64" ]]; then
    ARCH="arm64"
    KIND_BINARY="kind-linux-arm64"
    MINIKUBE_BINARY="minikube-linux-arm64"
    INSTALL_KIND_FROM_SOURCE="false"
else
    ARCH="amd64"
    KIND_BINARY="kind-linux-amd64"
    MINIKUBE_BINARY="minikube-linux-amd64"
    INSTALL_KIND_FROM_SOURCE="false"
fi
# -----------------------------

# 1. Install kubectl (via APT - Official support for s390x exists)
# ----------------------------------------------------------------
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo mkdir -p /etc/apt/keyrings
# Use v1.32 stable repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl

# 2. Install Kind
# ----------------------------------------------------------------
if [[ "$INSTALL_KIND_FROM_SOURCE" == "true" ]]; then
    echo "Compiling Kind v${KIND_VERSION} from source for ${ARCH}..."
    
    # Ensure Go is in PATH (relies on golang.sh installation)
    # Adjust path if your Go is installed elsewhere
    export PATH="/usr/local/go/bin:/usr/bin:$PATH"
    
    # Install directly to /usr/local/bin
    export GOBIN=/usr/local/bin
    
    # Use go install to build specific version
    if go install sigs.k8s.io/kind@v${KIND_VERSION}; then
        echo "Kind installed successfully via Go."
    else
        echo "FATAL: Failed to build Kind from source."
        exit 1
    fi
else
    # Use official binaries for x86/ARM
    KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/${KIND_BINARY}"
    echo "Downloading Kind (v${KIND_VERSION}) for ${ARCH} from $KIND_URL..."
    curl -fsSL "$KIND_URL" -o /usr/local/bin/kind
    chmod +x /usr/local/bin/kind
fi

# 3. Install Minikube
# ----------------------------------------------------------------
# Minikube officially supports s390x binaries
MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/latest/${MINIKUBE_BINARY}"

echo "Downloading Minikube for ${ARCH} from $MINIKUBE_URL..."
curl -LO "$MINIKUBE_URL"
sudo install "$MINIKUBE_BINARY" /usr/local/bin/minikube
rm "$MINIKUBE_BINARY"

# 4. Install Helm (Official Script supports s390x)
# ----------------------------------------------------------------
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# 5. Install Kustomize (Official Script supports s390x)
# ----------------------------------------------------------------
echo "Installing Kustomize..."
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
mv kustomize /usr/local/bin/

# Validate installations
echo "Verifying installations..."
kubectl version --client
kind version
minikube version
helm version
kustomize version

# Run tests
invoke_tests "Tools" "Kubernetes tools"
