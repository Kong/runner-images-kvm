#!/bin/bash -e
################################################################################
##  File:  install-bazel.sh
##  Desc:  Install Bazel (Bazelisk on x64/arm64, Source Build on s390x)
################################################################################

source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/os.sh

KERNEL_ARCH=$(uname -m)
if [[ $KERNEL_ARCH == "s390x" ]]; then
    echo "Detected s390x. Bazelisk does not support this arch."
    echo "Starting Bazel bootstrap build from source..."

    apt-get update
    apt-get install -y build-essential openjdk-21-jdk python3 zip unzip python-is-python3

    update-alternatives --set java /usr/lib/jvm/java-21-openjdk-s390x/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-s390x/bin/javac
    echo "JAVA_HOME=\"/usr/lib/jvm/java-21-openjdk-s390x\"" | sudo tee -a /etc/environment
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-s390x"

    BAZEL_VERSION="7.3.1"
    BAZEL_DIST_URL="https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip"

    WORK_DIR=$(mktemp -d)
    echo "Downloading Bazel source distribution from $BAZEL_DIST_URL..."
    curl -L "$BAZEL_DIST_URL" -o "$WORK_DIR/bazel-dist.zip"

    mkdir -p "$WORK_DIR/source"
    unzip -q "$WORK_DIR/bazel-dist.zip" -d "$WORK_DIR/source"
    
    echo "Compiling Bazel (this may take a while)..."
    cd "$WORK_DIR/source"
    
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-s390x"
    
    env EXTRA_BAZEL_ARGS="--tool_java_runtime_version=local_jdk" bash ./compile.sh

    echo "Installing binary to /usr/local/bin/bazel..."
    cp output/bazel /usr/local/bin/bazel
    chmod +x /usr/local/bin/bazel

    cd /
    rm -rf "$WORK_DIR"
    
    echo "Bazel $BAZEL_VERSION installed successfully."

else
    echo "Installing Bazelisk via npm..."
    npm install -g @bazel/bazelisk
fi

echo "Verifying Bazel installation..."
if bazel --version; then
    echo "Bazel validation passed."
else
    echo "Bazel validation failed."
    exit 1
fi
