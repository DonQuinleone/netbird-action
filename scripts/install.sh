#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_VERSION=0.81.4
readonly DEFAULT_SHA256_AMD64=e9b3d7e396584ddc2513d50bc9168fe4b6a89c1a527308c1e51331c7a1e67165
readonly DEFAULT_SHA256_ARM64=428a6fdc330bc43c2791ef208ce6b059d50731cf4bffc5a6e4e8af2f4c7a5029

fail() {
  echo "::error::$1" >&2
  exit 1
}

version=${NB_VERSION:-$DEFAULT_VERSION}

case ${RUNNER_ARCH:-} in
  X64) arch=amd64 default_sha=$DEFAULT_SHA256_AMD64 ;;
  ARM64) arch=arm64 default_sha=$DEFAULT_SHA256_ARM64 ;;
  *) fail "Runner architecture '${RUNNER_ARCH:-unknown}' is not supported. Use an X64 or ARM64 Linux runner." ;;
esac

if [ -n "${NB_CHECKSUM:-}" ]; then
  expected=$NB_CHECKSUM
elif [ "$version" = "$DEFAULT_VERSION" ]; then
  expected=$default_sha
else
  fail "NetBird $version has no pinned checksum. Pass the tarball's SHA-256 as the checksum input."
fi

tarball="netbird_${version}_linux_${arch}.tar.gz"
url="https://github.com/netbirdio/netbird/releases/download/v${version}/${tarball}"
dir=$(mktemp -d "${RUNNER_TEMP:-/tmp}/netbird.XXXXXX")

curl --fail --silent --show-error --location --retry 3 --output "$dir/$tarball" "$url"

if ! echo "$expected  $dir/$tarball" | sha256sum --check --status; then
  fail "$tarball does not match the expected SHA-256 $expected."
fi

tar -xzf "$dir/$tarball" -C "$dir" netbird
sudo install -m 0755 "$dir/netbird" /usr/local/bin/netbird
echo "Installed NetBird $version ($arch)"
