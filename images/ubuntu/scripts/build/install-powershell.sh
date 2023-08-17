#!/bin/bash -e
################################################################################
##  File:  install-powershell.sh
##  Desc:  Install PowerShell Core
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/os.sh

pwsh_version=$(get_toolset_value .pwsh.version)

if [[ $(arch) == "aarch64" ]]; then
	pwshversion=7.2.13

	# Download the powershell '.tar.gz' archive
	curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v$pwshversion/powershell-$pwshversion-linux-arm64.tar.gz

	# Create the target folder where powershell will be placed
	sudo mkdir -p /opt/microsoft/powershell/7

	# Expand powershell to the target folder
	sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7

	# Set execute permissions
	sudo chmod +x /opt/microsoft/powershell/7/pwsh

	# Create the symbolic link that points to pwsh
	sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
	exit 0
fi

if [[ "${ARCH}" == "arm64" ]]; then
    ARCH_M="arm64"
else
    ARCH_M="x64"
fi

# Install Powershell
if is_ubuntu24; then
    if [[ "${ARCH_M}" == "x64" ]]; then
        dependency_path=$(download_with_retry "http://mirrors.kernel.org/ubuntu/pool/main/i/icu/libicu66_66.1-2ubuntu2_${ARCH}.deb")
    else
        dependency_path=$(download_with_retry "http://launchpadlibrarian.net/687377183/libicu72_72.1-3ubuntu3_${ARCH}.deb")
    fi
    sudo dpkg -i "$dependency_path"
    package_path=$(download_with_retry "https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/powershell-lts_7.4.2-1.deb_${ARCH_M}.deb")
    sudo dpkg -i "$package_path"
else
    apt-get install powershell=$pwsh_version*
fi
