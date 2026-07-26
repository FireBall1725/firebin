# Contributing to firebin

This guide is for anyone opening a pull request here, including people driving the change through Claude. Read it before you write code; it is short on purpose.

## What this repo is

The FireBin umbrella: Docker Compose, the self-host guide, and project docs. No application code. The backend is `firebin-api` and the client is `firebin-web`; a change to either belongs in that repo, not here.

## Layout

- `deploy/` is the production stack: `docker-compose.yml`, the `Caddyfile`, `.env.example`, and the self-host `README.md`.
- `local/` is the development stack: Postgres and the API for local work.
- `docs/` holds feature docs (enrichment, labels, the planned MCP server).
- `ROADMAP.md` lists what is not in the alpha yet.

## Conventions that matter

- If you add or rename a variable in `deploy/docker-compose.yml`, add the matching key to `deploy/.env.example`. CI fails when a compose variable has no template key, because a deployer copying the template would hit an unset-variable error.
- Never commit a real `.env`. Only `.env.example`, with blank secrets, is tracked.
- Keep the two image names (`ghcr.io/fireball1725/firebin-api` and `firebin-web`) and the `firebin-api` service name in step with what the web container's nginx proxies to. The web container points at `http://firebin-api:8080`, so renaming the service breaks the proxy.
- Docs are prose. Say the port, the command, the version. Skip the filler.

## Before you open a pull request

Validate the compose files the way CI does:

```sh
cd deploy && DOMAIN=x JWT_SECRET=x POSTGRES_PASSWORD=x docker compose config --quiet
cd ../local && docker compose config --quiet
```

Keep commits small and focused, and write a message that says what changed and why. Do not add `Co-Authored-By` or "Generated with" trailers; the commit is authored by the person who sent it.
