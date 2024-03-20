#!/bin/bash

if [[ -z $DOCKERHUB_LOGIN || -z $DOCKERHUB_PASSWORD ]]; then
    echo '$DOCKERHUB_LOGIN and $DOCKERHUB_PASSWORD is required'
    exit 1
fi

git fetch --tags -f

if [[ $(arch) == "aarch64" ]]; then
    tag=$(git tag|grep ubuntu22|sort| grep -P '\.\d+-arm64$'| tail -n1)
else
    tag=$(git tag|grep ubuntu22|sort| grep -P '\.\d+$'| grep -v arm64| tail -n1)
fi

echo "Use tag $tag"
git checkout refs/tags/$tag

version=$(git describe --tags --always|cut -d/ -f2|cut -d- -f1)

echo "Use version $version"

pushd images/ubuntu/templates
cp /usr/share/AAVMF/AAVMF_CODE.fd flash1.img || true
rm -rf output-custom_image
packer build -var dockerhub_login=$DOCKERHUB_LOGIN -var dockerhub_password=$DOCKERHUB_PASSWORD -var image_version=$version ./ubuntu-22.04.pkr.hcl

mv output-custom_image/ubuntu-22.04 /root/ubuntu-22.04-$version
popd
