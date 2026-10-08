import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 掃到防丟牌的人可以直接和物主開聊天室：chats 的主題改成「刊登物品」或「防丟牌」二選一。
 */
export class QrTagChats1760000000000 implements MigrationInterface {
  name = 'QrTagChats1760000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "chats" ALTER COLUMN "item_id" DROP NOT NULL`);
    await queryRunner.query(`ALTER TABLE "chats" ADD COLUMN IF NOT EXISTS "qr_item_id" uuid`);
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_chat_qr_item') THEN
          ALTER TABLE "chats" ADD CONSTRAINT "fk_chat_qr_item"
            FOREIGN KEY ("qr_item_id") REFERENCES "qr_items"("id");
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_chat_subject') THEN
          ALTER TABLE "chats" ADD CONSTRAINT "chk_chat_subject"
            CHECK (num_nonnulls("item_id", "qr_item_id") = 1);
        END IF;
      END $$
    `);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "uniq_chat_qr_requester" ON "chats" ("qr_item_id", "requester_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    const qrChats = `SELECT "id" FROM "chats" WHERE "qr_item_id" IS NOT NULL`;
    await queryRunner.query(`DELETE FROM "messages" WHERE "chat_id" IN (${qrChats})`);
    await queryRunner.query(`DELETE FROM "chat_participants" WHERE "chat_id" IN (${qrChats})`);
    await queryRunner.query(`DELETE FROM "chats" WHERE "qr_item_id" IS NOT NULL`);
    await queryRunner.query(`DROP INDEX IF EXISTS "uniq_chat_qr_requester"`);
    await queryRunner.query(`ALTER TABLE "chats" DROP CONSTRAINT IF EXISTS "chk_chat_subject"`);
    await queryRunner.query(`ALTER TABLE "chats" DROP CONSTRAINT IF EXISTS "fk_chat_qr_item"`);
    await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "qr_item_id"`);
    await queryRunner.query(`ALTER TABLE "chats" ALTER COLUMN "item_id" SET NOT NULL`);
  }
}
