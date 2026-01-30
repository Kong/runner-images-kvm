#!/bin/bash -e
################################################################################
##  File:  install-cmake.sh
##  Desc:  Install CMake
##  Supply chain security: CMake - checksum validation
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# Test to see if the software in question is already installed, if not install it
echo "Checking to see if the installer script has already been run"
if command -v cmake; then
    echo "cmake is already installed"
else
    if [[ "$(uname -m)" == "s390x" ]]; then
        echo "Detected s390x architecture. Installing CMake via APT..."
        apt-get update
        apt-get install -y cmake
    else
        download_url=$(resolve_github_release_asset_url "Kitware/CMake" "endswith(\"inux-$ARCH_L.sh\")" "latest")
        curl -fsSL "${download_url}" -o cmakeinstall.sh

        # Supply chain security - CMake
        hash_url=$(resolve_github_release_asset_url "Kitware/CMake" "endswith(\"SHA-256.txt\")" "latest")
        external_hash=$(get_checksum_from_url "$hash_url" "linux-$ARCH_L.sh" "SHA256")
        use_checksum_comparison "cmakeinstall.sh" "$external_hash"

        # Install CMake and remove the install script
        chmod +x cmakeinstall.sh \
        && ./cmakeinstall.sh --prefix=/usr/local --exclude-subdir \
        && rm cmakeinstall.sh
    fi
fi

invoke_tests "Tools" "Cmake"
