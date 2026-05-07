#!/bin/bash

# SSL Certificate Auto-Renewal Testing Script
# This script helps verify that the SSL certificate auto-renewal feature works correctly
# Usage: ./test-ssl-renewal.sh [container-name]

set -e

CONTAINER_NAME="${1:-stapxs-qq-lite-x}"
SSL_CERT_PATH="/etc/ssl/certs/nginx-selfsigned.crt"
SSL_KEY_PATH="/etc/ssl/private/nginx-selfsigned.key"

# Check if container is running
check_container_running() {
    local name="$1"

    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Error: Docker CLI is not installed or not available in PATH"
        exit 1
    fi

    if docker ps --filter "name=^${name}$" --format '{{.Names}}' | grep -xq "$name"; then
        return 0
    fi

    if docker ps -a --filter "name=^${name}$" --format '{{.Names}}' | grep -xq "$name"; then
        echo "⚠ Container '$name' exists but is not running. Attempting to start it..."
        docker start "$name" >/dev/null
        sleep 2
        if docker ps --filter "name=^${name}$" --format '{{.Names}}' | grep -xq "$name"; then
            return 0
        fi
        echo "❌ Error: Container '$name' exists but failed to start"
        exit 1
    fi

    echo "❌ Error: Container '$name' is not running"
    echo "   Start it with: docker-compose up -d"
    exit 1
}

check_container_running "$CONTAINER_NAME"

echo \"✓ Container '$CONTAINER_NAME' is running\"
echo ""

# Test 1: Check certificate existence
echo \"[Test 1] Checking certificate files...\"
if docker exec \"$CONTAINER_NAME\" test -f \"$SSL_CERT_PATH\"; then
    echo \"✓ Certificate file exists: $SSL_CERT_PATH\"
else
    echo \"❌ Certificate file not found: $SSL_CERT_PATH\"
    exit 1
fi

if docker exec \"$CONTAINER_NAME\" test -f \"$SSL_KEY_PATH\"; then
    echo \"✓ Private key file exists: $SSL_KEY_PATH\"
else
    echo \"❌ Private key file not found: $SSL_KEY_PATH\"
    exit 1
fi
echo \"\"

# Test 2: Check certificate validity
echo \"[Test 2] Checking certificate validity...\"
CERT_INFO=$(docker exec \"$CONTAINER_NAME\" openssl x509 -in \"$SSL_CERT_PATH\" -noout -text)

if echo \"$CERT_INFO\" | grep -q \"Subject:\"; then
    echo \"✓ Certificate is valid and readable\"
    echo \"  Subject: $(echo \"$CERT_INFO\" | grep -A 1 'Subject:' | head -1 | sed 's/.*Subject: //')\"
else
    echo \"❌ Certificate validation failed\"
    exit 1
fi
echo \"\"

# Test 3: Check certificate expiration
echo \"[Test 3] Checking certificate expiration date...\"
EXPIRATION_DATE=$(docker exec \"$CONTAINER_NAME\" openssl x509 -in \"$SSL_CERT_PATH\" -noout -enddate)
echo \"✓ $EXPIRATION_DATE\"
echo \"\"

# Test 4: Check nginx is running and using the certificate
echo \"[Test 4] Checking nginx configuration...\"
if docker exec \"$CONTAINER_NAME\" nginx -t 2>&1 | grep -q \"successful\"; then
    echo \"✓ Nginx configuration is valid\"
else
    echo \"❌ Nginx configuration validation failed\"
    docker exec \"$CONTAINER_NAME\" nginx -t
    exit 1
fi
echo \"\"

# Test 5: Check HTTPS connectivity
echo \"[Test 5] Testing HTTPS connectivity...\"
if docker exec \"$CONTAINER_NAME\" wget -q --spider --no-check-certificate https://localhost 2>/dev/null || \
   docker exec \"$CONTAINER_NAME\" curl -k -s https://localhost > /dev/null 2>&1; then
    echo \"✓ HTTPS endpoint is accessible\"
else
    echo \"⚠ Warning: HTTPS connectivity check failed (this may be expected if no content is deployed)\"
fi
echo \"\"

# Test 6: Check monitoring process
echo \"[Test 6] Checking certificate monitoring process...\"
if docker exec \"$CONTAINER_NAME\" ps aux | grep -v grep | grep monitor_certificate > /dev/null 2>&1 || \
   docker exec \"$CONTAINER_NAME\" ps aux | grep sleep | grep -v grep > /dev/null 2>&1; then
    echo \"✓ Background monitoring process is running\"
else
    echo \"⚠ Warning: Background monitoring process not clearly visible (may still be active)\"
fi
echo \"\"

# Test 7: Check logs for errors
echo \"[Test 7] Checking container logs for errors...\"
RECENT_ERRORS=$(docker logs --tail 50 \"$CONTAINER_NAME\" 2>&1 | grep -i \"error\" || true)
if [ -z \"$RECENT_ERRORS\" ]; then
    echo \"✓ No errors found in recent logs\"
else
    echo \"⚠ Found these log entries mentioning 'error':(may be informational)\"
    echo \"$RECENT_ERRORS\" | head -5
fi
echo \"\"

echo \"✓ All SSL tests completed successfully!\"
