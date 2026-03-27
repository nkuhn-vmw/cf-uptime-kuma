#!/bin/bash
# start.sh - CF entrypoint for Uptime Kuma
# Parses MariaDB credentials from VCAP_SERVICES and launches the server.

set -euo pipefail

# Detect the service key in VCAP_SERVICES.
# CF marketplace labels vary by provider: "mysql", "p-mysql", "p.mysql", etc.
# Also supports user-provided services via "user-provided" key.
SERVICE_KEY=$(echo "$VCAP_SERVICES" | jq -r '
  if has("mysql") then "mysql"
  elif has("p-mysql") then "p-mysql"
  elif has("p.mysql") then "p.mysql"
  elif has("mariadb") then "mariadb"
  elif has("user-provided") then "user-provided"
  else empty
  end
')

if [ -z "$SERVICE_KEY" ]; then
  echo "ERROR: No MySQL/MariaDB service found in VCAP_SERVICES."
  echo "Bind a mysql or mariadb service, or create a user-provided service."
  exit 1
fi

echo "Using service key: $SERVICE_KEY"

# Extract credentials
export UPTIME_KUMA_DB_TYPE=mariadb
export UPTIME_KUMA_DB_HOSTNAME=$(echo "$VCAP_SERVICES" | jq -r ".\"${SERVICE_KEY}\"[0].credentials.hostname")
export UPTIME_KUMA_DB_PORT=$(echo "$VCAP_SERVICES" | jq -r ".\"${SERVICE_KEY}\"[0].credentials.port")
export UPTIME_KUMA_DB_USERNAME=$(echo "$VCAP_SERVICES" | jq -r ".\"${SERVICE_KEY}\"[0].credentials.username")
export UPTIME_KUMA_DB_PASSWORD=$(echo "$VCAP_SERVICES" | jq -r ".\"${SERVICE_KEY}\"[0].credentials.password")
export UPTIME_KUMA_DB_NAME=$(echo "$VCAP_SERVICES" | jq -r ".\"${SERVICE_KEY}\"[0].credentials.name")

# CF assigns the listen port dynamically
export UPTIME_KUMA_PORT=$PORT

# Disable WebSocket origin check — GoRouter/Cloudflare rewrite the Origin header
export UPTIME_KUMA_WS_ORIGIN_CHECK=bypass

echo "Starting Uptime Kuma (DB: $UPTIME_KUMA_DB_HOSTNAME:$UPTIME_KUMA_DB_PORT/$UPTIME_KUMA_DB_NAME)"
exec node server/server.js
