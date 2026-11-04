import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 網站的第二種登入方式：Email＋密碼。和 Google 帳號完全分開：
 * - 帳號鍵是 users.phone = `e:<email 的 sha256>`（Google 帳號是 `g:<sub>`），同一個 email 可以各有一個帳號，互不相通；
 * - verified_email 留空，所以 campus_auth.users 視為未驗證：拿不到工作人員或管理員資格，也不會依 email 寄信；
 * - 密碼只存 scrypt 雜湊（password_hash）。
 */
export class EmailPasswordLogin1793059206000 implements MigrationInterface {
  name = 'EmailPasswordLogin1793059206000';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash varchar(200)`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE users DROP COLUMN IF EXISTS password_hash`);
  }
}
