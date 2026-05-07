Unofficial Docker image for [Chzxxuanzheng/Stapxs-QQ-Lite-X](https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X) with automatic builds via GitHub Actions.

## Quick Start

### Using Pre-built Image

```bash
docker run -d -p 80:80 -p 443:443 \
  -v ssl-certs:/etc/ssl/certs \
  -v ssl-private:/etc/ssl/private \
  --name stapxs-qq-lite-x \
  ghcr.io/axycri7/stapxs-qq-lite-x-docker:latest
```

Or with Docker Compose:

```yaml
# docker-compose.yml
services:
  stapxs-qq-lite-x:
    image: ghcr.io/axycri7/stapxs-qq-lite-x-docker:latest
    container_name: stapxs-qq-lite-x
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ssl-certs:/etc/ssl/certs
      - ssl-private:/etc/ssl/private
    restart: unless-stopped

volumes:
  ssl-certs:
  ssl-private:
```

Then run:

```bash
docker-compose up -d
```

### Manual Build

```bash
git clone https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker
cd Stapxs-QQ-Lite-X-Docker
docker build -t stapxs-qq-lite-x:latest .
docker run -d -p 80:80 -p 443:443 \
  -v ssl-certs:/etc/ssl/certs \
  -v ssl-private:/etc/ssl/private \
  --name stapxs-qq-lite-x \
  stapxs-qq-lite-x:latest
```
