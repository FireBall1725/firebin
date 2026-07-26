# FireBin

FireBin is a self-hosted electronics parts inventory. It does what PartsBox, InvenTree, and Part-DB do, without the subscription or the cloud lock-in: you run it on your own box, your parts stay in your own Postgres, and adding a part is one barcode scan.

The idea it is built around: parts behave like books. A "1k resistor" is one thing you reach for, but underneath it live many real part numbers that differ by tolerance, package, and brand. FireBin tracks quantity, brand, package, location, and vendor pricing across all of them, and makes adding a part nearly free by reading the Data Matrix on a Digi-Key, Mouser, or LCSC bag so the part enriches itself.

FireBin is in alpha. Expect rough edges, and keep a backup.

This is the umbrella repo: deploy files, docs, and the project overview. The code lives in two sibling repos.

## The three repos

| Repo | What it is |
|---|---|
| [`firebin`](https://github.com/FireBall1725/firebin) | This repo. Docker Compose, self-host docs, roadmap. |
| [`firebin-api`](https://github.com/FireBall1725/firebin-api) | The Go 1.26 and Postgres 16 backend. REST on `/api/v1`, port 8080. |
| [`firebin-web`](https://github.com/FireBall1725/firebin-web) | The React 19 web client. |

Released images are published to `ghcr.io/fireball1725/firebin-api` and `ghcr.io/fireball1725/firebin-web`.

## Deploy it

The production stack is Postgres, the API, the web client, and Caddy for automatic HTTPS. Full instructions, the compose file, the `Caddyfile`, and the `.env` template are in [`deploy/`](deploy/). The short version:

```sh
cd deploy
cp .env.example .env      # set DOMAIN, JWT_SECRET, POSTGRES_PASSWORD
docker compose up -d
```

Open the domain, register the first account (it becomes the admin), and you're running. See [deploy/README.md](deploy/README.md) for HTTPS requirements, enrichment keys, backups, and updating.

## Run it for development

`local/docker-compose.yml` starts Postgres and the API together for local work:

```sh
cd local && docker compose up -d --build
```

Then run the web client from the `firebin-web` repo with `npm run dev`. It proxies `/api` to the API on port 8080.

## Docs

- [docs/enrichment-providers.md](docs/enrichment-providers.md): Digi-Key and Nexar setup.
- [docs/labels.md](docs/labels.md): label templates, sheets, and Brother tape printing.
- [docs/mcp-server.md](docs/mcp-server.md): the planned MCP server.
- [ROADMAP.md](ROADMAP.md): what is not in the alpha yet.

## Contributing

See [CLAUDE.md](CLAUDE.md). To change the backend or the client, open a pull request against `firebin-api` or `firebin-web`; this repo holds deploy files and docs.

## Licence

AGPL-3.0-only. See [LICENSE](LICENSE).
