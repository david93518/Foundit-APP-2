# Web / App interoperability

The campus Web app uses the existing NestJS / Render PostgreSQL / R2 services. No Supabase export or deletion is part of this deployment. All existing mobile users, items, chats and media remain in place.

Deploy this API before deploying `Timothychen00/foundit-webapp` to the Cloudflare `foundit-platform` Worker. The brand homepage is a separate Worker. Add `https://app.foundit.tw` to `CORS_ORIGINS` and to the Google Web OAuth client's authorized JavaScript origins. Never put backend credentials into the Web repository.

The two additive migrations add shared bookmarks, hidden conversations, idempotent points, campus scope and the isolated campus administration / sticker schema. Existing posts receive `campus_code=ncku` only if their coordinates fall within the versioned NCKU polygons. New mobile posts are classified from coordinates; the Web explicitly requests campus scope. Editing a located Web post outside that boundary is rejected. Personal collections and direct item links can include other areas.

Web login verifies the same Google subject as the mobile login. A dedicated browser OAuth client can be configured with `GOOGLE_BROWSER_CLIENT_ID`; keep `GOOGLE_WEB_CLIENT_ID` unchanged for installed mobile Apps. Browser login falls back to that existing client only when the separate browser setting is absent. Audience checks remain mandatory for both routes; accounts are matched by verified Google subject, never by a client-supplied email. The browser keeps its bearer token in memory and bootstraps it using a Secure / HttpOnly cookie. Cookie endpoints enforce an exact Origin allowlist. Business endpoints still require a bearer token. User-edited email addresses cannot become campus staff identities; staff lookup uses the separately verified Google email. Existing core administrators can configure the fresh campus staff list.

Campus tables and functions have no PUBLIC access. Runtime schema grants are explicit, station/staff writes use RLS, private sticker threads require ownership or an unguessable finder credential, and photos require staff authentication. The campus RPC controller exposes a fixed parameterized allowlist. Email outbox sending is not configured; in-site sticker notifications work without email.

## Validation

- `npm run build`
- `npm test -- --runInBand`
- Set `PGLITE_MODULE` to the installed `@electric-sql/pglite/dist/index.js`, then run `node test/web-interop-db.cjs` to execute both real migrations and permission / preservation / points checks in disposable PostgreSQL.
- Web: `npm run check` in the separate Web repository.
- Flutter: `flutter test --no-pub test/bookmark_sync_test.dart test/experience_test.dart test/regression_test.dart`.

Live checks must verify CORS with credentials, the browser session endpoint, the NCKU list, existing mobile endpoints, private image protection and campus anonymous/admin boundaries. Test posting/chatting must use isolated test accounts, not real recipients.

Existing TestFlight 1.0.0 (9) works with the additive APIs. Its bookmarks are local; the updated Flutter code merges a user's old phone bookmarks once and then treats the shared API as authoritative. This feature needs a new signed App build. Updating the API or Web does not update an installed App.

## Rollback

Roll back the Render program commit and the Cloudflare Worker version if necessary. Keep the additive migrations in place. Do not run migration down or restore the entire database after new user writes, because that would erase new records. Campus data starts fresh independently of the preserved mobile tables.
