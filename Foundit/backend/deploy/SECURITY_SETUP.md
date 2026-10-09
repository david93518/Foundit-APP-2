# Runtime database and private media setup

Apply this setup before starting the new API. Back up the database and uploads volume first.

1. Keep the database owner in `DB_MIGRATION_USER` / `DB_MIGRATION_PASS`. Use a separate non-owner role in `DB_USER` / `DB_PASS`.
2. Run migrations with the migration credential, then run `scripts/db-least-privilege.sql` as the owner with `app_user` and `app_pass` psql variables. The script is transactional and can be rerun. Production startup checks require its protection trigger and reject owner/superuser runtime credentials, schema/database creation and temporary-table privileges. Business UUID keys need no sequence grants; migration sequences stay inaccessible. New business tables require an explicit whitelist update and grant.
3. Administrator roles are provisioned by an operator using `scripts/provision-admin.sql` and an existing verified account UUID. Verify the identity independently; profile email alone is not identity proof. `ADMIN_EMAILS` / `ADMIN_PHONES` can restrict administrator login but never grant a role. To revoke existing sessions immediately, change the DB role and increment `token_version`.
4. Set `TRUSTED_PROXY_ADDRESSES` to the exact TCP addresses of your trusted proxy, including the actual Docker gateway when applicable. Inspect the network on the deployment host; do not grant trust to entire LAN/private subnets. Keep the API listener bound to loopback when the tunnel runs on the same host.
5. The container entrypoint migrates existing chat images before serving traffic. It copies them into the non-public `uploads/.private` directory, updates message references, and removes chat-only public originals. Images also used by a public listing or avatar stay public. Files already downloaded by a device cannot be withdrawn.
6. Purge the old URLs in `uploads/.private/legacy-cache-purge.json` from your CDN before reopening access after the migration. Origin deletion alone does not clear already cached copies. This file stays in the protected uploads volume; do not publish it.

New chat uploads use `POST /api/v1/upload/image?scope=chat`. Their URLs require a bearer token and a sender/participant check; clients must fetch with the authenticated API client. Public listing/avatar uploads keep the existing endpoint with `scope=public` (default). Ship the updated mobile client with the API update so private image rendering and QR ownership checks use the new response contract.

Account deletion commits redaction and a file cleanup job together. The API retries file cleanup at startup and once per minute; failures retain the job. Monitor cleanup warnings and verify the queue drains. Deployments must not reset or discard that table.
