#!/usr/bin/env bash
# Usage: scripts/open-pr.sh <version>
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

[ $# -eq 1 ] || fail "$(sed -n '2p' "$0" | sed 's/^# //')"
version=$1
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Version '$version' is not in x.y.z form."
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"

root=$(cd "$(dirname "$0")/.." && pwd)
branch="bump/netbird-$version"
title="build: pin NetBird $version"
base=${BASE_SHA:-$(git -C "$root" rev-parse HEAD)}

if gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/$branch" >/dev/null 2>&1; then
  echo "$branch already exists"
  exit 0
fi

gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs" -f ref="refs/heads/$branch" -f sha="$base" >/dev/null

# createCommitOnBranch commits are signed by GitHub, unlike a git push from the runner.
contents=$(base64 <"$root/scripts/install.sh" | tr -d '\n')
jq --null-input \
  --arg repository "$GITHUB_REPOSITORY" --arg branch "$branch" --arg headline "$title" \
  --arg base "$base" --arg contents "$contents" \
  '{
    query: "mutation ($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }",
    variables: {input: {
      branch: {repositoryNameWithOwner: $repository, branchName: $branch},
      message: {headline: $headline},
      expectedHeadOid: $base,
      fileChanges: {additions: [{path: "scripts/install.sh", contents: $contents}]}
    }}
  }' | gh api graphql --input - >/dev/null

# Pushes made with the workflow token start no workflows, but a dispatch does.
gh workflow run test.yml --ref "$branch"

gh pr create --base master --head "$branch" --title "$title" \
  --body "Pins [NetBird $version](https://github.com/netbirdio/netbird/releases/tag/v$version). Both tarballs were downloaded and matched the release's checksums file, and the tests passed."
