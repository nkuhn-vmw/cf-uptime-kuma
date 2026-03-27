# Uptime Kuma on Cloud Foundry

Deploy [Uptime Kuma](https://github.com/louislam/uptime-kuma) v2.x on Cloud Foundry using the Node.js buildpack and a CF marketplace MariaDB/MySQL service.

## Prerequisites

- CF CLI v8+ authenticated and targeting your org/space
- A MySQL or MariaDB service in your CF marketplace (run `cf marketplace` and look for `mysql`, `p.mysql`, `p-mysql`, or `mariadb`)
- Node.js >= 20.4 and npm installed locally (for the build step)

## Deployment

### 1. Clone Uptime Kuma at a release tag

```bash
git clone --branch 2.2.1 --depth 1 https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
```

> Replace `2.2.1` with the latest [v2.x release tag](https://github.com/louislam/uptime-kuma/releases).

### 2. Install dependencies and build the frontend

```bash
npm ci --omit dev
npm run download-dist
```

This installs production dependencies and downloads the pre-built Vue.js frontend.

### 3. Add the CF deployment files

Clone this repo and copy the artifacts into the Uptime Kuma directory:

```bash
git clone https://github.com/nkuhn-vmw/cf-uptime-kuma.git /tmp/cf-uptime-kuma
cp /tmp/cf-uptime-kuma/start.sh .
cp /tmp/cf-uptime-kuma/manifest.yml .
cp /tmp/cf-uptime-kuma/.cfignore .
```

### 4. Edit the manifest

Open `manifest.yml` and update the **route** to match your CF domain:

```yaml
  routes:
  - route: uptime-kuma.<YOUR-APPS-DOMAIN>
```

Find your apps domain with `cf domains`.

### 5. Create the database service

Check your marketplace for the correct service name and plan:

```bash
cf marketplace | grep -i mysql
```

Then create the service instance. The service instance **must** be named `uptime-kuma-db` (to match the manifest):

```bash
# Examples — adjust the service name and plan for your foundation:
cf create-service p.mysql db-small uptime-kuma-db      # VMware Tanzu MySQL
cf create-service mysql small uptime-kuma-db            # Other MySQL providers
```

**Alternative: External database via User-Provided Service**

If your marketplace doesn't offer MySQL, or you want to use an existing MariaDB/MySQL instance:

```bash
cf create-user-provided-service uptime-kuma-db -p '{
  "hostname": "your-db-host.example.com",
  "port": "3306",
  "username": "uptime_kuma",
  "password": "YOUR_PASSWORD",
  "name": "uptime_kuma"
}'
```

### 6. Push

```bash
cf push
```

The first push triggers database schema migration. This can take up to 60 seconds. Watch the logs to confirm:

```bash
cf logs uptime-kuma --recent
```

You should see `Created basic tables for MariaDB` and `Container became healthy`.

### 7. First login

Open the route URL in your browser and create your admin account. **Enable 2FA immediately** in Settings > Security.

## Upgrading

1. Read the upstream [changelog](https://github.com/louislam/uptime-kuma/releases) for breaking changes.
2. Back up the database (use your marketplace's backup tooling, or `mysqldump` via `cf ssh`).
3. Clone the new release tag, rebuild (`npm ci --omit dev && npm run download-dist`), copy in the CF files, and `cf push`. Migrations run automatically on startup.
4. Monitor `cf logs uptime-kuma` during first boot for migration status.

## Key Constraints

- **Single instance only.** `instances: 1` is mandatory. Uptime Kuma uses in-memory state and a single Socket.IO event loop. Do not scale horizontally.
- **WebSocket required.** CF GoRouter handles WebSocket upgrades natively — no extra configuration needed. If you have an upstream proxy (Cloudflare, HAProxy, etc.), ensure it forwards `Upgrade` and `Connection` headers.
- **Ephemeral filesystem.** Uploaded status page icons are lost on restage. Use external image URLs instead of file uploads.

## How `start.sh` Works

The `start.sh` script is the app entrypoint. It:

1. Auto-detects the MySQL/MariaDB service key in `VCAP_SERVICES` (supports `mysql`, `p-mysql`, `p.mysql`, `mariadb`, and `user-provided`)
2. Extracts hostname, port, username, password, and database name from the bound credentials
3. Exports them as `UPTIME_KUMA_DB_*` environment variables that Uptime Kuma expects
4. Sets `UPTIME_KUMA_PORT` to the CF-assigned `$PORT`
5. Disables the WebSocket origin check (required behind GoRouter)
6. Launches the Node.js server

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Crash on start with "No MySQL/MariaDB service found" | Service not bound, or marketplace uses an unusual label | Run `cf env uptime-kuma` and check the VCAP_SERVICES key. If it's not one of the auto-detected labels, use a User-Provided Service instead. |
| Dashboard loads but shows "WebSocket connection failed" | Origin header mismatch | Verify `UPTIME_KUMA_WS_ORIGIN_CHECK=bypass` is set in the manifest env |
| 502 errors on the dashboard | Upstream proxy not forwarding WebSocket upgrade | Check your load balancer / tunnel configuration for WebSocket support |
| Status page icons missing after restage | Uploaded images stored on ephemeral disk | Use external image URLs instead of uploading files |
| App slow to start on first push | Database migration running | Normal — wait up to 60s. Check `cf logs` for progress. |

## Files

| File | Purpose |
|------|---------|
| `start.sh` | CF entrypoint — parses VCAP_SERVICES, exports DB env vars, launches server |
| `manifest.yml` | CF app manifest — single instance, Node.js buildpack, MariaDB service binding |
| `.cfignore` | Excludes `.git/`, test files, and Docker artifacts from the push upload |
