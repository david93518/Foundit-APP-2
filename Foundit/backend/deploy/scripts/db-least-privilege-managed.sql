-- 建立／更新 API 執行用的最小權限資料庫帳號。
--
-- For managed PostgreSQL: run as the schema owner with CREATEROLE.
-- Supply psql variables app_user and app_pass through a private input file.
-- Existing privileged roles are rejected; no superuser attributes are altered.
-- Reapply after adding business tables to the explicit grants below.

\set ON_ERROR_STOP on
BEGIN;

-- Never reuse a schema owner or a role with inherited memberships as the API credential.
SELECT 1 / CASE WHEN :'app_user' = current_user OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) OR EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner
  WHERE c.relnamespace = 'public'::regnamespace AND r.rolname = :'app_user') OR EXISTS (
  SELECT 1 FROM pg_database d JOIN pg_roles r ON r.oid = d.datdba
  WHERE d.datname = current_database() AND r.rolname = :'app_user') OR EXISTS (
  SELECT 1 FROM pg_namespace n JOIN pg_roles r ON r.oid = n.nspowner
  WHERE n.nspname = 'public' AND r.rolname = :'app_user') OR EXISTS (
  SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member WHERE r.rolname = :'app_user')
  THEN 0 ELSE 1 END AS validate_non_owner_role;

SELECT format(
  'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 50',
  :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user') \gexec

SELECT format(
  'ALTER ROLE %I WITH LOGIN PASSWORD %L',
  :'app_user', :'app_pass') \gexec

-- 查詢跑太久或交易卡住時自動中止，單一請求拖不垮整個資料庫。
SELECT format('ALTER ROLE %I SET statement_timeout = %L', :'app_user', '15s') \gexec
SELECT format('ALTER ROLE %I SET idle_in_transaction_session_timeout = %L', :'app_user', '60s') \gexec

-- 資料庫：只有擁有者與 app 帳號能連線；public schema 不讓任何人隨意建物件。
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM %I', current_database(), :'app_user') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'app_user') \gexec
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SELECT format('REVOKE ALL ON SCHEMA public FROM %I', :'app_user') \gexec
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'app_user') \gexec

-- 業務資料表：可查詢、新增、修改。
SELECT format('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I', :'app_user') \gexec
SELECT format('GRANT SELECT, INSERT, UPDATE ON TABLE public.%I TO %I', tablename, :'app_user')
FROM pg_tables WHERE schemaname = 'public' AND tablename IN (
  'users', 'items', 'chats', 'chat_participants', 'messages', 'notifications', 'qr_items',
  'user_points', 'point_events', 'reports', 'user_blocks', 'admin_actions',
  'chat_rate_limits', 'upload_cleanup_jobs', 'saved_items', 'hidden_chats', 'point_awards') \gexec
-- 僅解除封鎖與完成的檔案清理工作需要 DELETE。
SELECT format('GRANT DELETE ON TABLE public.user_blocks TO %I', :'app_user') \gexec
SELECT format('GRANT DELETE ON TABLE public.upload_cleanup_jobs TO %I', :'app_user') \gexec
SELECT format('GRANT DELETE ON TABLE public.%I TO %I', tablename, :'app_user') FROM pg_tables WHERE schemaname='public' AND tablename IN ('saved_items','hidden_chats') \gexec
-- 稽核紀錄只能追加，執行中的 API 無法竄改或刪除既有紀錄。
SELECT format('REVOKE UPDATE, DELETE ON TABLE public.admin_actions FROM %I', :'app_user') \gexec
SELECT format('REVOKE UPDATE, DELETE ON TABLE public.%I FROM %I', tablename, :'app_user') FROM pg_tables WHERE schemaname='public' AND tablename='point_awards' \gexec
-- migration 紀錄與 API 無關。
SELECT format('REVOKE ALL ON TABLE public.%I FROM %I', tablename, :'app_user')
FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('migrations', 'typeorm_metadata') \gexec
-- Business keys are UUIDs; the migration bookkeeping sequence is not an API capability.
SELECT format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', :'app_user') \gexec

-- New tables are inaccessible until deliberately granted; an unrelated future secrets table stays private.
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM %I', :'app_user') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', :'app_user') \gexec

CREATE OR REPLACE FUNCTION public.foundit_guard_user_security() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $guard$
BEGIN
  IF current_user <> TG_ARGV[0] THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.role <> 'user' OR NEW.token_version <> 0 OR NEW.status <> 'active' THEN
      RAISE EXCEPTION 'API cannot provision privileged accounts' USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'API cannot change account roles' USING ERRCODE = '42501';
    END IF;
    IF NEW.token_version < OLD.token_version OR
       (OLD.status = 'deleted' AND NEW.status <> 'deleted') OR
       (OLD.role = 'admin' AND NEW.status = 'suspended') THEN
      RAISE EXCEPTION 'Invalid account security transition' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END
$guard$;
REVOKE ALL ON FUNCTION public.foundit_guard_user_security() FROM PUBLIC;
DROP TRIGGER IF EXISTS foundit_user_security ON public.users;
SELECT format('CREATE TRIGGER foundit_user_security BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.foundit_guard_user_security(%L)', :'app_user') \gexec
COMMIT;
