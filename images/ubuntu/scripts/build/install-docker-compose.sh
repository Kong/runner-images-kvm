#!/bin/bash -e
################################################################################
##  File:  install-docker-compose.sh
##  Desc:  Install Docker Compose v1
##  Supply chain security: Docker Compose v1 - checksum validation
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# Download docker-compose v1 from releases
# TODO: Revert this change when the official version supports v2.1 or above.
binary_path=$(download_with_retry "https://github.com/docker/compose/releases/download/v2.38.2/docker-compose-linux-aarch64")

# Supply chain security - Docker Compose v1
# TODO: Revert this change when the official version supports v2.1 or above.
external_hash="4d0f7678dd3338452beba4518e36a8e22b20cad79ba2535c687da554dc3997fb"
use_checksum_comparison "${binary_path}" "${external_hash}"

# Install docker-compose v1
install "${binary_path}" "/usr/local/bin/docker-compose"

invoke_tests "Tools" "Docker-compose v1"
