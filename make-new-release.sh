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

tag=${2:-$(gh release list -R actions/runner-images|$GREP -oP "ubuntu${urel}/\K[\d\.]+" | head -n1)}
rel=ubuntu${urel}/${tag}
last_kvm_branch=$(git branch -r|grep kvm|grep -v arm64|grep -v $rel|grep ubuntu${urel}|sort|tail -n1|awk '{print $1}')
last_arm64_branch=$(git branch -r|grep kvm-arm64|grep -v $rel|grep ubuntu${urel}|sort|tail -n1|awk '{print $1}')

echo "The latest upstream release tag is $rel"
echo "Cherry pick from $last_kvm_branch and $last_arm64_branch"
if [[ -z $last_kvm_branch || -z $last_arm64_branch ]]; then
    echo "Cannot find last time branch to cherry pick from"
    exit 0
fi

# Resolve the upstream release commit up front. `git tag -f ${rel}` below repoints
# this tag at the amd64 branch, so tags/$rel can no longer be used as the base once
# that has run.
base=$(git rev-parse "tags/$rel^{commit}")
echo "Upstream release commit is $base"

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

# Start the arm64 branch from the upstream release commit, not from the amd64 branch
# we just built. Otherwise the arm64 branch inherits the 3 amd64 commits and the loop
# below replays their arm64 counterparts on top, producing duplicated commit messages.
# tags/$rel points at the amd64 branch by now, so use the commit resolved earlier.
git checkout $base

git branch -D ${rel}-kvm-arm64 2>/dev/null
git checkout --no-track -b ${rel}-kvm-arm64 2>/dev/null
git clean -f
git pull origin ${rel}-kvm-arm64 --rebase 2>/dev/null
# total of 5 commits for arm64
for c in $(git log --reverse -n 5 --pretty=format:"%H" $last_arm64_branch); do
    cherry $c
done

# sanity check
what=0
for f in $($GREP images/ubuntu/scripts/ -rPe "(?:x86_64|amd64)"|cut -d: -f1|sort|uniq); do
    ff=$(echo $f|cut -d/ -f3-5)
    fff=$(cat images/ubuntu/templates/build.ubuntu-22_04.pkr.hcl | grep $ff )
    if [[ ! -z "$fff" && -z $(echo $fff |grep "//") ]]; then
        echo "$f possible contain arch dependent install code, please check"
        what=1
    fi
done
if [[ $what -eq 1 ]]; then
    echo "Press enter to continue ..."
    read
fi

push -f refs/heads/${rel}-kvm-arm64
git tag -f ${rel}-arm64
push -f refs/tags/${rel}-arm64
gh release create $rel-arm64 --notes "https://github.com/actions/runner-images/releases/tag/${rel//\//%2F}"

