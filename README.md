Unofficial Docker image for [Chzxxuanzheng/Stapxs-QQ-Lite-X](https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X) with automatic builds from upstream via GitHub Actions.

## Quick Start

### Using the pre-built image

```bash
docker run -d -p 80:80 -p 443:443 \
  -v ssl-certs:/etc/ssl/certs \
  -v ssl-private:/etc/ssl/private \
  --name stapxs-qq-lite-x \
  ghcr.io/axycri7/stapxs-qq-lite-x-docker:latest
```

Or with Docker Compose:

```bash
curl -fsSL https://raw.githubusercontent.com/axycri7/Stapxs-QQ-Lite-X-Docker/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/axycri7/Stapxs-QQ-Lite-X-Docker/main/.env.example -o .env
docker compose up -d
```

### Building from source

The Dockerfile clones and builds upstream inside a multi-stage build, so no pre-checkout or local Node/pnpm is required:

```bash
git clone https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker
cd Stapxs-QQ-Lite-X-Docker
docker build -t stapxs-qq-lite-x:latest .
docker run -d -p 80:80 -p 443:443 --name stapxs-qq-lite-x stapxs-qq-lite-x:latest
```

Build arguments:

| Arg             | Default                                                  | Purpose                                |
| --------------- | -------------------------------------------------------- | -------------------------------------- |
| `UPSTREAM_REPO` | `https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X.git`  | Source repo to clone                   |
| `UPSTREAM_REF`  | `test`                                                   | Branch or tag when `UPSTREAM_SHA` empty |
| `UPSTREAM_SHA`  | *(unset)*                                                | Pin to an exact commit (reproducible)  |
| `NODE_VERSION`  | `20-alpine`                                              | Node base image for the builder stage  |
| `PNPM_VERSION`  | `10.32.1`                                                | Matches upstream `packageManager`      |

Example:

```bash
docker build \
  --build-arg UPSTREAM_REF=main \
  --build-arg UPSTREAM_SHA=<40-char-sha> \
  -t stapxs-qq-lite-x:pinned .
```

## Configuration

All runtime options are environment variables consumed by `entrypoint.sh`. Defaults are safe for local use; see `.env.example` for the full list.

| Variable                     | Default                                                    | Notes                          |
| ---------------------------- | ---------------------------------------------------------- | ------------------------------ |
| `SSL_VALIDITY_DAYS`          | `90`                                                       | Lifetime of generated cert     |
| `SSL_RENEWAL_THRESHOLD_DAYS` | `7`                                                        | Renew when fewer days remain   |
| `SSL_CHECK_INTERVAL_HOURS`   | `24`                                                       | Monitor polling interval       |
| `SSL_KEY_SIZE`               | `4096`                                                     | RSA key size                   |
| `SSL_SUBJECT`                | `/C=US/ST=State/L=City/O=Organization/CN=localhost`        | Certificate DN                 |
| `SSL_CERT`, `SSL_KEY`        | `/etc/ssl/{certs,private}/nginx-selfsigned.*`              | Cert/key paths in the image    |

For production use, mount your own certificate into `SSL_CERT` / `SSL_KEY` and the auto-renewal monitor will leave it alone until it is within the threshold window.

## Health check

The image exposes an unauthenticated `/health` endpoint on both HTTP and HTTPS:

```bash
curl -k https://localhost/health   # -> healthy
```

`docker inspect --format='{{.State.Health.Status}}' stapxs-qq-lite-x` reflects the same probe.

## Smoke test

After `docker compose up -d`, run:

```bash
./test-ssl-renewal.sh stapxs-qq-lite-x
```

This verifies certificate presence, nginx config validity, the HTTPS endpoint, and the renewal monitor.

## Upstream project

All credit for the application itself belongs to [Chzxxuanzheng/Stapxs-QQ-Lite-X](https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X) and its contributors.

## License

The upstream project is licensed under AGPL-3.0. This repository's Docker build scripts and workflows are also released under AGPL-3.0.

Corresponding source for the application is at https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X.
