import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 空資料庫先依實體建立 schema；既有資料庫只補欄位與新表。
 * 正式環境維持 synchronize=false，並用 npm run migration:run 執行。
 */
export class SecurityGovernance1735689600000 implements MigrationInterface {
  name = 'SecurityGovernance1735689600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    if (!(await queryRunner.hasTable('users'))) {
      await queryRunner.connection.synchronize();
    }

    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "token_version" integer NOT NULL DEFAULT 0`);
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "role" character varying(20) NOT NULL DEFAULT 'user'`);
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "status" character varying(20) NOT NULL DEFAULT 'active'`);
    await queryRunner.query(`ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "terms_version" character varying(32) NOT NULL DEFAULT ''`);
    await queryRunner.query(`ALTER TABLE "items" ADD COLUMN IF NOT EXISTS "hidden_at" TIMESTAMP WITH TIME ZONE`);
    await queryRunner.query(`ALTER TABLE "chats" ADD COLUMN IF NOT EXISTS "requester_id" uuid`);
    await queryRunner.query(`ALTER TABLE "messages" ADD COLUMN IF NOT EXISTS "client_message_id" character varying(64)`);
    await queryRunner.query(`ALTER TABLE "qr_items" ADD COLUMN IF NOT EXISTS "code" character varying(80)`);
    await queryRunner.query(`ALTER TABLE "qr_items" ADD COLUMN IF NOT EXISTS "revoked_at" TIMESTAMP WITH TIME ZONE`);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "uniq_chat_item_requester" ON "chats" ("item_id", "requester_id")`);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "uniq_msg_client" ON "messages" ("chat_id", "sender_id", "client_message_id")`);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "uniq_qr_code" ON "qr_items" ("code")`);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "reports" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "reporter_id" uuid NOT NULL,
        "target_type" character varying(32) NOT NULL,
        "target_id" character varying(64) NOT NULL,
        "reason" text NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'open',
        "resolution" text NOT NULL DEFAULT '',
        "handled_by" uuid,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "user_blocks" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "blocker_id" uuid NOT NULL,
        "blocked_id" uuid NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "uniq_user_block" ON "user_blocks" ("blocker_id", "blocked_id")`);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "admin_actions" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "actor_id" uuid NOT NULL,
        "action" character varying(64) NOT NULL,
        "target_type" character varying(32) NOT NULL,
        "target_id" character varying(64) NOT NULL,
        "reason" text NOT NULL DEFAULT '',
        "result" character varying(32) NOT NULL DEFAULT '',
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "admin_actions"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "user_blocks"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "reports"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "token_version"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "role"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "status"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "terms_version"`);
    await queryRunner.query(`ALTER TABLE "items" DROP COLUMN IF EXISTS "hidden_at"`);
    await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "requester_id"`);
    await queryRunner.query(`ALTER TABLE "messages" DROP COLUMN IF EXISTS "client_message_id"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP COLUMN IF EXISTS "code"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP COLUMN IF EXISTS "revoked_at"`);
  }
}
