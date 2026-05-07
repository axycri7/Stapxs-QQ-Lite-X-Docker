FROM nginx:1.27-alpine-slim

LABEL maintainer="axycrio"
LABEL description="Docker image for Chzxxuanzheng/Stapxs-QQ-Lite-X"
LABEL version="1.0"
LABEL security="scan-required"

RUN apk add --no-cache openssl coreutils && \
    rm -rf /etc/nginx/conf.d/default.conf

COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/

# Create default HTML content for SSL testing
RUN mkdir -p /usr/share/nginx/html && \
    echo '<!DOCTYPE html><html><head><title>SSL Test</title></head><body><h1>SSL Certificate Test Page</h1><p>This is a test page for SSL certificate renewal.</p></body></html>' > /usr/share/nginx/html/index.html

# Copy dist if it exists (for production builds)
RUN if [ -d ./dist ]; then cp -r ./dist/* /usr/share/nginx/html/; fi

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chmod 644 /etc/nginx/conf.d/default.conf

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]