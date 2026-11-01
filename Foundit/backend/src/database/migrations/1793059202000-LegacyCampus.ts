import { MigrationInterface, QueryRunner } from 'typeorm';
import { campusForLocation } from '../../items/campus';

export class LegacyCampus1793059202000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    const rows = await runner.query(`SELECT id, location_name FROM items
      WHERE campus_code = '' AND latitude IS NULL AND longitude IS NULL`);
    for (const row of rows) {
      if (campusForLocation(null, null, row.location_name)) {
        await runner.query(`UPDATE items SET campus_code='ncku'
          WHERE id=$1 AND campus_code='' AND latitude IS NULL AND longitude IS NULL`, [row.id]);
      }
    }
  }
  async down(): Promise<void> {
    // Preserve repaired classifications and later user edits during a code rollback.
  }
}
