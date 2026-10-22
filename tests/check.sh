#!/usr/bin/env bash
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_LOCAL_PORT="${CHECK_LOCAL_PORT:-18434}"
CHECK_ALLOWED_HOST="${CHECK_ALLOWED_HOST:-example.com}"
CHECK_WORK="$(mktemp -d)"
SERVER_PID=""

stop_local_server() {
  [ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null
  rm -rf "$CHECK_WORK"
}

start_local_server() {
  python3 -I -m http.server "$CHECK_LOCAL_PORT" --bind 127.0.0.1 --directory "$CHECK_WORK" >/dev/null 2>&1 &
  SERVER_PID=$!
  sleep 0.5
}

check_log_records_deny() {
  if grep -q "DENY CONNECT chatgpt.com:443" "$CHECK_WORK/connect.log"; then
    echo "PASS proxy log records DENY chatgpt.com:443"
  else
    echo "FAIL proxy log has no DENY for chatgpt.com:443: see $CHECK_WORK/connect.log"
    return 1
  fi
}

main() {
  trap stop_local_server EXIT
  start_local_server
  CODEX_NETJAIL_LOG="$CHECK_WORK/connect.log" \
  CODEX_NETJAIL_ALLOW="$CHECK_ALLOWED_HOST:443" \
  CODEX_NETJAIL_OLLAMA="127.0.0.1:$CHECK_LOCAL_PORT" \
  CODEX_NETJAIL_CMD="bash $REPO/tests/probe.sh" \
  PROBE_LOCAL_URL="http://127.0.0.1:$CHECK_LOCAL_PORT/" \
  PROBE_ALLOWED_URL="https://$CHECK_ALLOWED_HOST/" \
    "$REPO/codex-netjail"
  local probe_status=$?
  check_log_records_deny
  local log_status=$?
  [ "$probe_status" -eq 0 ] && [ "$log_status" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main "$@"; fi
