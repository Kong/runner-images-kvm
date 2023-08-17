#!/bin/bash -e
################################################################################
##  File:  golang
##  Desc:  Installs golang (manaul)
################################################################################

source $HELPER_SCRIPTS/os.sh
source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/etc-environment.sh

# Get version from toolset
KNOWN_VERSIONS=$(curl 'https://raw.githubusercontent.com/actions/node-versions/main/versions-manifest.json'|jq -r .[].version)
TOOLSET_VERSIONS=$(get_toolset_value '.toolcache[] | select(.name | contains("node")) | .versions[]')
PLATFORM_NAME=$(get_toolset_value '.toolcache[] | select(.name | contains("node")) | .platform')

# Install golang
NODEJS_PATH="$AGENT_TOOLSDIRECTORY/node"

echo "Check if NodeJS hostedtoolcache folder exist..."
if [ ! -d $NODEJS_PATH ]; then
    mkdir -p $NODEJS_PATH
fi

if [[ $ARCH == "arm64" ]]; then
    arch="arm64"
else
    arch="x64"
fi

for TOOLSET_VERSION in ${TOOLSET_VERSIONS[@]}; do
    NODEJS_VERSION=$(echo "$KNOWN_VERSIONS" | grep "^${TOOLSET_VERSION}" | sort -V | tail -1)
    PACKAGE_TAR_NAME="node-v$NODEJS_VERSION-linux-$arch.tar.xz"
    NODEJS_VERSION_PATH="$NODEJS_PATH/$NODEJS_VERSION/$arch"

    echo "Create NodeJS $NODEJS_VERSION directory..."
    mkdir -p $NODEJS_VERSION_PATH

    echo "Downloading tar archive $PACKAGE_TAR_NAME"
    DOWNLOAD_URL="https://nodejs.org/dist/v$NODEJS_VERSION/$PACKAGE_TAR_NAME"
    download_with_retries $DOWNLOAD_URL "/tmp" $PACKAGE_TAR_NAME

    echo "Expand '$PACKAGE_TAR_NAME' to the '$NODEJS_VERSION_PATH' folder"
    tar xf "/tmp/$PACKAGE_TAR_NAME" -C $NODEJS_VERSION_PATH --strip-components=1

    COMPLETE_FILE_PATH="$NODEJS_VERSION_PATH/../$arch.complete"
    if [ ! -f $COMPLETE_FILE_PATH ]; then
        echo "Create complete file"
        touch $COMPLETE_FILE_PATH
    fi
done
