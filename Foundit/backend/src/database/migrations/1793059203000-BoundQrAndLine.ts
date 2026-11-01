import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 貼紙改成「先綁定才能用」：
 * - qr_items 可以沒有物主（尚未綁定），綁定時間與物主同進同出。
 * - 管理員成批印製貼紙（qr_batches），也能停用單張。
 * - LINE 官方帳號給撿到的人一次性連結（line_links），留言紀錄（qr_finder_notices）用來限制頻率。
 * 既有貼紙都是物主自己產生的，視為已綁定。
 */
export class BoundQrAndLine1793059203000 implements MigrationInterface {
  name = 'BoundQrAndLine1793059203000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "qr_items" ALTER COLUMN "user_id" DROP NOT NULL`);
    await queryRunner.query(`ALTER TABLE "qr_items" ALTER COLUMN "name" SET DEFAULT ''`);
    await queryRunner.query(`ALTER TABLE "qr_items" ADD COLUMN IF NOT EXISTS "batch_id" uuid`);
    await queryRunner.query(`ALTER TABLE "qr_items" ADD COLUMN IF NOT EXISTS "bound_at" TIMESTAMP WITH TIME ZONE`);
    await queryRunner.query(`ALTER TABLE "qr_items" ADD COLUMN IF NOT EXISTS "disabled_at" TIMESTAMP WITH TIME ZONE`);
    await queryRunner.query(`UPDATE "qr_items" SET "bound_at" = "created_at" WHERE "user_id" IS NOT NULL AND "bound_at" IS NULL`);
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_qr_bound_owner') THEN
          ALTER TABLE "qr_items" ADD CONSTRAINT "chk_qr_bound_owner"
            CHECK (("user_id" IS NULL) = ("bound_at" IS NULL));
        END IF;
      END $$
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "idx_qr_items_user" ON "qr_items" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "idx_qr_items_batch" ON "qr_items" ("batch_id")`);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "qr_batches" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "label" character varying(100) NOT NULL,
        "place" character varying(100),
        "count" integer NOT NULL,
        "created_by" uuid,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_qr_item_batch') THEN
          ALTER TABLE "qr_items" ADD CONSTRAINT "fk_qr_item_batch"
            FOREIGN KEY ("batch_id") REFERENCES "qr_batches"("id");
        END IF;
      END $$
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "line_links" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "token_hash" character varying(64) NOT NULL,
        "line_user_hash" character varying(64) NOT NULL,
        "expires_at" TIMESTAMP WITH TIME ZONE NOT NULL,
        "uses_left" integer NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "uniq_line_links_token" UNIQUE ("token_hash"),
        CONSTRAINT "chk_line_links_uses" CHECK ("uses_left" >= 0)
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "idx_line_links_user_created" ON "line_links" ("line_user_hash", "created_at")`);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "qr_finder_notices" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "qr_item_id" uuid NOT NULL REFERENCES "qr_items"("id"),
        "line_user_hash" character varying(64) NOT NULL,
        "message" text NOT NULL,
        "contact" character varying(100),
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "idx_qr_finder_notices_line_created" ON "qr_finder_notices" ("line_user_hash", "created_at")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "qr_finder_notices"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "line_links"`);
    // 尚未綁定的貼紙沒有物主，無法回到 NOT NULL，先移除。
    await queryRunner.query(`DELETE FROM "chats" WHERE "qr_item_id" IN (SELECT "id" FROM "qr_items" WHERE "user_id" IS NULL)`);
    await queryRunner.query(`DELETE FROM "qr_items" WHERE "user_id" IS NULL`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP CONSTRAINT IF EXISTS "fk_qr_item_batch"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "qr_batches"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP CONSTRAINT IF EXISTS "chk_qr_bound_owner"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_qr_items_batch"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_qr_items_user"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP COLUMN IF EXISTS "disabled_at"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP COLUMN IF EXISTS "bound_at"`);
    await queryRunner.query(`ALTER TABLE "qr_items" DROP COLUMN IF EXISTS "batch_id"`);
    await queryRunner.query(`ALTER TABLE "qr_items" ALTER COLUMN "name" DROP DEFAULT`);
    await queryRunner.query(`ALTER TABLE "qr_items" ALTER COLUMN "user_id" SET NOT NULL`);
  }
}
