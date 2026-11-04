import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 同一組碼每小時可以開的新對話從 5 段放寬到 30 段（同一台裝置每小時 10 段不變）。
 *
 * 2026-11-04 現場試用時，大家掃的是同一組碼：第 6 個人之後送出第一則訊息都被擋下，看到「送出得太頻繁了」。
 * 一般情況一件東西只會有一兩個人撿到，30 段仍擋得住有人對同一組碼大量灌留言；
 * 猜碼則由每台裝置每小時 10 段擋住。
 *
 * 只改 campus.sticker_notify 裡那一個數字：讀出目前的函式定義、換掉數字、重新建立。
 * 定義若和預期不同（之後有人改過這個函式），就停下來報錯，不會蓋掉別人的修改。
 */
const FN = `'campus.sticker_notify(text,text,text,text)'::regprocedure`;
const PER_CODE = (n: number) => `WHERE code = c AND created_at > now() - interval ''1 hour'') >= ${n}`;

const swap = (from: number, to: number) => `DO $migration$
DECLARE
  def text := pg_get_functiondef(${FN});
BEGIN
  IF position('${PER_CODE(from)}' IN def) = 0 THEN
    RAISE EXCEPTION 'campus.sticker_notify no longer has the per-code limit of ${from}; update this migration';
  END IF;
  EXECUTE replace(def, '${PER_CODE(from)}', '${PER_CODE(to)}');
END $migration$`;

export class StickerNotifyCodeLimit1793059205000 implements MigrationInterface {
  name = 'StickerNotifyCodeLimit1793059205000';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(swap(5, 30));
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(swap(30, 5));
  }
}
