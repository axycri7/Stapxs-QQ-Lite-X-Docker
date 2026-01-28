A Docker image for [Chzxxuanzheng/Stapxs-QQ-Lite-X](https://github.com/Chzxxuanzheng/Stapxs-QQ-Lite-X) with automatic builds via GitHub Actions.

### Manual build

```bash
git clone https://github.com/axycri7/Stapxs-QQ-Lite-X-Docker
cd Stapxs-QQ-Lite-X-Docker
docker build -t stapxs-qq-lite-x:latest .
```

### Running the Container

```bash
docker run -d \
  --name stapxs-qq \
  -p 80:80 \
  stapxs-qq-lite-x:latest
```

Then access the application at `http://localhost`