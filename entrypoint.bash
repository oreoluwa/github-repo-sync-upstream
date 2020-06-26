#!/usr/bin/env bash

set -e
set -x

if [[ -n "$SSH_PRIVATE_KEY" ]]; then
  echo "Saving SSH_PRIVATE_KEY"

  mkdir -p /root/.ssh
  echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa

  # Github action changes $HOME to /github at runtime
  # therefore we always copy the SSH key to $HOME (aka. ~)
  mkdir -p ~/.ssh
  cp /root/.ssh/* ~/.ssh/ 2> /dev/null || true 
fi

UPSTREAM_REPO=$1
BRANCH_MAPPING=$2
STRATEGY=$3
LOCAL_BRANCH=$(echo $2 | cut -d: -f2)

git clone "https://github.com/${GITHUB_REPOSITORY}.git" work
cd work || { echo "Missing work dir" && exist 2 ; }

git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

git checkout $LOCAL_BRANCH

if [[ -z "$UPSTREAM_REPO" ]]; then
  echo "Missing \$UPSTREAM_REPO"
  exit 1
fi

if [[ -z "$STRATEGY" ]]; then
  echo "Missing \$STRATEGY"
  exit 1
fi

if [[ -z "$BRANCH_MAPPING" ]]; then
  echo "Missing \$SOURCE_BRANCH:\$DESTINATION_BRANCH"
  exit 1
fi

if ! echo "$UPSTREAM_REPO" | grep '\.git'; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi

echo "UPSTREAM_REPO=$UPSTREAM_REPO"
echo "BRANCHES=$BRANCH_MAPPING"

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

git remote add upstream "$UPSTREAM_REPO"
git fetch upstream "${BRANCH_MAPPING%%:*}"
git remote -v

if [[ "$STRATEGY" == "rebase" ]]; then
  echo "Rebasing ..."
  git rebase --autosquash --autostash "upstream/${BRANCH_MAPPING%%:*}"
fi

if [[ "$STRATEGY" == "merge" ]]; then
  echo "Merging Upstream into your branch ..."
  git merge "upstream/${BRANCH_MAPPING%%:*}"
fi

PUSH_FLAGS="--force"
if [[ "$FORCE_PUSH" == "false" ]]; then
  PUSH_FLAGS=""
fi

git push $PUSH_FLAGS origin "${BRANCH_MAPPING#*:}"

git remote rm upstream
git remote -v
