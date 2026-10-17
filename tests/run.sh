#!/usr/bin/env bash
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0
failed=0

mkdir -p "$work/payload"
printf '#!/bin/sh\n' >"$work/payload/netbird"
tar -czf "$work/netbird.tar.gz" -C "$work/payload" netbird

stubs() {
  local bin=$work/bin
  rm -rf "$bin" && mkdir -p "$bin"
  cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  if [ "$1" = --output ]; then cp "$FAKE_TARBALL" "$2"; fi
  shift
done
EOF
  cat >"$bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"$CALLS"
while [ "${1:-}" != "${1#-}" ]; do shift; done
"$@"
EOF
  cat >"$bin/install" <<'EOF'
#!/usr/bin/env bash
echo "install $*" >>"$CALLS"
EOF
  cat >"$bin/netbird" <<'EOF'
#!/usr/bin/env bash
echo "netbird $* key=${NB_SETUP_KEY:-} url=${NB_MANAGEMENT_URL:-}" >>"$CALLS"
if [ "${1:-}" = status ]; then echo "Management: ${STUB_MANAGEMENT:-Connected}"; fi
EOF
  cat >"$bin/timeout" <<'EOF'
#!/usr/bin/env bash
[ "${STUB_REACHABLE:-yes}" = yes ]
EOF
  cat >"$bin/sleep" <<'EOF'
#!/usr/bin/env bash
EOF
  if ! PATH=/usr/bin:/bin command -v sha256sum >/dev/null; then
    cat >"$bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
exec shasum -a 256 "$@"
EOF
  fi
  chmod +x "$bin"/*
  : >"$work/calls"
}

run() {
  stubs
  env -i HOME="$HOME" PATH="$work/bin:/usr/bin:/bin" CALLS="$work/calls" \
    FAKE_TARBALL="$work/netbird.tar.gz" RUNNER_TEMP="$work" RUNNER_ARCH=X64 \
    "$@" >"$work/out" 2>&1
}

checksum() { (sha256sum "$work/netbird.tar.gz" 2>/dev/null || shasum -a 256 "$work/netbird.tar.gz") | cut -d' ' -f1; }

check() {
  local name=$1
  shift
  if "$@"; then
    passed=$((passed + 1))
    echo "ok   $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name"
    sed 's/^/     /' "$work/out" "$work/calls"
  fi
}

install_sh=$root/scripts/install.sh
connect_sh=$root/scripts/connect.sh
default_version=$(sed -n 's/^readonly DEFAULT_VERSION=//p' "$install_sh")

t_rejects_unknown_arch() {
  run RUNNER_ARCH=X86 NB_VERSION="$default_version" bash "$install_sh" && return 1
  grep -q 'not supported' "$work/out"
}
check "install rejects an unsupported runner architecture" t_rejects_unknown_arch

t_requires_checksum_for_other_version() {
  run NB_VERSION=0.1.0 bash "$install_sh" && return 1
  grep -q 'checksum' "$work/out" && ! grep -q '^install' "$work/calls"
}
check "install refuses a non-default version without a checksum" t_requires_checksum_for_other_version

t_rejects_bad_checksum() {
  run NB_VERSION="$default_version" bash "$install_sh" && return 1
  grep -q 'does not match' "$work/out" && ! grep -q '^install' "$work/calls"
}
check "install refuses a tarball that does not match the pinned checksum" t_rejects_bad_checksum

t_installs_on_match() {
  local sum
  sum=$(checksum)
  run NB_VERSION=0.1.0 NB_CHECKSUM="$sum" bash "$install_sh" || return 1
  grep -q '^install .*netbird /usr/local/bin/netbird' "$work/calls"
}
check "install installs the binary when the checksum matches" t_installs_on_match

t_requires_setup_key() {
  run NB_MANAGEMENT_URL=https://nb.example.com bash "$connect_sh" && return 1
  grep -q 'setup-key' "$work/out"
}
check "connect fails without a setup key" t_requires_setup_key

t_masks_url_and_host() {
  run NB_SETUP_KEY=secret-key NB_MANAGEMENT_URL=https://nb.example.com:443 bash "$connect_sh" || return 1
  grep -qx '::add-mask::https://nb.example.com:443' "$work/out" &&
    grep -qx '::add-mask::nb.example.com' "$work/out"
}
check "connect masks the management URL and its host" t_masks_url_and_host

t_key_stays_off_argv() {
  run NB_SETUP_KEY=secret-key NB_MANAGEMENT_URL=https://nb.example.com bash "$connect_sh" || return 1
  grep -q '^netbird up  *key=secret-key url=https://nb.example.com' "$work/calls" &&
    ! grep -q '^sudo .*secret-key' "$work/calls"
}
check "connect passes the key through the environment, not the command line" t_key_stays_off_argv

t_waits_for_target() {
  run NB_SETUP_KEY=k NB_MANAGEMENT_URL=https://nb.example.com WAIT_FOR=192.0.2.1:8081 TIMEOUT=3 bash "$connect_sh"
}
check "connect succeeds once the wait-for target answers" t_waits_for_target

t_times_out() {
  run STUB_REACHABLE=no NB_SETUP_KEY=k NB_MANAGEMENT_URL=https://nb.example.com WAIT_FOR=192.0.2.1:8081 TIMEOUT=3 bash "$connect_sh" && return 1
  grep -q '192.0.2.1:8081' "$work/out"
}
check "connect fails when the wait-for target never answers" t_times_out

t_waits_for_management() {
  run STUB_MANAGEMENT=Disconnected NB_SETUP_KEY=k NB_MANAGEMENT_URL=https://nb.example.com TIMEOUT=3 bash "$connect_sh" && return 1
  grep -q 'management' "$work/out"
}
check "connect fails when management never connects" t_waits_for_management

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
