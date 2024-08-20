#!/bin/bash

if [[ -z $DOCKERHUB_LOGIN || -z $DOCKERHUB_PASSWORD ]]; then
    echo '$DOCKERHUB_LOGIN and $DOCKERHUB_PASSWORD is required'
    exit 1
fi

rel=${1:-22}

if [[ $rel != "22" && $rel != "24" ]]; then
    echo "Only support Ubuntu 22.04 and 24.04"
    exit 1
fi

echo "Using ${rel}.04"

git fetch -f

if [ -n "$2" ]; then
    branch=remote/origin/ubuntu${rel}/$2
elif [[ $(arch) == "aarch64" ]]; then
    branch=$(git branch -a|grep remotes|grep ubuntu${rel}|sort| grep -P '\.\d+-kvm-arm64$'|tail -n1)
else
    branch=$(git branch -a|grep remote|grep -v arm64|grep ubuntu${rel}|sort| grep -P '\.\d+-kvm$'|tail -n1)
fi

echo "Use branch $branch"
git checkout $branch

version=$(git describe --tags --always|cut -d/ -f2|cut -d- -f1)

echo "Use version $version"

pushd images/ubuntu/templates
cp /usr/share/AAVMF/AAVMF_CODE.fd flash1.img || true
rm -rf output-custom_image
packer build -var dockerhub_login=$DOCKERHUB_LOGIN -var dockerhub_password=$DOCKERHUB_PASSWORD -var image_version=$version ./ubuntu-${rel}.04.pkr.hcl

mv output-custom_image/ubuntu-${rel}.04 /root/ubuntu-${rel}.04-$version
popd
