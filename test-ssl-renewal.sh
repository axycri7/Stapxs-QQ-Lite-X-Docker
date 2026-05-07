#!/usr/bin/env bash
# SSL certificate smoke test for the nginx container.
# Usage: ./test-ssl-renewal.sh [container-name]
set -euo pipefail

CONTAINER_NAME="${1:-stapxs-qq-lite-x}"
SSL_CERT_PATH="/etc/ssl/certs/nginx-selfsigned.crt"
SSL_KEY_PATH="/etc/ssl/private/nginx-selfsigned.key"

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*" >&2; exit 1; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

command -v docker >/dev/null 2>&1 || fail "docker CLI not found on PATH"

ensure_running() {
    local name=$1
    if docker ps --filter "name=^${name}$" --format '{{.Names}}' | grep -qx "$name"; then
        return 0
    fi
    if docker ps -a --filter "name=^${name}$" --format '{{.Names}}' | grep -qx "$name"; then
        warn "Container '$name' exists but is stopped; starting..."
        docker start "$name" >/dev/null
        sleep 2
        docker ps --filter "name=^${name}$" --format '{{.Names}}' | grep -qx "$name" \
            || fail "Container '$name' failed to start"
        return 0
    fi
    fail "Container '$name' not found (hint: docker compose up -d)"
}

in_container() { docker exec "$CONTAINER_NAME" "$@"; }

ensure_running "$CONTAINER_NAME"
pass "container '$CONTAINER_NAME' running"

step "Certificate files"
in_container test -f "$SSL_CERT_PATH" && pass "cert present at $SSL_CERT_PATH" || fail "cert missing"
in_container test -f "$SSL_KEY_PATH"  && pass "key present at $SSL_KEY_PATH"  || fail "key missing"

step "Certificate contents"
cert_info=$(in_container openssl x509 -in "$SSL_CERT_PATH" -noout -subject -enddate)
subject=$(printf '%s\n' "$cert_info" | awk -F'subject= ?' '/^subject/{print $2}')
enddate=$(printf '%s\n' "$cert_info" | awk -F'notAfter= ?' '/^notAfter/{print $2}')
[ -n "$subject" ] && pass "subject: $subject" || fail "unreadable subject"
[ -n "$enddate" ] && pass "expires: $enddate" || fail "unreadable enddate"

step "Nginx configuration"
if in_container nginx -t >/dev/null 2>&1; then
    pass "nginx -t ok"
else
    in_container nginx -t || true
    fail "nginx configuration invalid"
fi

step "HTTPS endpoint"
if in_container wget -q --spider --no-check-certificate https://localhost/health; then
    pass "https://localhost/health reachable"
else
    warn "HTTPS health probe failed (may be expected until content is deployed)"
fi

step "Certificate renewal monitor"
if in_container sh -c "ps -o pid,args 2>/dev/null || ps w" | grep -E 'entrypoint\.sh|monitor_certificate|sleep' | grep -v grep >/dev/null; then
    pass "monitor process running"
else
    warn "monitor process not visibly running"
fi

step "Recent container errors"
errors=$(docker logs --tail 100 "$CONTAINER_NAME" 2>&1 | grep -iE 'error|fail' || true)
if [ -z "$errors" ]; then
    pass "no errors in recent logs"
else
    warn "found log lines mentioning error/fail:"
    printf '%s\n' "$errors" | head -5 | sed 's/^/    /'
fi

printf '\n\033[32mAll SSL smoke tests completed\033[0m\n'
