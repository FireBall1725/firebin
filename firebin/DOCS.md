# FireBin

Self-hosted electronics parts inventory. Scan a distributor bag and the part enriches itself: quantity, package, brand, location, and vendor pricing.

## What this add-on does

Home Assistant add-ons run as a single container, so this one bundles all of FireBin together: a Postgres database, the FireBin API, and the web app. You install one thing and open it in a browser; the add-on keeps everything running.

## Getting started

1. Install and Start the add-on.
2. Open the Web UI (or your Home Assistant address on port 3000).
3. Register the first account. It becomes the admin, and registration then closes.
4. To pull datasheets and pricing when you scan a bag, add a Digi-Key API app under Settings, Enrichment.

## Options

- `registration_enabled`: off by default. Turn it on to let more people sign up; otherwise the admin adds users under Settings.

## Data and backups

The database, uploaded files, and the session secret are stored in the add-on's persistent storage, so they are included in Home Assistant backups. You can also export a full JSON backup from inside FireBin under Settings, Data.

## Limitations

- Runs on amd64 (Intel and AMD) and aarch64 (ARM).
- The camera scanner and Brother tape printing need a secure origin (HTTPS or localhost), so over your network they stay disabled unless you put Home Assistant behind HTTPS.

FireBin is in alpha. Expect rough edges, and keep a backup.
