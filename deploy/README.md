# Self-hosting FireBin

FireBin is a self-hosted electronics parts inventory: track quantity, package, brand, location, and vendor pricing across your parts, scan a distributor bag to add a part in one tap, and print bin and part labels. This directory is the deploy scaffold: a production `docker-compose.yml`, a `Caddyfile` for HTTPS, and an `.env` template.

FireBin is in alpha. Expect rough edges and keep a backup (see below).

## What you need

- A host with Docker and the Compose plugin (`docker compose version` should work).
- A domain name pointing at the host, with ports 80 and 443 reachable from the internet. Caddy uses them to get and renew a Let's Encrypt certificate. HTTPS is not optional in practice: the camera scanner and the WebUSB label printer only run on a secure origin (HTTPS, or `localhost`).

If you only want a local test on your LAN with no domain, see [Local test without a domain](#local-test-without-a-domain).

## Quick start

```sh
cp .env.example .env
```

Edit `.env` and set three values:

- `DOMAIN` to your hostname (for example `firebin.example.com`).
- `JWT_SECRET` to a generated secret. Run `openssl rand -base64 48` and paste the output. Keep it stable; changing it logs everyone out.
- `POSTGRES_PASSWORD` to any strong value. The database port is not published, so this guards the internal network only.

Pin `FIREBIN_VERSION` to a released tag (for example `26.7.1`) rather than `latest` so an image push does not change your running version underneath you.

Then bring it up:

```sh
docker compose up -d
```

Compose pulls `ghcr.io/fireball1725/firebin-api` and `firebin-web`, starts Postgres, and starts Caddy. The API runs its own database migrations on boot.

Open `https://your-domain`. The first account you register becomes the instance admin, and registration then closes. To add more people afterward, the admin creates them under Settings, or you set `REGISTRATION_ENABLED: "true"` in `docker-compose.yml` to allow open signup.

## How the pieces fit

- `postgres` holds all data on the `pgdata` volume.
- `firebin-api` is the REST backend on port 8080 (internal only). Datasheets and images live on the `attachments` volume.
- `firebin-web` serves the web client and proxies `/api` to `firebin-api`. The service must keep that name; the web container's nginx points at `http://firebin-api:8080`.
- `caddy` terminates TLS and reverse-proxies everything to `firebin-web`.

Only Caddy publishes ports (80 and 443). Nothing else is exposed to the host.

## Enrichment keys

Scanning a distributor bag matches the part locally at no API cost. To pull datasheets, parameters, images, and price breaks, add a Digi-Key API app (the V4 API, free). Put the client ID and secret either in `.env` (`DIGIKEY_CLIENT_ID` and `DIGIKEY_CLIENT_SECRET`) or in the UI under Settings, Enrichment. The UI also sets your display currency (CAD, USD, and others) and lets you turn individual providers on or off.

## Backups

FireBin gives you two layers, and you should use both.

App-level export lives under Settings, Data (admin only). Export writes a single JSON file that round-trips every table with types intact, and Import loads it back into an empty or partial database. Use it for config-level snapshots and for moving between hosts.

Database-level backup is your responsibility as the deployer, and it is the one that matters for disaster recovery. FireBin does not run automated backups yet (it is on the roadmap). Dump the Postgres volume on whatever schedule you keep for other services:

```sh
docker compose exec -T postgres pg_dump -U firebin firebin > firebin-$(date +%F).sql
```

Restore into a fresh database with `psql`. Keep the dumps off the host.

## Updating

Bump `FIREBIN_VERSION` in `.env` to the new tag, then:

```sh
docker compose pull
docker compose up -d
```

The API applies any new migrations on start. Take a backup first.

## Local test without a domain

For a quick look on your own machine without a public domain, skip Caddy and reach the web container directly. Publish its port and point a browser at `http://localhost`. The app works, but the camera scanner and the WebUSB printer stay disabled because the origin is not secure over a LAN IP. For anything past a first look, put it behind HTTPS.

## Kubernetes and Helm

The compose stack above is the supported path for the alpha. A Helm chart (backed by CloudNativePG for Postgres) is on the roadmap; until it lands, run the containers on Kubernetes with your own manifests using the same three images and the same environment variables shown here.
