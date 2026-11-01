import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';

/** Production must use a separate, non-owner runtime role and the role protection trigger. */
@Injectable()
export class DatabaseSecurityService implements OnApplicationBootstrap {
  constructor(private readonly db: DataSource, private readonly config: ConfigService) {}
  async onApplicationBootstrap(): Promise<void> {
    if (this.config.get<string>('NODE_ENV') !== 'production') return;
    const [role]: Array<{ unsafe: boolean; name: string }> = await this.db.query(`SELECT
      current_user AS name,
      (r.rolsuper OR r.rolcreaterole OR r.rolcreatedb OR r.rolreplication OR r.rolbypassrls OR
       has_database_privilege(current_user, current_database(), 'CREATE') OR
       has_database_privilege(current_user, current_database(), 'TEMP') OR
       has_schema_privilege(current_user, 'public', 'CREATE') OR
       EXISTS(SELECT 1 FROM pg_database d WHERE d.datname = current_database() AND d.datdba = r.oid) OR
       EXISTS(SELECT 1 FROM pg_namespace n WHERE n.nspname = 'public' AND n.nspowner = r.oid) OR
       EXISTS(SELECT 1 FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relowner = r.oid) OR
       EXISTS(SELECT 1 FROM pg_auth_members m WHERE m.member = r.oid)) AS unsafe
      FROM pg_roles r WHERE r.rolname = current_user`);
    const [trigger]: Array<{ tgargs: Buffer }> = await this.db.query(`SELECT tgargs FROM pg_trigger
      WHERE tgrelid = 'public.users'::regclass AND tgname = 'foundit_user_security' AND tgenabled = 'O'`);
    if (!role || role.unsafe || !trigger || trigger.tgargs.toString('utf8') !== `${role.name}\0`) {
      throw new Error('正式環境資料庫權限未完成隔離，請先套用 db-least-privilege.sql');
    }
  }
}
