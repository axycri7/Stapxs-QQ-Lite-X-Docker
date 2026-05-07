FROM nginx:1.27-alpine-slim

LABEL maintainer="axycrio"
LABEL description="Docker image for Chzxxuanzheng/Stapxs-QQ-Lite-X"
LABEL version="1.0"
LABEL security="scan-required"

RUN apk add --no-cache openssl coreutils && \
    rm -rf /etc/nginx/conf.d/default.conf

COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/

COPY ./dist /usr/share/nginx/html

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chmod 644 /etc/nginx/conf.d/default.conf

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]