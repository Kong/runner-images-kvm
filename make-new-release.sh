#!/bin/bash -e

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
git remote add upstream https://github.com/actions/runner-images 2>/dev/null
git fetch upstream --tags 2>/dev/null
git fetch origin 2>/dev/null

rel=$(gh release list -R actions/runner-images|$GREP -oP "ubuntu22/[\d\.]+"|head -n1)
last_kvm_branch=origin/$(git branch|grep kvm|grep -v arm64|grep -v $rel|sort|tail -n1|awk '{print $1}')
last_arm64_branch=origin/$(git branch|grep kvm-arm64|grep -v $rel|sort|tail -n1|awk '{print $1}')

echo "The latest upstream release tag is $rel"

git checkout $rel

git branch -D ${rel}-kvm 2>/dev/null
git checkout -b ${rel}-kvm 2>/dev/null
git clean -f
cherry $(git log -n 1 --pretty=format:"%H" $last_kvm_branch)
push -f refs/heads/${rel}-kvm
git tag -f ${rel}
push -f refs/tags/${rel}
gh release create $rel --notes "https://github.com/actions/runner-images/releases/tag/${rel//\//%2F}"

git branch -D ${rel}-kvm-arm64 2>/dev/null
git checkout -b ${rel}-kvm-arm64 2>/dev/null
git clean -f
for c in $(git log --reverse -n 2 --pretty=format:"%H" $last_arm64_branch); do
    cherry $c
done
push -f refs/heads/${rel}-kvm-arm64
git tag -f ${rel}-arm64
push -f refs/tags/${rel}-arm64
gh release create $rel-arm64 --notes "https://github.com/actions/runner-images/releases/tag/${rel//\//%2F}"

