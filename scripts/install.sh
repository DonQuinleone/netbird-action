#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_VERSION=0.82.0
readonly DEFAULT_SHA256_AMD64=b569f65de303d21317bc716f3116002e2cf175ae22a9f6d2bed91200a2f5000b
readonly DEFAULT_SHA256_ARM64=c2e5ccb5824cb29fe008a5a54854fd5926b89d3aaff7ab8721f77abf8e8b3e62

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
