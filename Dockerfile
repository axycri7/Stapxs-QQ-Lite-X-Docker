# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# Stage 1: build the Vue app from upstream source.
# ---------------------------------------------------------------------------
ARG NODE_VERSION=20-alpine

FROM node:${NODE_VERSION} AS builder

ARG UPSTREAM_REPO=https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X.git
ARG UPSTREAM_REF=test
ARG UPSTREAM_SHA=
ARG PNPM_VERSION=10.32.1

RUN apk add --no-cache git
RUN corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate

WORKDIR /src

RUN --mount=type=cache,target=/root/.cache/git \
    if [ -n "${UPSTREAM_SHA}" ]; then \
        git init --quiet && \
        git remote add origin "${UPSTREAM_REPO}" && \
        git fetch --depth 1 origin "${UPSTREAM_SHA}" && \
        git checkout --quiet FETCH_HEAD; \
    else \
        git clone --depth 1 --branch "${UPSTREAM_REF}" --recurse-submodules "${UPSTREAM_REPO}" . ; \
    fi && \
    git submodule update --init --recursive --depth 1 || true

RUN --mount=type=cache,target=/pnpm-store \
    pnpm config set store-dir /pnpm-store && \
    pnpm install --frozen-lockfile --prefer-offline

RUN pnpm build

# ---------------------------------------------------------------------------
# Stage 2: nginx runtime.
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine-slim

LABEL org.opencontainers.image.title="Stapxs-QQ-Lite-X Docker"
LABEL org.opencontainers.image.description="Unofficial Docker image for Chzxxuanzheng/Stapxs-QQ-Lite-X"
LABEL org.opencontainers.image.source="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.url="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.documentation="https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker"
LABEL org.opencontainers.image.licenses="AGPL-3.0"
LABEL org.opencontainers.image.authors="axycrio"

RUN apk add --no-cache openssl tini && \
    rm -f /etc/nginx/conf.d/default.conf

COPY nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
COPY --from=builder /src/dist /usr/share/nginx/html

RUN chmod +x /entrypoint.sh && \
    chmod 644 /etc/nginx/conf.d/default.conf && \
    # fallback index in case the upstream build produced nothing at dist root
    [ -f /usr/share/nginx/html/index.html ] || \
      printf '%s' '<!DOCTYPE html><title>Stapxs-QQ-Lite-X</title><p>Build artifacts missing.</p>' \
      > /usr/share/nginx/html/index.html

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
