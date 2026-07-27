#!/usr/bin/env bash
# Starts Postgres, the FireBin API, and nginx inside the one add-on container.
# Home Assistant gives the add-on a persistent /data directory, so the database,
# the uploaded files, and the generated session secret all live there and survive
# restarts and updates.
set -euo pipefail

DATA=/data
PGDATA="$DATA/pgdata"
ATTACH="$DATA/attachments"
# Alpine keeps the Postgres binaries out of the default PATH.
export PATH="/usr/libexec/postgresql16:/usr/lib/postgresql16/bin:$PATH"

log() { echo "[firebin] $*"; }

mkdir -p /run/nginx /run/postgresql "$ATTACH"
chown postgres:postgres /run/postgresql

# --- Database ---------------------------------------------------------------
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  log "Initialising the database (first run, this happens once)..."
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  su-exec postgres initdb --username=firebin --auth=trust --encoding=UTF8 -D "$PGDATA" >/dev/null
  {
    echo "listen_addresses = '127.0.0.1'"
    echo "unix_socket_directories = '/run/postgresql'"
  } >> "$PGDATA/postgresql.conf"
fi
chown -R postgres:postgres "$PGDATA"

log "Starting the database..."
su-exec postgres pg_ctl -D "$PGDATA" -w -t 60 start

# Create the firebin database on first run.
if ! su-exec postgres psql -h 127.0.0.1 -U firebin -d postgres -tAc \
      "SELECT 1 FROM pg_database WHERE datname='firebin'" | grep -q 1; then
  log "Creating the firebin database..."
  su-exec postgres createdb -h 127.0.0.1 -U firebin firebin
fi

# --- Session secret + options ----------------------------------------------
# Generate a stable session secret once and keep it, so restarts do not sign
# everyone out.
if [ ! -f "$DATA/jwt_secret" ]; then
  openssl rand -base64 48 | tr -d '\n' > "$DATA/jwt_secret"
fi

REGISTRATION=false
if [ -f "$DATA/options.json" ]; then
  REGISTRATION="$(jq -r '.registration_enabled // false' "$DATA/options.json")"
fi

export DATABASE_URL="postgres://firebin@127.0.0.1:5432/firebin?sslmode=disable"
export JWT_SECRET="$(cat "$DATA/jwt_secret")"
export REGISTRATION_ENABLED="$REGISTRATION"
export ATTACHMENT_STORAGE_PATH="$ATTACH"

# --- API --------------------------------------------------------------------
# The API runs its own database migrations on start.
log "Starting the API..."
/usr/bin/firebin-api &

# --- Web (foreground; keeps the container alive) ---------------------------
log "Starting the web interface on port 3000..."
exec nginx -g 'daemon off;'
