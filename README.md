# Uptime Kuma on Cloud Foundry

Deploy [Uptime Kuma](https://github.com/louislam/uptime-kuma) v2.x on Cloud Foundry using the Node.js buildpack and a CF marketplace MariaDB/MySQL service.

## Prerequisites

- CF CLI authenticated and targeting your org/space
- A CF marketplace offering MySQL or MariaDB (run `cf marketplace -e mysql` to check)
- Node.js >= 20.4 and npm installed locally (for the build step)
- `jq` available in the CF buildpack runtime (included in the default Node.js buildpack)

## Deployment

### 1. Clone Uptime Kuma

```bash
git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
git checkout 2.x.x   # pin to your desired v2.x release tag
```

### 2. Build the frontend

```bash
npm run setup
```

This installs dependencies and builds the Vue.js frontend into `dist/`.

### 3. Copy CF artifacts into the repo

```bash
cp /path/to/cf-uptime-kuma/start.sh .
cp /path/to/cf-uptime-kuma/manifest.yml .
```

### 4. Create the database service

**Option A: CF Marketplace**

```bash
cf create-service mysql small uptime-kuma-db
```

**Option B: User-Provided Service (external/homelab DB)**

```bash
cf create-user-provided-service uptime-kuma-db -p '{
  "hostname": "mariadb.example.com",
  "port": "3306",
  "username": "uptime_kuma",
  "password": "YOUR_PASSWORD",
  "name": "uptime_kuma"
}'
```

### 5. Push

```bash
cf push
```

The first push triggers database schema migration — watch the logs:

```bash
cf logs uptime-kuma --recent
```

### 6. First login

Open the app URL and create your admin account. Enable 2FA immediately.

## Upgrading

1. Read the upstream [changelog](https://github.com/louislam/uptime-kuma/releases) for breaking changes.
2. Back up the database (`cf ssh uptime-kuma -c "mysqldump ..."` or use your marketplace's backup tooling).
3. Pull the new version, rebuild (`npm run setup`), and `cf push`. Migrations run automatically on startup.
4. Monitor `cf logs uptime-kuma` during first boot after upgrade.

## Key Constraints

- **Single instance only.** `instances: 1` is mandatory. Uptime Kuma uses in-memory state and a single Socket.IO event loop.
- **WebSocket required.** CF GoRouter handles this natively. If using Cloudflare Tunnel, ensure WebSocket support is enabled on the ingress rule.
- **Ephemeral filesystem.** Uploaded status page icons are lost on restage. Use external image URLs instead.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| DB error on start | VCAP_SERVICES key mismatch | Run `cf env uptime-kuma` and check the service label (`mysql`, `p-mysql`, `p.mysql`, etc.) — `start.sh` auto-detects common labels |
| WebSocket fails | Origin check rejecting connection | Verify `UPTIME_KUMA_WS_ORIGIN_CHECK=bypass` is set |
| 502 on WS upgrade | Upstream proxy not forwarding Upgrade header | Check Cloudflare Tunnel / LB config |
| Icons missing after restage | Ephemeral disk | Use external image URLs |

## Files

| File | Purpose |
|------|---------|
| `start.sh` | CF entrypoint — parses VCAP_SERVICES, exports DB env vars, launches server |
| `manifest.yml` | CF app manifest — single instance, Node.js buildpack, MariaDB service binding |
