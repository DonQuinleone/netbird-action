#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$1" >&2
  exit 1
}

[ -n "${NB_SETUP_KEY:-}" ] || fail "The setup-key input is empty."
[ -n "${NB_MANAGEMENT_URL:-}" ] || fail "The management-url input is empty."

host=${NB_MANAGEMENT_URL#*://}
host=${host%%[:/]*}
echo "::add-mask::$NB_MANAGEMENT_URL"
echo "::add-mask::$host"

export NB_SETUP_KEY NB_MANAGEMENT_URL NB_HOSTNAME
sudo netbird service install
sudo netbird service start
sudo --preserve-env=NB_SETUP_KEY,NB_MANAGEMENT_URL,NB_HOSTNAME netbird up

timeout_seconds=${TIMEOUT:-60}
deadline=$((SECONDS + timeout_seconds))

management_connected() {
  sudo netbird status 2>/dev/null | grep -q 'Management: Connected'
}

target_answers() {
  local target_host=${WAIT_FOR%:*} target_port=${WAIT_FOR##*:}
  timeout 2 bash -c ">/dev/tcp/$target_host/$target_port" 2>/dev/null
}

if [ -n "${WAIT_FOR:-}" ]; then
  ready=target_answers
  waiting_for="$WAIT_FOR to accept connections"
else
  ready=management_connected
  waiting_for="the management server to connect"
fi

until "$ready"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    sudo netbird status >&2 || true
    fail "Timed out after ${timeout_seconds}s waiting for $waiting_for."
  fi
  sleep 2
done

echo "Connected to NetBird"
