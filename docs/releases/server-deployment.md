# Server deployment

This guide deploys the authoritative Besprotoritsa server as a Docker Compose
service. The process keeps room snapshots and command journals in the named
Docker volume `besprotoritsa-server-data`; do not remove that volume during an
ordinary upgrade.

## Requirements

For up to 100 concurrent rooms, provision at least:

- 1 vCPU
- 1 GB RAM
- Linux with Docker Engine and the Docker Compose plugin
- a public IPv4/IPv6 address and a DNS `A`/`AAAA` record for the server name
- TCP ports 80 and 443 open to the Internet; port 8080 stays bound to loopback

Install Docker Engine and its Compose plugin using the package repository for
your Linux distribution. Confirm the installation with:

```sh
docker --version
docker compose version
```

## First deployment

Clone the repository on the server and start the service from its root:

```sh
git clone <repository-url> /srv/besprotoritsa
cd /srv/besprotoritsa
docker compose up -d --build
docker compose ps
curl --fail http://127.0.0.1:8080/healthz
```

The image runs as a non-root user, persists state at `/data`, and restarts
automatically after a crash or host reboot (`restart: unless-stopped`). Docker
marks it unhealthy if `GET /healthz` stops returning HTTP 200.

Put a TLS reverse proxy such as Nginx in front of `127.0.0.1:8080`. Its proxy
location must support WebSocket upgrades for both `/rooms/<code>/ws` and
`/rooms/<code>/lobby/ws`:

```nginx
location / {
  proxy_pass http://127.0.0.1:8080;
  proxy_http_version 1.1;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
}
```

## TLS certificate with Let's Encrypt / Certbot

Before requesting a certificate, replace `api.example.com` below with the
actual DNS name, point its `A`/`AAAA` record at this server, and ensure Nginx
is serving that name on port 80. On Debian or Ubuntu:

```sh
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d api.example.com --redirect
```

Certbot installs the HTTPS virtual host and renewal timer. Test automatic
renewal, then verify the public health endpoint:

```sh
sudo certbot renew --dry-run
curl --fail https://api.example.com/healthz
```

The certificate private key is managed by Certbot on the host. Do not place it
in the application repository or Docker image.

## Update and rollback

To deploy a new revision, build it and recreate only the application
container. The named volume is preserved:

```sh
cd /srv/besprotoritsa
git fetch --tags origin
git pull --ff-only
docker compose up -d --build --remove-orphans
docker compose ps
curl --fail http://127.0.0.1:8080/healthz
```

If the revision must be rolled back, check out the previous known-good commit
and run the same `docker compose up -d --build` command. Inspect failures with
`docker compose logs --tail=100 besprotoritsa-server`. Do not run `docker
compose down -v` during updates: `-v` deletes the persisted room data.

## Image-size check

The multi-stage build uses `dart:stable` only to compile AOT executables; the
runtime uses a small distroless C/C++ base and should remain below 50 MB.
Verify the actual image after a build:

```sh
docker image inspect besprotoritsa-server:latest \
  --format '{{.Size}}' | awk '{printf "%.1f MB\\n", $1 / 1048576}'
```
