#!/bin/bash -e
################################################################################
##  File:  install-packer.sh
##  Desc:  Install packer
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

KERNEL_ARCH=$(uname -m)

if [[ $KERNEL_ARCH == "s390x" ]]; then
    echo "Detected s390x. Installing Packer from source (Clone & Build)..."
    
    export PATH="/usr/local/go/bin:/usr/bin:$PATH"
    
    BUILD_DIR=$(mktemp -d)
    echo "Cloning Packer source code to $BUILD_DIR..."
    
    git clone --depth 1 https://github.com/hashicorp/packer.git "$BUILD_DIR"
    
    echo "Building Packer..."
    cd "$BUILD_DIR"
    
    go build -o packer .
    
    echo "Installing binary to /usr/local/bin/packer..."
    cp packer/packer /usr/local/bin/packer
    chmod +x /usr/local/bin/packer

    ln -sf /usr/local/bin/packer /usr/bin/packer
    
    cd /
    rm -rf "$BUILD_DIR"
    echo "Packer installed successfully."

else
    if [[ $KERNEL_ARCH == "aarch64" ]] || [[ $KERNEL_ARCH == "arm64" ]]; then
        ARCH="arm64"
    else
        ARCH="amd64"
    fi

    echo "Detecting latest Packer version for architecture: $ARCH"
    
    download_url=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/packer/latest | jq -r '.builds[] | select((.arch=="'$ARCH'") and (.os=="linux")).url')

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        echo "Error: Failed to find Packer download URL for architecture: $ARCH"
        exit 1
    fi

    echo "Downloading from: $download_url"
    archive_path=$(download_with_retry "$download_url")
    unzip -o -qq "$archive_path" -d /usr/local/bin
    rm "$archive_path"
fi

invoke_tests "Tools" "Packer"
