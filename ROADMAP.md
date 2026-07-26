# FireBin roadmap

Tracked items that are not in the alpha but are planned. This list is about operational and self-host gaps; the product roadmap (assemblies, native apps, MCP) lives in the plan.

## Automated database backups

Today a deployer owns their Postgres backup. The self-host guide shows a `pg_dump` one-liner, and the app has a JSON export under Settings, Data, but nothing runs on a schedule. Planned: an opt-in scheduled dump driven by the River job processor, writing to a configured path or object store, with retention. It would sit next to the existing job workers rather than a separate cron container, so a single deployment keeps its own backups. The JSON export stays as the portable, cross-version snapshot; the scheduled dump is the disaster-recovery layer.

## First-run admin flow

The first account to register bootstraps as admin and registration then closes, which works but gives no signal that it happened. Planned: a first-run screen that names the account as the instance admin, points at the export and enrichment settings, and offers to import an existing backup before any data is entered. It lands after the export and import feature, which is done, so a fresh install can restore straight from the welcome screen.

## Shipped from this list

- **Empty stock lot cleanup** (opt-in, default off). A lot that drops to zero is kept so its history survives and you can reorder into it. Settings, Data has a toggle to allow purging empty lots and a one-off purge button. Lots with a barcode or a name are a cut spool or a tracked unit, so they are always kept. Endpoints: `GET`/`PUT /settings/stock` and `POST /stock/cleanup-empty` (admin).
