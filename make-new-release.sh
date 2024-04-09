#!/bin/bash

GREP=grep
if [[ "$OSTYPE" == darwin* ]]; then
    GREP=ggrep
fi

cherry() {
    c=$1
    git cherry-pick $c
    while [[ -e .git/CHERRY_PICK_HEAD ]]; do
        echo "Resolve conflicts and ctrl+d to continue"
        bash
    done
}

push() {
    git push origin $@
    git push private $@
}


git reset --hard
git checkout main
git remote add upstream https://github.com/actions/runner-images 2>/dev/null || true
git fetch upstream --tags 2>/dev/null || true 
git fetch origin 2>/dev/null || true

rel=$(gh release list -R actions/runner-images|$GREP -oP "ubuntu22/[\d\.]+"|head -n1)
last_kvm_branch=origin/$(git branch|grep kvm|grep -v arm64|grep -v $rel|sort|tail -n1|awk '{print $1}')
last_arm64_branch=origin/$(git branch|grep kvm-arm64|grep -v $rel|sort|tail -n1|awk '{print $1}')

echo "The latest upstream release tag is $rel"

git checkout $rel

git branch -D ${rel}-kvm 2>/dev/null
git checkout -b ${rel}-kvm 2>/dev/null
git clean -f
git pull origin ${rel}-kvm --rebase 2>/dev/null
for c in $(git log --reverse -n 2 --pretty=format:"%H" $last_kvm_branch); do
    cherry $c
done
push -f refs/heads/${rel}-kvm
git tag -f ${rel}
push -f refs/tags/${rel}
gh release create $rel --notes "https://github.com/actions/runner-images/releases/tag/${rel//\//%2F}"

git branch -D ${rel}-kvm-arm64 2>/dev/null
git checkout -b ${rel}-kvm-arm64 2>/dev/null
git clean -f
git pull origin ${rel}-kvm-arm64 --rebase 2>/dev/null
# total of 4 commits for arm64
for c in $(git log --reverse -n 2 --pretty=format:"%H" $last_arm64_branch); do
    cherry $c
done

# sanity check
what=0
for f in $(grep images/ubuntu/scripts/ -rPe "(?:x86_64|amd64)"|cut -d: -f1|sort|uniq); do
    ff=$(echo $f|cut -d/ -f3-5)
    fff=$(cat images/ubuntu/templates/ubuntu-22.04.pkr.hcl | grep $ff )
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

