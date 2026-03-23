#!/bin/sh

# Generate self-signed SSL certificate if it doesn't exist
if [ ! -f /etc/ssl/certs/nginx-selfsigned.crt ]; then
    echo "Generating self-signed SSL certificate..."
    mkdir -p /etc/ssl/private
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx-selfsigned.key \
        -out /etc/ssl/certs/nginx-selfsigned.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    echo "SSL certificate generated."
fi

# Start nginx
exec nginx -g "daemon off;"