# FireBin add-on

Run [FireBin](https://github.com/FireBall1725/firebin), a self-hosted electronics parts inventory, as a Home Assistant add-on. The add-on bundles the database, the API, and the web app in one container, so there is nothing to set up beyond installing it.

## Install

1. In Home Assistant, go to Settings, Add-ons, Add-on Store.
2. Open the menu (top right), Repositories, and add `https://github.com/FireBall1725/firebin`.
3. Install the FireBin add-on, then Start it. Turn on Start on boot and Watchdog.
4. Open the Web UI, or browse to your Home Assistant address on port 3000. The first account you register becomes the admin.

## Notes

- The database and uploaded files live in the add-on's own storage, so they are part of your Home Assistant backups.
- The session secret is generated once on first start and kept, so restarts do not sign you out.
- Runs on amd64 (Intel and AMD) and aarch64 (ARM).

FireBin is in alpha. Keep a backup (Settings, Data inside FireBin).
