import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 管理員只有一份名單：App 的管理員（users.role = 'admin'，來自 ADMIN_EMAILS／ADMIN_PHONES）在網站後台也是管理員，
 * 不必再另外加進「工作人員」。反過來（工作人員裡的管理員能用 API 的 /admin/*）由 AdminGuard 處理。
 * 停權的帳號不算。
 */
export class AppAdminsAreStaff1793059205000 implements MigrationInterface {
  name = 'AppAdminsAreStaff1793059205000';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`CREATE OR REPLACE FUNCTION campus.staff_role() RETURNS text
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
        SELECT CASE
          WHEN EXISTS (SELECT 1 FROM public.users p WHERE p.id = campus_auth.uid() AND p.role = 'admin' AND p.status = 'active') THEN 'admin'
          ELSE (
            SELECT s.role
            FROM campus.staff s
            JOIN campus_auth.users u ON lower(u.email) = s.email
            WHERE u.id = campus_auth.uid()
              AND u.email_confirmed_at IS NOT NULL
            LIMIT 1
          )
        END
      $$`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`CREATE OR REPLACE FUNCTION campus.staff_role() RETURNS text
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
        SELECT s.role
        FROM campus.staff s
        JOIN campus_auth.users u ON lower(u.email) = s.email
        WHERE u.id = campus_auth.uid()
          AND u.email_confirmed_at IS NOT NULL
        LIMIT 1
      $$`);
  }
}
