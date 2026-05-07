#!/bin/sh

set -e

# SSL certificate paths
SSL_CERT="/etc/ssl/certs/nginx-selfsigned.crt"
SSL_KEY="/etc/ssl/private/nginx-selfsigned.key"
SSL_DIR="/etc/ssl/private"
SSL_VALIDITY_DAYS=90
SSL_RENEWAL_THRESHOLD_DAYS=7  # Renew when 7 days remaining
SSL_CHECK_INTERVAL_HOURS=24   # Check every 24 hours

# Create SSL directories
mkdir -p "$SSL_DIR" /etc/ssl/certs

# Function to generate SSL certificate
generate_ssl_cert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating self-signed SSL certificate (valid for $SSL_VALIDITY_DAYS days)..."
    
    if ! openssl req -x509 -nodes -days "$SSL_VALIDITY_DAYS" -newkey rsa:4096 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null; then
        echo "Error: Failed to generate SSL certificate" >&2
        return 1
    fi
    
    # Set appropriate permissions
    chmod 600 "$SSL_KEY"
    chmod 644 "$SSL_CERT"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSL certificate generated successfully."
    return 0
}

# Function to check certificate expiration
check_cert_expiration() {
    if [ ! -f "$SSL_CERT" ]; then
        return 1  # Certificate doesn't exist
    fi
    
    # Get expiration date in seconds since epoch
    exp_date=$(openssl x509 -enddate -noout -in "$SSL_CERT" 2>/dev/null | cut -d= -f2)
    exp_epoch=$(date -j -f "%b %d %T %Y %Z" "$exp_date" +%s 2>/dev/null || echo 0)
    current_epoch=$(date +%s)
    
    # Calculate days remaining
    seconds_remaining=$((exp_epoch - current_epoch))
    days_remaining=$((seconds_remaining / 86400))
    
    echo $days_remaining
}

# Function to reload nginx (graceful restart)
reload_nginx() {
    if [ -f /var/run/nginx.pid ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reloading nginx configuration..."
        if kill -s HUP $(cat /var/run/nginx.pid) 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nginx reloaded successfully."
            return 0
        fi
    fi
    return 1
}

# Function to monitor and renew certificate
monitor_certificate() {
    while true; do
        days_remaining=$(check_cert_expiration)
        
        if [ "$days_remaining" -lt "$SSL_RENEWAL_THRESHOLD_DAYS" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificate expiring soon ($days_remaining days remaining). Renewing..."
            if generate_ssl_cert; then
                reload_nginx || true
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificate renewed and nginx reloaded."
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Certificate renewal failed." >&2
            fi
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Certificate is valid for $days_remaining days."
        fi
        
        # Sleep for the specified interval
        sleep $((SSL_CHECK_INTERVAL_HOURS * 3600))
    done
}

# Generate initial certificate if it doesn't exist
if [ ! -f "$SSL_CERT" ]; then
    if ! generate_ssl_cert; then
        echo "Error: Failed to generate initial SSL certificate" >&2
        exit 1
    fi
else
    days_remaining=$(check_cert_expiration)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Existing certificate found, valid for $days_remaining days."
fi

# Verify nginx configuration
if ! nginx -t 2>&1; then
    echo "Error: Nginx configuration is invalid" >&2
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting nginx..."

# Start the certificate monitoring in the background
monitor_certificate &
CERT_MONITOR_PID=$!

# Start nginx in foreground, and ensure cleanup of monitor on exit
trap "kill $CERT_MONITOR_PID 2>/dev/null; exit" TERM INT

exec nginx -g "daemon off;"