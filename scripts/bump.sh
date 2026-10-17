#!/usr/bin/env bash
# Usage: scripts/bump.sh <version> <checksums file from that NetBird release>
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

[ $# -eq 2 ] || fail "$(sed -n '2p' "$0" | sed 's/^# //')"
version=$1
checksums=$2
target=${INSTALL_SH:-$(dirname "$0")/install.sh}

[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Version '$version' is not in x.y.z form."

checksum_for() {
  local tarball="netbird_${version}_linux_$1.tar.gz" sum
  sum=$(awk -v name="$tarball" '$2 == name { print $1 }' "$checksums")
  [[ $sum =~ ^[0-9a-f]{64}$ ]] || fail "No valid SHA-256 for $tarball in $checksums."
  echo "$sum"
}

amd64=$(checksum_for amd64)
arm64=$(checksum_for arm64)

sed -i.orig -E \
  -e "s/^readonly DEFAULT_VERSION=.*/readonly DEFAULT_VERSION=$version/" \
  -e "s/^readonly DEFAULT_SHA256_AMD64=.*/readonly DEFAULT_SHA256_AMD64=$amd64/" \
  -e "s/^readonly DEFAULT_SHA256_ARM64=.*/readonly DEFAULT_SHA256_ARM64=$arm64/" \
  "$target"
rm "$target.orig"

echo "Pinned NetBird $version"
