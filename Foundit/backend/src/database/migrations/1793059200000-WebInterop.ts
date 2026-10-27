import { MigrationInterface, QueryRunner } from 'typeorm';
import { campusForCoordinates } from '../../items/campus';

export class WebInterop1793059200000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(
      `ALTER TABLE items ADD COLUMN campus_code varchar(20) NOT NULL DEFAULT ''`,
    );
    await runner.query(
      `ALTER TABLE users ADD COLUMN verified_email varchar(120) NOT NULL DEFAULT ''`,
    );
    // Old editable email addresses are deliberately not promoted to verified identities.
    const rows = await runner.query(
      'SELECT id, latitude, longitude FROM items WHERE latitude IS NOT NULL AND longitude IS NOT NULL',
    );
    for (const row of rows) {
      if (campusForCoordinates(Number(row.latitude), Number(row.longitude))) {
        await runner.query(
          `UPDATE items SET campus_code = 'ncku' WHERE id = $1`,
          [row.id],
        );
      }
    }
    await runner.query(
      `CREATE INDEX items_campus_feed ON items(campus_code, created_at DESC) WHERE hidden_at IS NULL AND status = 'ACTIVE'`,
    );
    await runner.query(`CREATE TABLE saved_items (
      user_id uuid NOT NULL REFERENCES users(id), item_id uuid NOT NULL REFERENCES items(id),
      created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id, item_id))`);
    await runner.query(`CREATE TABLE hidden_chats (
      user_id uuid NOT NULL REFERENCES users(id), chat_id uuid NOT NULL REFERENCES chats(id),
      hidden_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id, chat_id))`);
    await runner.query(`CREATE TABLE point_awards (
      user_id uuid NOT NULL REFERENCES users(id), kind text NOT NULL, reference text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id, kind, reference))`);
    const role = process.env.DB_USER;
    if (
      role &&
      (await runner.query('SELECT 1 FROM pg_roles WHERE rolname=$1', [role]))
        .length
    ) {
      const quoted = '"' + role.replace(/"/g, '""') + '"';
      await runner.query(
        `GRANT SELECT, INSERT, UPDATE, DELETE ON saved_items, hidden_chats TO ${quoted}`,
      );
      await runner.query(`GRANT SELECT, INSERT ON point_awards TO ${quoted}`);
    }
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('DROP TABLE point_awards, hidden_chats, saved_items');
    await runner.query('ALTER TABLE items DROP COLUMN campus_code');
    await runner.query('ALTER TABLE users DROP COLUMN verified_email');
  }
}
