# Cloud deployment

Deployed 2026-10-27 (Asia/Taipei).

- Brand: https://foundit.tw and https://www.foundit.tw — Cloudflare Worker `foundit-brand`.
- Web platform: https://app.foundit.tw — Cloudflare Worker `foundit-platform`. Existing demo/localStorage behavior is unchanged; member API integration is separate work.
- API: https://api.foundit.tw — Cloudflare Worker `foundit-api-proxy`, forwarding to Render `https://foundit-api-0p3h.onrender.com`.
- Render API: `srv-dbg9rbe7bikc73fg3psg`, Singapore, one `1c-2g` instance. Docker root `Foundit/backend`; health check `/api/v1/health`; automatic deployment disabled.
- Render PostgreSQL 16: `dpg-dbg9lk4ipgvc73euk7p0-a`, Singapore, `0.5c-1g`, 1 GB, no HA/autoscaling. External IP allowlist is empty; API uses internal network.
- Private R2 bucket: `foundit-media`. Public photos use `public/`; authenticated chat photos use `chat/`. The API enforces chat authorization before reading objects.

## Credentials

Render environment contains the runtime and migration DB credentials, original JWT secret, R2 object credentials and origin proxy secret. The Worker contains the same origin proxy secret as a secret binding. Never put these in Git or frontend bundles.

Operator configuration and migration backups are stored in the ACL-restricted local directory `C:\Users\david\.codex\private\foundit-deployment`. R2 credentials are in `r2.env`, scoped to object read/write on `foundit-media` only. Source-host backups are under `/home/david/foundit-private/cloud-migration-20261027`.

## Updates

1. Build/test the backend, commit and push a reviewed revision of `codex/cloudflare-render-deploy`.
2. Deploy the exact commit using `render deploys create srv-dbg9rbe7bikc73fg3psg --commit <SHA> --confirm`.
3. Confirm Render reports `live`; verify health, authenticated API access, image reads and WebSocket connectivity through `api.foundit.tw`.
4. Deploy Worker changes with `wrangler deploy --config deploy/cloudflare/wrangler.jsonc`. Keep the secret binding; never place its value in the config.
5. For schema changes, update the explicit table grants in `deploy/scripts/db-least-privilege-managed.sql` and reapply as database owner. The runtime role cannot perform migrations.

Web deployment config is in `Timothychen00/foundit-site`, branch `codex/cloudflare-hosting`: `npm run deploy` for the brand and `npm run deploy:platform` for the platform. DNS records remain proxied; exact Worker routes intercept requests before their former origins. Preserve those routes and proxied records.

## Migration verification

The old API was stopped before the final database dump. Every public table matched by row count and deterministic row-content hash after restoration; key counts were 8 users, 9 items and 20 messages. Seven media files were uploaded and downloaded for byte comparison. Public API health, authenticated listing reads, unauthenticated rejection, direct-origin rejection and Engine.IO WebSocket upgrade passed through the production hostname. Backend tests: 27 suites / 139 tests. Web checks: 14 brand + 31 platform tests.

The old API container remains stopped. Its database and backups remain available. **Do not restart the old API as a rollback without reconciling writes made on Render since cutover.** Prefer reverting a Render code revision while retaining the current database and R2 storage. For a full infrastructure rollback, stop writes, back up the current Render database and R2 changes, restore them to the rollback target, verify consistency, then change the Cloudflare route.

## Remaining product work

Web member features still need API integration. Mobile store submission is not part of hosting deployment. FCM configuration was absent in the source environment, so production push notifications remain unconfigured. This deployment has one API instance and no database HA; do not describe it as highly available or assign a user-capacity figure without a representative load test.
