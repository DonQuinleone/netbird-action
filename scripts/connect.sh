#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$1" >&2
  exit 1
}

[ -n "${NB_SETUP_KEY:-}" ] || fail "The setup-key input is empty."
[[ $NB_SETUP_KEY != *$'\n'* ]] || fail "The setup-key input spans more than one line."
echo "::add-mask::$NB_SETUP_KEY"

[[ ${NB_MANAGEMENT_URL:-} =~ ^https?://([A-Za-z0-9.-]+)(:[0-9]{1,5})?/?$ ]] ||
  fail "The management-url input must look like https://host or https://host:port."
host=${BASH_REMATCH[1]}
echo "::add-mask::$NB_MANAGEMENT_URL"
echo "::add-mask::$host"

timeout_seconds=${TIMEOUT:-60}
[[ $timeout_seconds =~ ^[0-9]{1,4}$ ]] || fail "The timeout input must be a whole number of seconds."

if [ -n "${WAIT_FOR:-}" ]; then
  [[ $WAIT_FOR =~ ^([A-Za-z0-9.-]+):([0-9]{1,5})$ ]] || fail "The wait-for input must look like host:port."
  target_host=${BASH_REMATCH[1]}
  target_port=${BASH_REMATCH[2]}
fi

export NB_SETUP_KEY NB_MANAGEMENT_URL NB_HOSTNAME
sudo netbird service install
sudo netbird service start
sudo --preserve-env=NB_SETUP_KEY,NB_MANAGEMENT_URL,NB_HOSTNAME netbird up

management_connected() {
  sudo netbird status 2>/dev/null | grep -q 'Management: Connected'
}

target_answers() {
  # shellcheck disable=SC2016
  timeout 2 bash -c 'exec 3<>"/dev/tcp/$0/$1"' "$target_host" "$target_port" 2>/dev/null
}

if [ -n "${WAIT_FOR:-}" ]; then
  ready=target_answers
  waiting_for="$WAIT_FOR to accept connections"
else
  ready=management_connected
  waiting_for="the management server to connect"
fi

deadline=$((SECONDS + timeout_seconds))
until "$ready"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    sudo netbird status >&2 || true
    fail "Timed out after ${timeout_seconds}s waiting for $waiting_for."
  fi
  sleep 2
done

echo "Connected to NetBird"
