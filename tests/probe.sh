#!/usr/bin/env bash
set -uo pipefail

PROBE_BLOCKED_URL="${PROBE_BLOCKED_URL:-https://chatgpt.com/}"
PROBE_ALLOWED_URL="${PROBE_ALLOWED_URL:-https://example.com/}"
PROBE_LOCAL_URL="${PROBE_LOCAL_URL:-http://127.0.0.1:11434/}"
FAILURES=0

pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; FAILURES=$((FAILURES + 1)); }

http_code() {
  curl -s -o /dev/null -m 8 -w '%{http_code}' "$@"
}

check_no_default_route() {
  local routes
  routes=$(ip route show default)
  if [ -z "$routes" ]; then pass "no default route in namespace"; else fail "default route present: $routes"; fi
}

check_direct_connection_fails() {
  local code
  code=$(http_code --noproxy '*' "$PROBE_BLOCKED_URL")
  if [ "$code" = "000" ]; then pass "direct $PROBE_BLOCKED_URL unreachable"; else fail "direct $PROBE_BLOCKED_URL answered $code: namespace has a way out"; fi
}

check_proxy_denies_blocked_host() {
  local code
  code=$(http_code "$PROBE_BLOCKED_URL")
  if [ "$code" = "000" ]; then pass "proxied $PROBE_BLOCKED_URL refused"; else fail "proxied $PROBE_BLOCKED_URL answered $code: remove it from CODEX_NETJAIL_ALLOW"; fi
}

check_proxy_allows_allowed_host() {
  local code
  code=$(http_code "$PROBE_ALLOWED_URL")
  if [ "$code" != "000" ]; then pass "proxied $PROBE_ALLOWED_URL answered $code"; else fail "proxied $PROBE_ALLOWED_URL unreachable: add its host:443 to CODEX_NETJAIL_ALLOW"; fi
}

check_local_model_port_reachable() {
  local code
  code=$(http_code "$PROBE_LOCAL_URL")
  if [ "$code" != "000" ]; then pass "local model port answered $code"; else fail "local model port unreachable: start ollama or set CODEX_NETJAIL_OLLAMA"; fi
}

main() {
  check_no_default_route
  check_direct_connection_fails
  check_proxy_denies_blocked_host
  check_proxy_allows_allowed_host
  check_local_model_port_reachable
  [ "$FAILURES" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main "$@"; fi
