#!/bin/bash -e
################################################################################
##  File:  golang
##  Desc:  Installs golang (manaul)
################################################################################

source $HELPER_SCRIPTS/os.sh
source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/etc-environment.sh

# Get version from toolset
PACKAGE_TAR_NAMES=$(curl 'https://go.dev/dl/?mode=json&include=all'|jq -r .[].files[].filename)
TOOLSET_VERSIONS=$(get_toolset_value '.toolcache[] | select(.name | contains("go")) | .versions[]')
PLATFORM_NAME=$(get_toolset_value '.toolcache[] | select(.name | contains("go")) | .platform')

# Install golang
GOLANG_PATH="$AGENT_TOOLSDIRECTORY/go"

echo "Check if Golang hostedtoolcache folder exist..."
if [ ! -d $GOLANG_PATH ]; then
    mkdir -p $GOLANG_PATH
fi

if [[ $ARCH == "arm64" ]]; then
    arch="arm64"
else
    arch="x64"
fi

for TOOLSET_VERSION in ${TOOLSET_VERSIONS[@]}; do
    # Note: skip inproper version numbers like 1.20.0.linux -> 1.20.linux
    PACKAGE_TAR_NAME=$(echo "$PACKAGE_TAR_NAMES" | grep "^go${TOOLSET_VERSION}.${PLATFORM_NAME}-${ARCH}.tar.gz$" | grep -vP "go\d+\.\d+\.linux" | sort -V | tail -1)
    GOLANG_VERSION=$(echo "$PACKAGE_TAR_NAME" | cut -d'.' -f 1-3| cut -d'o' -f 2)
    GOLANG_VERSION_PATH="$GOLANG_PATH/$GOLANG_VERSION/$arch"

    echo "Create Golang $GOLANG_VERSION directory..."
    mkdir -p $GOLANG_VERSION_PATH

    echo "Downloading tar archive $PACKAGE_TAR_NAME"
    DOWNLOAD_URL="https://go.dev/dl/${PACKAGE_TAR_NAME}"
    archive_path=$(download_with_retry $DOWNLOAD_URL)

    echo "Expand '$archive_path' to the '$GOLANG_VERSION_PATH' folder"
    tar xf "$archive_path" -C $GOLANG_VERSION_PATH --strip-components=1

    COMPLETE_FILE_PATH="$GOLANG_VERSION_PATH/../$arch.complete"
    if [ ! -f $COMPLETE_FILE_PATH ]; then
        echo "Create complete file"
        touch $COMPLETE_FILE_PATH
    fi

    if [[ "$TOOLSET_VERSION" == "$(get_toolset_value '.toolcache[] | select(.name | contains("go")) | .default')" ]]; then
	    echo "Create symlink for default toolset path"
	    ln -svf $GOLANG_VERSION_PATH/bin/go /usr/bin/go
    fi

    set_etc_environment_variable "GOROOT_$(echo $GOLANG_VERSION| cut -d'.' -f1)_$(echo $GOLANG_VERSION| cut -d'.' -f2)_${arch^^}" $GOLANG_VERSION_PATH
done

/usr/bin/go version
