#!/bin/bash -e
################################################################################
##  File:  install-docker-compose.sh
##  Desc:  Install Docker Compose v1
##  Supply chain security: Docker Compose v1 - checksum validation
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# Download docker-compose v1 from releases
<<<<<<< HEAD
binary_path=$(download_with_retry "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Linux-x86_64")

# Supply chain security - Docker Compose v1
external_hash="f3f10cf3dbb8107e9ba2ea5f23c1d2159ff7321d16f0a23051d68d8e2547b323"
=======
# TODO: Revert this change when the official version supports v2.1 or above.
binary_path=$(download_with_retry "https://github.com/docker/compose/releases/download/v2.1.0/docker-compose-linux-aarch64")

# Supply chain security - Docker Compose v1
# TODO: Revert this change when the official version supports v2.1 or above.
external_hash="914bc7176a25648e71cdafb11acee567989c5aa9e35248ef4bf197a4d6b0bfef"
>>>>>>> 383c80b32 (use docker-compose v2)
use_checksum_comparison "${binary_path}" "${external_hash}"

# Install docker-compose v1
install "${binary_path}" "/usr/local/bin/docker-compose"

invoke_tests "Tools" "Docker-compose v1"
