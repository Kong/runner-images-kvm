#!/bin/bash -e
################################################################################
##  File:  install-ninja.sh
##  Desc:  Install ninja-build
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

if [[ $(uname -m) == "s390x" ]]; then
    BUILD_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/ninja-build/ninja.git "$BUILD_DIR"
    cd "$BUILD_DIR"

    python3 configure.py --bootstrap
    install ninja /usr/local/bin/ninja

    cd /
    rm -rf "$BUILD_DIR"
    invoke_tests "Tools" "Ninja"
    exit 0
fi

# Install ninja
download_url=$(resolve_github_release_asset_url "ninja-build/ninja" "endswith(\"ninja-linux-aarch64.zip\")" "latest")
ninja_binary_path=$(download_with_retry "${download_url}")

# Unzip the ninja binary
unzip -qq "$ninja_binary_path" -d /usr/local/bin

invoke_tests "Tools" "Ninja"
