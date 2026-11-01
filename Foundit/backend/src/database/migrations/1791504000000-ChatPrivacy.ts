import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatPrivacy1791504000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE IF NOT EXISTS chat_rate_limits (
      user_id uuid PRIMARY KEY, window_start timestamptz NOT NULL,
      count integer NOT NULL CHECK (count > 0))`);
    await runner.query(`CREATE TABLE IF NOT EXISTS upload_cleanup_jobs (
      user_id uuid PRIMARY KEY, files text[] NOT NULL DEFAULT '{}',
      created_at timestamptz NOT NULL DEFAULT now())`);
    const appRole = process.env.DB_USER;
    if (appRole) {
      const roles = await runner.query('SELECT 1 FROM pg_roles WHERE rolname = $1', [appRole]);
      if (roles.length) {
        const quoted = `"${appRole.replace(/"/g, '""')}"`;
        await runner.query(`GRANT SELECT, INSERT, UPDATE ON chat_rate_limits, upload_cleanup_jobs TO ${quoted}`);
        await runner.query(`GRANT DELETE ON upload_cleanup_jobs TO ${quoted}`);
      }
    }
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('DROP TABLE upload_cleanup_jobs');
    await runner.query('DROP TABLE chat_rate_limits');
  }
}
