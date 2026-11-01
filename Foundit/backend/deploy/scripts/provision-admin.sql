-- Run as the migration owner: psql -v user_id=<existing verified account UUID> -f provision-admin.sql.
-- The API cannot run this operation; choose the account by a verified identity, never profile email alone.
\set ON_ERROR_STOP on
BEGIN;
UPDATE public.users SET role = 'admin', token_version = token_version + 1
WHERE id = :'user_id'::uuid AND status = 'active' AND is_verified = true;
INSERT INTO public.admin_actions(actor_id, action, target_type, target_id, reason, result)
SELECT id, 'role.provision', 'user', id::text, 'Provisioned by database operator', 'admin'
FROM public.users WHERE id = :'user_id'::uuid AND role = 'admin' AND status = 'active';
COMMIT;
