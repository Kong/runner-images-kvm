#!/bin/bash -e
################################################################################
##  File:  install-yq.sh
##  Desc:  Install yq - a command-line YAML, JSON and XML processor
##  Supply chain security: yq - checksum validation
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

if [[ $(uname -m) == "s390x" ]]; then
    export PATH="/usr/local/go/bin:/usr/bin:$PATH"
    BUILD_DIR=$(mktemp -d)
    
    git clone --depth 1 https://github.com/mikefarah/yq.git "$BUILD_DIR"
    cd "$BUILD_DIR"
    go build -o yq .
    install "yq" /usr/bin/yq
    
    cd /
    rm -rf "$BUILD_DIR"
    
    invoke_tests "Tools" "yq"
    exit 0
fi

# Download yq
yq_url=$(resolve_github_release_asset_url "mikefarah/yq" "endswith(\"yq_linux_$ARCH\")" "latest")
binary_path=$(download_with_retry "${yq_url}")

# Supply chain security - yq
hash_url=$(resolve_github_release_asset_url "mikefarah/yq" "endswith(\"checksums\")" "latest")
external_hash=$(get_checksum_from_url "${hash_url}" "yq_linux_$ARCH " "SHA256" "true" " " "19")
use_checksum_comparison "$binary_path" "$external_hash"

# Install yq
install "$binary_path" /usr/bin/yq

invoke_tests "Tools" "yq"
