#!/bin/bash -e
################################################################################
##  File:  install-github-cli.sh
##  Desc:  Install GitHub CLI
##         Must be run as non-root user after homebrew
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# Download GitHub CLI
gh_cli_url=$(resolve_github_release_asset_url "cli/cli" "contains(\"linux\") and contains(\"$ARCH\") and contains(\".deb\")" "latest")
gh_cli_deb_path=$(download_with_retry "$gh_cli_url")
# Supply chain security - GitHub CLI
hash_url=$(resolve_github_release_asset_url "cli/cli" "contains(\"checksums.txt\")" "latest")
external_hash=$(get_hash_from_remote_file "$hash_url" "linux_$ARCH.deb")
use_checksum_comparison "$gh_cli_deb_path" "$external_hash"
# Install GitHub CLI
apt install "$gh_cli_deb_path"

invoke_tests "CLI.Tools" "GitHub CLI"
