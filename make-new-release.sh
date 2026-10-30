#!/bin/bash

GREP=grep
if [[ "$OSTYPE" == darwin* ]]; then
    GREP=ggrep
fi

urel=${1:-24}

if [[ $urel != "22" && $urel != "24" ]]; then
    echo "Only support Ubuntu 22.04 and 24.04"
    exit 1
fi

echo "Using ${urel}.04"


cherry() {
    c=$1
    git cherry-pick $c
    while [[ -e .git/CHERRY_PICK_HEAD ]]; do
        # Nothing left to apply (the change is already in history). Skip it instead
        # of leaving behind an empty commit that duplicates an existing message.
        # Use `git status --porcelain` rather than `git diff`: it also reports
        # untracked files, so a newly added file is never mistaken for "nothing".
        if [[ -z $(git status --porcelain) ]]; then
            echo "Nothing to apply for $c, skipping"
            git cherry-pick --skip
            break
        fi
        echo "Resolve conflicts and ctrl+d to continue"
        bash
    done
}

push() {
    git push origin $@
    #git push private $@
}

git reset --hard
git checkout main
git tag -l | xargs -I {} git tag -d {} > /dev/null 2>&1 #clean up all local tags to avoid being rejected when fetching upstream tags
git remote add upstream https://github.com/actions/runner-images 2>/dev/null || true
git fetch upstream --tags 2>/dev/null || true 
git fetch origin 2>/dev/null || true

tag=${2:-$(gh release list -R actions/runner-images --limit 100|$GREP -oP "ubuntu${urel}/\K[\d\.]+" | head -n1)}
rel=ubuntu${urel}/${tag}

# Upstream publishes the arm64 image as its own release line (ubuntu24-arm64/...),
# on its own cadence, so its version never matches the amd64 one. Resolve it
# separately and build the arm64 branch from it. Our own branch/tag naming stays
# ubuntu${urel}/<arm64 version>-kvm-arm64 so build-new-image.sh keeps finding it.
arm_tag=${3:-$(gh release list -R actions/runner-images --limit 100|$GREP -oP "ubuntu${urel}-arm64/\K[\d\.]+" | head -n1)}
arm_upstream_tag=ubuntu${urel}-arm64/${arm_tag}
arm_rel=ubuntu${urel}/${arm_tag}

last_kvm_branch=$(git branch -r|grep kvm|grep -v arm64|grep -v $rel|grep ubuntu${urel}|sort|tail -n1|awk '{print $1}')
last_arm64_branch=$(git branch -r|grep kvm-arm64|grep -v $arm_rel|grep ubuntu${urel}|sort|tail -n1|awk '{print $1}')

echo "The latest upstream release tag is $rel"
echo "The latest upstream arm64 release tag is $arm_upstream_tag"
echo "Cherry pick from $last_kvm_branch and $last_arm64_branch"
if [[ -z $last_kvm_branch || -z $last_arm64_branch ]]; then
    echo "Cannot find last time branch to cherry pick from"
    exit 0
fi
if [[ -z $arm_tag ]]; then
    echo "Cannot find the upstream arm64 release tag"
    exit 1
fi

# Resolve the upstream release commit up front. `git tag -f ${rel}` below repoints
# this tag at the amd64 branch, so tags/$rel can no longer be used as the base once
# that has run.
# --verify --quiet matters here: plain `git rev-parse` echoes an unresolvable name
# back unchanged, so a typo in $2/$3 or a silently failed fetch would leave $arm_base
# holding a string, `git checkout $arm_base` would fail, and - there being no `set -e` -
# the script would carry on from the current HEAD (the amd64 branch) and force-push
# that as the arm64 release. Bail out before the first push instead.
base=$(git rev-parse --verify --quiet "tags/$rel^{commit}")
arm_base=$(git rev-parse --verify --quiet "tags/$arm_upstream_tag^{commit}")
if [[ -z $base ]]; then
echo "Cannot resolve upstream release tag $rel"
exit 1
fi
if [[ -z $arm_base ]]; then
echo "Cannot resolve upstream arm64 release tag $arm_upstream_tag"
exit 1
fi
echo "Upstream release commit is $base"
echo "Upstream arm64 release commit is $arm_base"

git checkout $base

git branch -D ${rel}-kvm 2>/dev/null
git checkout --no-track -b ${rel}-kvm 2>/dev/null
git clean -f
git pull origin ${rel}-kvm --rebase 2>/dev/null
# 3 commits for amd64
for c in $(git log --reverse -n 3 --pretty=format:"%H" $last_kvm_branch); do
    cherry $c
done
push -f refs/heads/${rel}-kvm
git tag -f ${rel}
push -f refs/tags/${rel}
gh release create $rel --notes "https://github.com/actions/runner-images/releases/tag/${rel//\//%2F}"

# Start the arm64 branch from the upstream *arm64* release commit, not from the amd64
# branch we just built and not from the amd64 release either: upstream ships first-class
# arm64 packer templates and toolsets (build.ubuntu-XX_04-arm64.pkr.hcl,
# toolset-XXXX-arm64.json), and we build straight from those instead of patching the
# amd64 ones. Starting from the amd64 branch would also replay its commits here and
# produce duplicated commit messages.
git checkout $arm_base

git branch -D ${arm_rel}-kvm-arm64 2>/dev/null
git checkout --no-track -b ${arm_rel}-kvm-arm64 2>/dev/null
git clean -f
git pull origin ${arm_rel}-kvm-arm64 --rebase 2>/dev/null
# total of 5 commits for arm64
for c in $(git log --reverse -n 5 --pretty=format:"%H" $last_arm64_branch); do
    cherry $c
done

# Sanity check: flag install scripts that still hardcode an amd64 artifact while being
# referenced (not commented out) by the arm64 template we actually build from.
what=0
arm_template=images/ubuntu/templates/build.ubuntu-${urel}_04-arm64.pkr.hcl
for f in $($GREP images/ubuntu/scripts/ -rPe "(?:x86_64|amd64)"|cut -d: -f1|sort|uniq); do
    ff=$(echo $f|cut -d/ -f3-5)
    fff=$($GREP -- "$ff" "$arm_template")
    if [[ ! -z "$fff" && -z $(echo $fff |grep "//") ]]; then
        echo "$f possible contain arch dependent install code, please check"
        what=1
    fi
done
if [[ $what -eq 1 ]]; then
    echo "Press enter to continue ..."
    read
fi

push -f refs/heads/${arm_rel}-kvm-arm64
git tag -f ${arm_rel}-arm64
push -f refs/tags/${arm_rel}-arm64
gh release create $arm_rel-arm64 --notes "https://github.com/actions/runner-images/releases/tag/${arm_upstream_tag//\//%2F}"

