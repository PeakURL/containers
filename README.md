# PeakURL

Official Docker image for PeakURL, a self-hosted URL shortener.

## Quick reference

- Image: `peakurl/peakurl`
- Source: [PeakURL/containers](https://github.com/PeakURL/containers)
- Core app: [PeakURL/PeakURL](https://github.com/PeakURL/PeakURL)
- Issues: [PeakURL/containers/issues](https://github.com/PeakURL/containers/issues)
- Supported architectures: `linux/amd64`, `linux/arm64`
- Tag style: version tags such as `1.0.12`, semver aliases such as `1.0` and `1`, plus `latest`

Use an exact version tag when you want a repeatable deployment.

## What is PeakURL?

PeakURL lets you run your own branded short links with analytics, a dashboard,
and a self-hosted PHP application you control.

This image packages the public PeakURL release archive and is intended for:

- a simple Docker Compose deployment
- a `docker run` deployment
- a reverse-proxy setup behind Nginx, Apache, Traefik, or another SSL terminator

Pull the image:

```bash
docker pull peakurl/peakurl:latest
```

## How to use this image

### Docker Compose

Recommended layout on a server:

```text
/var/www/sites/data/www/example.com/
├── compose.yaml
└── data/
    ├── mysql/
    └── peakurl/
```

Edit the values in `compose.yaml` before you start the stack:

- set `APACHE_SERVER_NAME` to your domain
- set the `127.0.0.1:8080:80` port mapping to the localhost port your host
  proxy will use
- set the MySQL credentials in the `db` service
- keep the PeakURL installer defaults in the `peakurl` service aligned with the
  MySQL values

Example `compose.yaml`:

```yaml
services:
  peakurl:
    image: peakurl/peakurl:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      APACHE_SERVER_NAME: example.com
      PEAKURL_INSTALL_DB_HOST_DEFAULT: db
      PEAKURL_INSTALL_DB_PORT_DEFAULT: "3306"
      PEAKURL_INSTALL_DB_NAME_DEFAULT: peakurl
      PEAKURL_INSTALL_DB_USER_DEFAULT: peakurl
      PEAKURL_INSTALL_DB_PASSWORD_DEFAULT: change-this-password
    ports:
      - "127.0.0.1:8080:80"
    volumes:
      - "./data/peakurl:/var/www/html"

  db:
    image: mysql:8.4
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: peakurl
      MYSQL_USER: peakurl
      MYSQL_PASSWORD: change-this-password
      MYSQL_ROOT_PASSWORD: change-this-root-password
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-name-resolve
    volumes:
      - "./data/mysql:/var/lib/mysql"
    healthcheck:
      test:
        - CMD-SHELL
        - mysqladmin ping -h 127.0.0.1 -p$$MYSQL_ROOT_PASSWORD --silent
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s
```

Create the directories first:

```bash
mkdir -p data/peakurl data/mysql
```

Start it with:

```bash
mkdir -p data/peakurl data/mysql
docker compose up -d
```

Then open `http://127.0.0.1:8080` and complete the installer.

If you already run Nginx or Apache on the host, keep the bind address on
`127.0.0.1` and proxy your public domain to `http://127.0.0.1:8080`.

If you want to expose the container directly instead, publish a normal host
port such as `8080:80`.

This default layout keeps the app files and MySQL data beside the
compose file, so each site folder stays self-contained and does not need a
separate `.env` file.

On first start, the container copies the bundled PeakURL release into
`./data/peakurl` and then runs directly from that directory. This keeps the
folder structure the same as the release ZIP.

### Docker Run

Create a deployment folder first:

```bash
mkdir -p peakurl-stack/data/peakurl peakurl-stack/data/mysql
cd peakurl-stack

docker network create peakurl
```

Start MySQL:

```bash
docker run -d \
  --name peakurl-db \
  --network peakurl \
  -e MYSQL_DATABASE=peakurl \
  -e MYSQL_USER=peakurl \
  -e MYSQL_PASSWORD=change-this-password \
  -e MYSQL_ROOT_PASSWORD=change-this-root-password \
  -v "$PWD/data/mysql:/var/lib/mysql" \
  mysql:8.4 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --skip-name-resolve
```

Then start PeakURL:

```bash
docker run -d \
  --name peakurl \
  --network peakurl \
  -p 127.0.0.1:8080:80 \
  -e APACHE_SERVER_NAME=example.com \
  -e PEAKURL_INSTALL_DB_HOST_DEFAULT=peakurl-db \
  -e PEAKURL_INSTALL_DB_PORT_DEFAULT=3306 \
  -e PEAKURL_INSTALL_DB_NAME_DEFAULT=peakurl \
  -e PEAKURL_INSTALL_DB_USER_DEFAULT=peakurl \
  -e PEAKURL_INSTALL_DB_PASSWORD_DEFAULT=change-this-password \
  -v "$PWD/data/peakurl:/var/www/html" \
  peakurl/peakurl:latest
```

Then open `http://127.0.0.1:8080` and finish the installer.

## Reverse proxy and SSL

PeakURL serves plain HTTP inside the container. SSL should be terminated by your
existing reverse proxy or load balancer.

Example host-side configs are included here:

- [Nginx](examples/nginx/peakurl.conf)
- [Apache](examples/apache/peakurl.conf)

Typical proxy target:

- `http://127.0.0.1:8080`
- or another localhost port you published for the container

## Configuration

For Docker Compose, edit the values directly in `compose.yaml`.

The main values most users change are:

- `APACHE_SERVER_NAME`
- the published host port in `ports`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- the matching `PEAKURL_INSTALL_DB_*` defaults

## Persistent data

By default the Compose setup keeps data in local folders beside the compose
file:

- `./data/peakurl`
  maps to `/var/www/html` and stores the full PeakURL app tree
- `./data/mysql`
  maps to `/var/lib/mysql` for the MySQL database

On first boot, `./data/peakurl` is populated from the bundled release package,
so files like `content/languages/*` stay exactly where the ZIP ships them.

If you prefer Docker-managed named volumes instead, you can replace those bind
mounts in your own compose file.

## Updating

For Docker Compose:

```bash
docker compose pull
docker compose up -d
```

For `docker run`, pull the new image and recreate the container with the same
volume and environment settings.

When a new PeakURL release is published, a matching container image is published
separately. Existing containers keep running their current image tag until you
pull the new tag and recreate them.

Because this image stores the full app tree in `./data/peakurl`, pulling a new
image does not replace app files that already exist in that mounted directory.
For a fresh app tree from a newer image, back up your site first, then recreate
or clear `./data/peakurl` before starting the updated container.

## License

PeakURL is released under the [MIT License](https://github.com/PeakURL/PeakURL/blob/main/LICENSE).
