#!/bin/sh
set -eu

SSL_CERT="${SSL_CERT:-/etc/ssl/certs/nginx-selfsigned.crt}"
SSL_KEY="${SSL_KEY:-/etc/ssl/private/nginx-selfsigned.key}"
SSL_KEY_SIZE="${SSL_KEY_SIZE:-4096}"
SSL_SUBJECT="${SSL_SUBJECT:-/C=US/ST=State/L=City/O=Organization/CN=localhost}"
SSL_VALIDITY_DAYS="${SSL_VALIDITY_DAYS:-90}"
SSL_RENEWAL_THRESHOLD_DAYS="${SSL_RENEWAL_THRESHOLD_DAYS:-7}"
SSL_CHECK_INTERVAL_HOURS="${SSL_CHECK_INTERVAL_HOURS:-24}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

mkdir -p "$(dirname "$SSL_CERT")" "$(dirname "$SSL_KEY")"

generate_ssl_cert() {
    log "Generating self-signed SSL certificate (valid for $SSL_VALIDITY_DAYS days)..."
    if ! openssl req -x509 -nodes -days "$SSL_VALIDITY_DAYS" -newkey "rsa:$SSL_KEY_SIZE" \
        -keyout "$SSL_KEY" -out "$SSL_CERT" -subj "$SSL_SUBJECT" 2>/dev/null; then
        log "ERROR: Failed to generate SSL certificate" >&2
        return 1
    fi
    chmod 600 "$SSL_KEY"
    chmod 644 "$SSL_CERT"
    log "SSL certificate generated."
}

# Portable cert-expiration check. Uses openssl's own -checkend to avoid the
# platform-specific `date` parsing that the previous implementation relied on
# (the original `date -j -f` is BSD/macOS only and silently fails on Alpine).
# Returns remaining days as a non-negative integer via stdout; prints 0 when
# the cert is already expired or unreadable.
check_cert_days_remaining() {
    [ -f "$SSL_CERT" ] || { echo 0; return 1; }
    # Binary-search up to SSL_VALIDITY_DAYS + 1 to find the largest N
    # for which `openssl x509 -checkend $((N*86400))` still reports "will not expire".
    lo=0
    hi=$((SSL_VALIDITY_DAYS + 1))
    while [ "$lo" -lt "$hi" ]; do
        mid=$(((lo + hi + 1) / 2))
        if openssl x509 -in "$SSL_CERT" -noout -checkend $((mid * 86400)) >/dev/null 2>&1; then
            lo=$mid
        else
            hi=$((mid - 1))
        fi
    done
    echo "$lo"
}

reload_nginx() {
    [ -f /var/run/nginx.pid ] || return 1
    log "Reloading nginx configuration..."
    if kill -s HUP "$(cat /var/run/nginx.pid)" 2>/dev/null; then
        log "Nginx reloaded."
        return 0
    fi
    return 1
}

monitor_certificate() {
    while :; do
        days_remaining=$(check_cert_days_remaining || echo 0)
        if [ "$days_remaining" -lt "$SSL_RENEWAL_THRESHOLD_DAYS" ]; then
            log "Certificate expiring soon ($days_remaining days remaining). Renewing..."
            if generate_ssl_cert; then
                reload_nginx || true
                log "Certificate renewed."
            else
                log "WARNING: Certificate renewal failed." >&2
            fi
        else
            log "Certificate valid for $days_remaining days."
        fi
        sleep $((SSL_CHECK_INTERVAL_HOURS * 3600))
    done
}

if [ ! -f "$SSL_CERT" ]; then
    generate_ssl_cert
else
    log "Existing certificate found, valid for $(check_cert_days_remaining) days."
fi

if ! nginx -t 2>&1; then
    log "ERROR: Nginx configuration is invalid" >&2
    exit 1
fi

log "Starting nginx..."
monitor_certificate &
CERT_MONITOR_PID=$!
trap 'kill $CERT_MONITOR_PID 2>/dev/null || true; exit 0' TERM INT
exec nginx -g "daemon off;"
