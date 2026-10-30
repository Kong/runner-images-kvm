#!/bin/bash

if [[ -z $DOCKERHUB_LOGIN || -z $DOCKERHUB_PASSWORD ]]; then
    echo '$DOCKERHUB_LOGIN and $DOCKERHUB_PASSWORD is required'
    exit 1
fi

rel=${1:-24}

if [[ $rel != "22" && $rel != "24" ]]; then
    echo "Only support Ubuntu 22.04 and 24.04"
    exit 1
fi

echo "Using ${rel}.04"

git fetch -f

if [ -n "$2" ]; then
    # Either a release suffix (20261026.166-kvm-arm64) or a full branch name
    # (trial/..., for trying a branch out before it becomes a release).
    if [[ $2 == */* ]]; then
        branch=origin/$2
    else
        branch=origin/ubuntu${rel}/$2
    fi
elif [[ $(arch) == "aarch64" ]]; then
    branch=$(git branch -a|grep remotes|grep ubuntu${rel}|sort| grep -P '\.\d+-kvm-arm64$'|tail -n1)
else
    branch=$(git branch -a|grep remote|grep -v arm64|grep ubuntu${rel}|sort| grep -P '\.\d+-kvm$'|tail -n1)
fi

echo "Use branch $branch"
git checkout $branch

# Take the version from the branch we just checked out (ubuntu24/<version>-kvm[-arm64]).
# The amd64 and arm64 release lines no longer share a version, so picking the highest
# ubuntu${rel} tag would hand the amd64 build the arm64 version, or the other way round.
version=$(echo "$branch"|sed -E 's#.*/ubuntu[0-9]+/##; s#-kvm(-arm64)?$##')
if [[ ! $version =~ ^[0-9]+\.[0-9]+$ ]]; then
    # Not a release branch (e.g. a trial branch): fall back to the newest tag of this
    # architecture's release line. The two lines no longer share a version, and
    # ubuntu24/20261026.354 sorts above ubuntu24/20261026.166-arm64, so an unfiltered
    # pick would hand an arm64 build the amd64 version.
    if [[ $(arch) == "aarch64" ]]; then
        tag_filter=(grep -- -arm64)
    else
        tag_filter=(grep -v -- -arm64)
    fi
    version=$(git tag --sort=-version:refname|grep ubuntu${rel}|"${tag_filter[@]}"|cut -d/ -f2|cut -d- -f1|head -n 1)
fi

echo "Use version $version"

pushd images/ubuntu/templates
cp /usr/share/AAVMF/AAVMF_CODE.fd flash1.img || true
rm -rf output-custom_image
# On arm64 build from upstream's own arm64 template rather than the amd64 one - but
# only once that template carries our qemu source. Release branches cut before this
# change ship upstream's unpatched arm64 template, which still builds for Azure
# (sources = ["source.azure-arm.image"]); on those, keep using the patched amd64 one.
suffix=""
if [[ $(arch) == "aarch64" ]] && grep -q 'source "qemu"' "build.ubuntu-${rel}_04-arm64.pkr.hcl" 2>/dev/null; then
    suffix="-arm64"
fi
template_file=./ubuntu-${rel}.04${suffix}.pkr.hcl
if [ -f "build.ubuntu-${rel}_04${suffix}.pkr.hcl" ]; then
    template_file=./build.ubuntu-${rel}_04${suffix}.pkr.hcl
fi
packer build -var dockerhub_login=$DOCKERHUB_LOGIN -var dockerhub_password=$DOCKERHUB_PASSWORD -var image_version=$version $template_file

mv output-custom_image/ubuntu-${rel}.04 /root/ubuntu-${rel}.04-$version
popd
