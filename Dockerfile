FROM nginx:1.27-alpine-slim

LABEL org.opencontainers.image.title="Stapxs-QQ-Lite-X Docker"
LABEL org.opencontainers.image.description="Unofficial Docker image for Chzxxuanzheng/Stapxs-QQ-Lite-X"
LABEL org.opencontainers.image.source="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.url="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.documentation="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.licenses="AGPL-3.0"
LABEL org.opencontainers.image.authors="axycrio"

RUN apk add --no-cache \
    openssl \
    coreutils \
    wget && \
    rm -rf /etc/nginx/conf.d/default.conf

COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/
COPY entrypoint.sh /entrypoint.sh

# Default HTML page for SSL testing / fallback
RUN mkdir -p /usr/share/nginx/html && \
    echo '<!DOCTYPE html><html><head><title>SSL Test</title></head><body><h1>SSL Certificate Test Page</h1><p>This is a test page for SSL certificate renewal.</p></body></html>' > /usr/share/nginx/html/index.html

# Copy frontend build artifacts if provided
COPY dist/ /usr/share/nginx/html/

RUN chmod +x /entrypoint.sh && \
    chmod 644 /etc/nginx/conf.d/default.conf

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]